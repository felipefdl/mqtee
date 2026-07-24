use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use tracing::info;

use super::ClientInner;
use super::tls::create_tls_config;
use super::v311::handle_v311_outgoing;
use crate::error::MqttError;
use crate::types::{
  ConnectionConfig, ConnectionEvent, LastWillConfig, MqttEventHandler, MqttMessage, UserProperty,
};

pub(super) fn create_v5_client(
  config: &ConnectionConfig,
  max_packet_size: usize,
) -> Result<ClientInner, MqttError> {
  let mut mqtt_options =
    rumqttc::v5::MqttOptions::new(&config.client_id, &config.host, config.port);
  mqtt_options.set_keep_alive(Duration::from_secs(config.keep_alive_secs as u64));
  mqtt_options.set_clean_start(config.clean_session);
  mqtt_options.set_max_packet_size(Some(max_packet_size as u32));

  if let Some(interval) = config.session_expiry_interval {
    mqtt_options.set_session_expiry_interval(Some(interval));
  }

  if let Some(username) = &config.username {
    mqtt_options.set_credentials(username, config.password.as_deref().unwrap_or(""));
  }

  if let Some(lw) = &config.last_will {
    mqtt_options.set_last_will(create_v5_last_will(lw));
  }

  if config.use_tls {
    let tls_config = create_tls_config(config)?;
    mqtt_options.set_transport(rumqttc::Transport::Tls(tls_config));
  }

  let (client, eventloop) = rumqttc::v5::AsyncClient::new(mqtt_options, 100);
  Ok(ClientInner::V5 {
    client,
    eventloop: Box::new(eventloop),
  })
}

fn create_v5_last_will(lw: &LastWillConfig) -> rumqttc::v5::mqttbytes::v5::LastWill {
  rumqttc::v5::mqttbytes::v5::LastWill::new(
    &lw.topic,
    lw.message.as_bytes().to_vec(),
    lw.qos.into(),
    lw.retain,
    None,
  )
}

// ---------------------------------------------------------------------------
// V5 event handling
// ---------------------------------------------------------------------------

pub(super) fn handle_v5_event(
  event: rumqttc::v5::Event,
  handler: &Arc<dyn MqttEventHandler + Send + Sync>,
  connected: &Arc<AtomicBool>,
) {
  use rumqttc::v5::mqttbytes::v5 as v5packets;

  match event {
    rumqttc::v5::Event::Incoming(packet) => match packet {
      v5packets::Packet::ConnAck(ack) => {
        let return_code = format!("{:?}", ack.code);
        let session_present = ack.session_present;

        if ack.code == v5packets::ConnectReturnCode::Success {
          connected.store(true, Ordering::Release);
          handler.on_event(ConnectionEvent::Connected);
          info!("Connected to MQTT broker (v5.0)");
        } else {
          handler.on_event(ConnectionEvent::Error {
            error: format!("Connection rejected: {:?}", ack.code),
          });
        }

        let (
          reason_string,
          assigned_client_id,
          server_keep_alive,
          maximum_qos,
          retain_available,
          wildcard_subscription_available,
          subscription_identifiers_available,
          shared_subscription_available,
          maximum_packet_size,
        ) = if let Some(props) = &ack.properties {
          (
            props.reason_string.clone(),
            props.assigned_client_identifier.clone(),
            props.server_keep_alive,
            props.max_qos,
            props.retain_available.map(|v| v != 0),
            props.wildcard_subscription_available.map(|v| v != 0),
            props.subscription_identifiers_available.map(|v| v != 0),
            props.shared_subscription_available.map(|v| v != 0),
            props.max_packet_size,
          )
        } else {
          (None, None, None, None, None, None, None, None, None)
        };

        handler.on_event(ConnectionEvent::ConnAckDetails {
          session_present,
          return_code,
          reason_string,
          assigned_client_id,
          server_keep_alive,
          maximum_qos,
          retain_available,
          wildcard_subscription_available,
          subscription_identifiers_available,
          shared_subscription_available,
          maximum_packet_size,
        });
      }

      v5packets::Packet::Publish(publish) => {
        let (
          content_type,
          response_topic,
          correlation_data,
          user_properties,
          payload_format_indicator,
          message_expiry_interval,
        ) = if let Some(props) = &publish.properties {
          (
            props.content_type.clone(),
            props.response_topic.clone(),
            props.correlation_data.as_ref().map(|b| b.to_vec()),
            props
              .user_properties
              .iter()
              .map(|(k, v)| UserProperty {
                key: k.clone(),
                value: v.clone(),
              })
              .collect::<Vec<_>>(),
            props.payload_format_indicator,
            props.message_expiry_interval,
          )
        } else {
          (None, None, None, Vec::<UserProperty>::new(), None, None)
        };

        let topic_str = String::from_utf8_lossy(&publish.topic).to_string();
        let message = MqttMessage::with_v5_properties(
          topic_str,
          publish.payload.to_vec(),
          publish.qos.into(),
          publish.retain,
          content_type,
          response_topic,
          correlation_data,
          user_properties,
          payload_format_indicator,
          message_expiry_interval,
        );
        handler.on_event(ConnectionEvent::MessageReceived { message });
      }

      v5packets::Packet::SubAck(ack) => {
        let codes = ack
          .return_codes
          .iter()
          .map(|c| format!("{:?}", c))
          .collect::<Vec<_>>()
          .join(", ");

        let reason_detail = ack
          .properties
          .as_ref()
          .and_then(|p| p.reason_string.clone());

        handler.on_event(ConnectionEvent::SubscribeAck {
          packet_id: ack.pkid,
          return_codes: codes,
          reason_codes_detail: reason_detail,
        });
      }

      v5packets::Packet::UnsubAck(ack) => {
        handler.on_event(ConnectionEvent::UnsubscribeAck {
          packet_id: ack.pkid,
        });
      }

      v5packets::Packet::PubAck(ack) => {
        handler.on_event(ConnectionEvent::PublishAck {
          packet_id: ack.pkid,
        });
      }
      v5packets::Packet::PubRec(ack) => {
        handler.on_event(ConnectionEvent::PubRecReceived {
          packet_id: ack.pkid,
        });
      }
      v5packets::Packet::PubRel(ack) => {
        handler.on_event(ConnectionEvent::PubRelReceived {
          packet_id: ack.pkid,
        });
      }
      v5packets::Packet::PubComp(ack) => {
        handler.on_event(ConnectionEvent::PubCompReceived {
          packet_id: ack.pkid,
        });
      }
      v5packets::Packet::PingResp(_) => {
        handler.on_event(ConnectionEvent::PingResponseReceived);
      }
      v5packets::Packet::Disconnect(disconnect) => {
        connected.store(false, Ordering::Release);
        let reason_code = Some(format!("{:?}", disconnect.reason_code));
        let reason = disconnect
          .properties
          .as_ref()
          .and_then(|p| p.reason_string.clone())
          .unwrap_or_else(|| {
            format!("Server initiated disconnect: {:?}", disconnect.reason_code)
          });
        handler.on_event(ConnectionEvent::Disconnected {
          reason,
          reason_code,
        });
      }

      v5packets::Packet::Connect(..)
      | v5packets::Packet::PingReq(_)
      | v5packets::Packet::Subscribe(_)
      | v5packets::Packet::Unsubscribe(_)
      | v5packets::Packet::Auth(_) => {}
    },
    rumqttc::v5::Event::Outgoing(outgoing) => handle_v311_outgoing(outgoing, handler),
  }
}
