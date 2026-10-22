use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use tracing::{debug, error, info, warn};

use super::{ClientInner, Command, create_client};
use crate::types::{ConnectionConfig, ConnectionEvent, MqttEventHandler};

/// Upper bound for flushing DISCONNECT to the broker before the socket is dropped.
const DISCONNECT_FLUSH_TIMEOUT: Duration = Duration::from_secs(2);

/// Sends DISCONNECT and drives the event loop until it is on the wire, so the broker sees a
/// clean disconnect and does not publish the Last Will. Dropping the event loop right after
/// queueing the request closes the socket before the packet is written.
pub(super) async fn close_gracefully(inner: ClientInner, connected: &AtomicBool) {
  let was_connected = connected.swap(false, Ordering::AcqRel);
  if !was_connected {
    return;
  }

  let flush = async {
    match inner {
      ClientInner::V311 { client, mut eventloop } => {
        if client.try_disconnect().is_err() {
          return;
        }
        loop {
          match eventloop.poll().await {
            Ok(rumqttc::Event::Outgoing(rumqttc::Outgoing::Disconnect)) | Err(_) => return,
            Ok(_) => {}
          }
        }
      }
      ClientInner::V5 { client, mut eventloop } => {
        if client.try_disconnect().is_err() {
          return;
        }
        loop {
          match eventloop.poll().await {
            Ok(rumqttc::v5::Event::Outgoing(rumqttc::Outgoing::Disconnect)) | Err(_) => return,
            Ok(_) => {}
          }
        }
      }
    }
  };

  if tokio::time::timeout(DISCONNECT_FLUSH_TIMEOUT, flush).await.is_err() {
    warn!("Timed out flushing DISCONNECT; closing the socket");
  }
}

// ---------------------------------------------------------------------------
// Command handling
// ---------------------------------------------------------------------------

/// Requests go to rumqttc with the non-blocking `try_*` calls: the event loop that drains
/// rumqttc's request queue runs on this same task, so awaiting a full queue would deadlock.
pub(super) async fn handle_command(
  cmd: Command,
  inner: &mut Option<ClientInner>,
  connected: &Arc<AtomicBool>,
  handler: &Arc<dyn MqttEventHandler + Send + Sync>,
  config: &ConnectionConfig,
) {
  let report = |action: &str, e: &dyn std::fmt::Display| {
    error!("{} failed: {}", action, e);
    handler.on_event(ConnectionEvent::Error {
      error: format!("{} failed: {}", action, e),
    });
  };

  match cmd {
    Command::Connect => {
      if inner.is_some() {
        return;
      }
      match create_client(config) {
        Ok(ci) => {
          *inner = Some(ci);
          info!("MQTT client created, starting event loop");
        }
        Err(e) => {
          error!("Failed to create MQTT client: {}", e);
          handler.on_event(ConnectionEvent::Error { error: e.to_string() });
        }
      }
    }

    Command::Disconnect => {
      if let Some(ci) = inner.take() {
        close_gracefully(ci, connected).await;
        handler.on_event(ConnectionEvent::Disconnected {
          reason: "User requested disconnect".to_string(),
          reason_code: None,
        });
        info!("Disconnected from MQTT broker");
      }
    }

    Command::Subscribe(subs) => match inner {
      Some(ClientInner::V311 { client, .. }) => {
        let filters: Vec<_> = subs
          .into_iter()
          .map(|sub| rumqttc::SubscribeFilter::new(sub.topic, sub.qos.into()))
          .collect();
        match client.try_subscribe_many(filters) {
          Ok(()) => debug!("Subscribe request sent"),
          Err(e) => report("Subscribe", &e),
        }
      }
      Some(ClientInner::V5 { client, .. }) => {
        use rumqttc::v5::mqttbytes::v5::{Filter, RetainForwardRule};

        let filters: Vec<Filter> = subs
          .into_iter()
          .map(|sub| {
            let mut filter = Filter::new(sub.topic, sub.qos.into());
            filter.nolocal = sub.no_local;
            filter.preserve_retain = sub.retain_as_published;
            filter.retain_forward_rule = match sub.retain_handling {
              1 => RetainForwardRule::OnNewSubscribe,
              2 => RetainForwardRule::Never,
              _ => RetainForwardRule::OnEverySubscribe,
            };
            filter
          })
          .collect();

        match client.try_subscribe_many(filters) {
          Ok(()) => debug!("V5 subscribe request sent"),
          Err(e) => report("Subscribe", &e),
        }
      }
      None => {}
    },

    Command::Unsubscribe(topics) => match inner {
      Some(ClientInner::V311 { client, .. }) => {
        for topic in topics {
          match client.try_unsubscribe(topic.as_str()) {
            Ok(()) => debug!("Unsubscribed from {}", topic),
            Err(e) => report("Unsubscribe", &e),
          }
        }
      }
      Some(ClientInner::V5 { client, .. }) => {
        for topic in topics {
          match client.try_unsubscribe(topic.as_str()) {
            Ok(()) => debug!("Unsubscribed from {}", topic),
            Err(e) => report("Unsubscribe", &e),
          }
        }
      }
      None => {}
    },

    Command::Publish {
      topic,
      payload,
      qos,
      retain,
      content_type,
      response_topic,
      correlation_data,
      message_expiry_interval,
      payload_format_indicator,
      user_properties,
    } => {
      let result = match inner {
        Some(ClientInner::V311 { client, .. }) => client
          .try_publish(&topic, qos.into(), retain, payload)
          .map_err(|e| e.to_string()),
        Some(ClientInner::V5 { client, .. }) => {
          let has_props = content_type.is_some()
            || response_topic.is_some()
            || correlation_data.is_some()
            || message_expiry_interval.is_some()
            || payload_format_indicator.is_some()
            || !user_properties.is_empty();

          if has_props {
            use rumqttc::v5::mqttbytes::v5::PublishProperties;

            let props = PublishProperties {
              content_type,
              response_topic,
              correlation_data: correlation_data.map(Into::into),
              message_expiry_interval,
              payload_format_indicator,
              user_properties: user_properties.into_iter().map(|p| (p.key, p.value)).collect(),
              ..Default::default()
            };
            client
              .try_publish_with_properties(&topic, qos.into(), retain, payload, props)
              .map_err(|e| e.to_string())
          } else {
            client
              .try_publish(&topic, qos.into(), retain, payload)
              .map_err(|e| e.to_string())
          }
        }
        None => return,
      };

      match result {
        Ok(()) => debug!("Published to {}", topic),
        Err(e) => report("Publish", &e),
      }
    }
  }
}
