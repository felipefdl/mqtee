use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use super::ClientInner;
use super::tls::create_tls_config;
use crate::error::MqttError;
use crate::types::{ConnectionConfig, ConnectionEvent, MqttEventHandler, MqttMessage};

pub(super) fn create_v311_client(config: &ConnectionConfig, max_packet_size: usize) -> Result<ClientInner, MqttError> {
  let mut mqtt_options = rumqttc::MqttOptions::new(&config.client_id, &config.host, config.port);
  mqtt_options.set_keep_alive(Duration::from_secs(config.keep_alive_secs as u64));
  mqtt_options.set_clean_session(config.clean_session);
  mqtt_options.set_max_packet_size(max_packet_size, max_packet_size);

  if let Some(username) = &config.username {
    mqtt_options.set_credentials(username, config.password.as_deref().unwrap_or(""));
  }

  if let Some(lw) = &config.last_will {
    mqtt_options.set_last_will(rumqttc::LastWill::new(
      &lw.topic,
      lw.message.as_bytes().to_vec(),
      lw.qos.into(),
      lw.retain,
    ));
  }

  if config.use_tls {
    let tls_config = create_tls_config(config)?;
    mqtt_options.set_transport(rumqttc::Transport::Tls(tls_config));
  }

  let (client, eventloop) = rumqttc::AsyncClient::new(mqtt_options, 100);
  Ok(ClientInner::V311 {
    client,
    eventloop: Box::new(eventloop),
  })
}

// ---------------------------------------------------------------------------
// V3.1.1 event handling
// ---------------------------------------------------------------------------

pub(super) fn handle_v311_event(
  event: rumqttc::Event,
  handler: &Arc<dyn MqttEventHandler + Send + Sync>,
  connected: &Arc<AtomicBool>,
) {
  match event {
    rumqttc::Event::Incoming(packet) => match packet {
      rumqttc::Packet::ConnAck(ack) => {
        let return_code = format!("{:?}", ack.code);
        let session_present = ack.session_present;
        if ack.code == rumqttc::ConnectReturnCode::Success {
          connected.store(true, Ordering::Release);
          handler.on_event(ConnectionEvent::Connected);
          tracing::info!("Connected to MQTT broker (v3.1.1)");
        } else {
          handler.on_event(ConnectionEvent::Error {
            error: format!("Connection rejected: {:?}", ack.code),
          });
        }
        handler.on_event(ConnectionEvent::ConnAckDetails {
          session_present,
          return_code,
          reason_string: None,
          assigned_client_id: None,
          server_keep_alive: None,
          maximum_qos: None,
          retain_available: None,
          wildcard_subscription_available: None,
          subscription_identifiers_available: None,
          shared_subscription_available: None,
          maximum_packet_size: None,
        });
      }
      rumqttc::Packet::Publish(publish) => {
        let message = MqttMessage::new(
          publish.topic.to_string(),
          publish.payload.to_vec(),
          publish.qos.into(),
          publish.retain,
        );
        handler.on_event(ConnectionEvent::MessageReceived { message });
      }
      rumqttc::Packet::SubAck(ack) => {
        let codes = ack
          .return_codes
          .iter()
          .map(|c| format!("{:?}", c))
          .collect::<Vec<_>>()
          .join(", ");
        handler.on_event(ConnectionEvent::SubscribeAck {
          packet_id: ack.pkid,
          return_codes: codes,
          reason_codes_detail: None,
        });
      }
      rumqttc::Packet::UnsubAck(ack) => {
        handler.on_event(ConnectionEvent::UnsubscribeAck { packet_id: ack.pkid });
      }
      rumqttc::Packet::PubAck(ack) => {
        handler.on_event(ConnectionEvent::PublishAck { packet_id: ack.pkid });
      }
      rumqttc::Packet::PubRec(ack) => {
        handler.on_event(ConnectionEvent::PubRecReceived { packet_id: ack.pkid });
      }
      rumqttc::Packet::PubRel(ack) => {
        handler.on_event(ConnectionEvent::PubRelReceived { packet_id: ack.pkid });
      }
      rumqttc::Packet::PubComp(ack) => {
        handler.on_event(ConnectionEvent::PubCompReceived { packet_id: ack.pkid });
      }
      rumqttc::Packet::PingResp => {
        handler.on_event(ConnectionEvent::PingResponseReceived);
      }
      rumqttc::Packet::Disconnect => {
        connected.store(false, Ordering::Release);
        handler.on_event(ConnectionEvent::Disconnected {
          reason: "Server initiated disconnect".to_string(),
          reason_code: None,
        });
      }
      rumqttc::Packet::Connect(_)
      | rumqttc::Packet::PingReq
      | rumqttc::Packet::Subscribe(_)
      | rumqttc::Packet::Unsubscribe(_) => {}
    },
    rumqttc::Event::Outgoing(outgoing) => handle_v311_outgoing(outgoing, handler),
  }
}

pub(super) fn handle_v311_outgoing(outgoing: rumqttc::Outgoing, handler: &Arc<dyn MqttEventHandler + Send + Sync>) {
  match outgoing {
    rumqttc::Outgoing::Publish(id) => {
      handler.on_event(ConnectionEvent::PublishSent { packet_id: id });
    }
    rumqttc::Outgoing::Subscribe(id) => {
      handler.on_event(ConnectionEvent::SubscribeSent { packet_id: id });
    }
    rumqttc::Outgoing::Unsubscribe(id) => {
      handler.on_event(ConnectionEvent::UnsubscribeSent { packet_id: id });
    }
    rumqttc::Outgoing::PubAck(id) => {
      handler.on_event(ConnectionEvent::PublishAckSent { packet_id: id });
    }
    rumqttc::Outgoing::PubRec(id) => {
      handler.on_event(ConnectionEvent::PubRecSent { packet_id: id });
    }
    rumqttc::Outgoing::PubComp(id) => {
      handler.on_event(ConnectionEvent::PubCompSent { packet_id: id });
    }
    rumqttc::Outgoing::PingReq => {
      handler.on_event(ConnectionEvent::PingSent);
    }
    rumqttc::Outgoing::Disconnect => {
      handler.on_event(ConnectionEvent::DisconnectSent);
    }
    _ => {}
  }
}
