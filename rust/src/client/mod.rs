mod tls;
mod v311;
mod v5;

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use tokio::runtime::Runtime;
use tokio::sync::mpsc;
use tracing::{debug, error, info};

use crate::error::MqttError;
use crate::types::{
  ConnectionConfig, ConnectionEvent, MqttEventHandler, MqttVersion, QosLevel, SubscriptionRequest,
  UserProperty,
};

use self::v311::{create_v311_client, handle_v311_event};
use self::v5::{create_v5_client, handle_v5_event};

pub enum Command {
  Connect,
  Disconnect,
  Subscribe(Vec<SubscriptionRequest>),
  Unsubscribe(Vec<String>),
  Publish {
    topic: String,
    payload: Vec<u8>,
    qos: QosLevel,
    retain: bool,
    content_type: Option<String>,
    response_topic: Option<String>,
    correlation_data: Option<Vec<u8>>,
    message_expiry_interval: Option<u32>,
    payload_format_indicator: Option<u8>,
    user_properties: Vec<UserProperty>,
  },
}

enum ClientInner {
  V311 {
    client: rumqttc::AsyncClient,
    eventloop: Box<rumqttc::EventLoop>,
  },
  V5 {
    client: rumqttc::v5::AsyncClient,
    eventloop: Box<rumqttc::v5::EventLoop>,
  },
}

#[derive(uniffi::Object)]
pub struct MqttClient {
  command_tx: mpsc::Sender<Command>,
  connected: Arc<AtomicBool>,
  runtime: Runtime,
}

#[uniffi::export]
impl MqttClient {
  #[uniffi::constructor]
  pub fn new(
    config: ConnectionConfig,
    handler: Box<dyn MqttEventHandler>,
  ) -> Result<Arc<Self>, MqttError> {
    let runtime = Runtime::new().map_err(|e| MqttError::InternalError(e.to_string()))?;

    let handler: Arc<dyn MqttEventHandler> = Arc::from(handler);
    let (command_tx, command_rx) = mpsc::channel::<Command>(100);
    let connected = Arc::new(AtomicBool::new(false));

    let connected_for_loop = connected.clone();

    let client = Arc::new(Self {
      command_tx,
      connected,
      runtime,
    });

    client.runtime.spawn(async move {
      run_client_loop(config, handler, command_rx, connected_for_loop).await;
    });

    Ok(client)
  }

  pub fn connect(&self) -> Result<(), MqttError> {
    self.command_tx
      .try_send(Command::Connect)
      .map_err(|e| MqttError::InternalError(format!("Command channel error: {}", e)))
  }

  pub fn disconnect(&self) -> Result<(), MqttError> {
    self.command_tx
      .try_send(Command::Disconnect)
      .map_err(|e| MqttError::InternalError(format!("Command channel error: {}", e)))
  }

  pub fn subscribe(&self, subscriptions: Vec<SubscriptionRequest>) -> Result<(), MqttError> {
    if !self.connected.load(Ordering::Acquire) {
      return Err(MqttError::NotConnected);
    }

    self.command_tx
      .try_send(Command::Subscribe(subscriptions))
      .map_err(|e| MqttError::InternalError(format!("Command channel error: {}", e)))
  }

  pub fn unsubscribe(&self, topics: Vec<String>) -> Result<(), MqttError> {
    if !self.connected.load(Ordering::Acquire) {
      return Err(MqttError::NotConnected);
    }

    self.command_tx
      .try_send(Command::Unsubscribe(topics))
      .map_err(|e| MqttError::InternalError(format!("Command channel error: {}", e)))
  }

  #[allow(clippy::too_many_arguments)]
  pub fn publish(
    &self,
    topic: String,
    payload: Vec<u8>,
    qos: QosLevel,
    retain: bool,
    content_type: Option<String>,
    response_topic: Option<String>,
    correlation_data: Option<Vec<u8>>,
    message_expiry_interval: Option<u32>,
    payload_format_indicator: Option<u8>,
    user_properties: Vec<UserProperty>,
  ) -> Result<(), MqttError> {
    if !self.connected.load(Ordering::Acquire) {
      return Err(MqttError::NotConnected);
    }

    self.command_tx
      .try_send(Command::Publish {
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
      })
      .map_err(|e| MqttError::InternalError(format!("Command channel error: {}", e)))
  }

  pub fn is_connected(&self) -> bool {
    self.connected.load(Ordering::Acquire)
  }
}

// ---------------------------------------------------------------------------
// Event loop
// ---------------------------------------------------------------------------

async fn run_client_loop(
  config: ConnectionConfig,
  handler: Arc<dyn MqttEventHandler + Send + Sync>,
  mut command_rx: mpsc::Receiver<Command>,
  connected: Arc<AtomicBool>,
) {
  let mut inner: Option<ClientInner> = None;

  loop {
    // Drain pending commands without blocking
    while let Ok(cmd) = command_rx.try_recv() {
      handle_command(cmd, &mut inner, &connected, &handler, &config).await;
    }

    match &mut inner {
      Some(ClientInner::V311 { eventloop, .. }) => {
        tokio::select! {
          biased;

          Some(cmd) = command_rx.recv() => {
            handle_command(cmd, &mut inner, &connected, &handler, &config).await;
          }

          result = eventloop.poll() => {
            match result {
              Ok(event) => handle_v311_event(event, &handler, &connected),
              Err(e) => {
                error!("Event loop error: {}", e);
                connected.store(false, Ordering::Release);
                handler.on_event(ConnectionEvent::Error { error: e.to_string() });
                handler.on_event(ConnectionEvent::Disconnected {
                  reason: e.to_string(),
                  reason_code: None,
                });
                inner = None;
              }
            }
          }
        }
      }

      Some(ClientInner::V5 { eventloop, .. }) => {
        tokio::select! {
          biased;

          Some(cmd) = command_rx.recv() => {
            handle_command(cmd, &mut inner, &connected, &handler, &config).await;
          }

          result = eventloop.poll() => {
            match result {
              Ok(event) => handle_v5_event(event, &handler, &connected),
              Err(e) => {
                error!("Event loop error: {}", e);
                connected.store(false, Ordering::Release);
                handler.on_event(ConnectionEvent::Error { error: e.to_string() });
                handler.on_event(ConnectionEvent::Disconnected {
                  reason: e.to_string(),
                  reason_code: None,
                });
                inner = None;
              }
            }
          }
        }
      }

      None => {
        if let Some(cmd) = command_rx.recv().await {
          handle_command(cmd, &mut inner, &connected, &handler, &config).await;
        } else {
          break;
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Command handling
// ---------------------------------------------------------------------------

async fn handle_command(
  cmd: Command,
  inner: &mut Option<ClientInner>,
  connected: &Arc<AtomicBool>,
  handler: &Arc<dyn MqttEventHandler + Send + Sync>,
  config: &ConnectionConfig,
) {
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
          handler.on_event(ConnectionEvent::Error {
            error: e.to_string(),
          });
        }
      }
    }

    Command::Disconnect => match inner.take() {
      Some(ClientInner::V311 { client, .. }) => {
        let _ = client.disconnect().await;
        connected.store(false, Ordering::Release);
        handler.on_event(ConnectionEvent::Disconnected {
          reason: "User requested disconnect".to_string(),
          reason_code: None,
        });
        info!("Disconnected from MQTT broker");
      }
      Some(ClientInner::V5 { client, .. }) => {
        let _ = client.disconnect().await;
        connected.store(false, Ordering::Release);
        handler.on_event(ConnectionEvent::Disconnected {
          reason: "User requested disconnect".to_string(),
          reason_code: None,
        });
        info!("Disconnected from MQTT broker");
      }
      None => {}
    },

    Command::Subscribe(subs) => match inner {
      Some(ClientInner::V311 { client, .. }) => {
        for sub in subs {
          match client.subscribe(&sub.topic, sub.qos.into()).await {
            Ok(_) => debug!("Subscribe request sent for {}", sub.topic),
            Err(e) => {
              error!("Failed to subscribe to {}: {}", sub.topic, e);
              handler.on_event(ConnectionEvent::Error {
                error: format!("Subscribe failed: {}", e),
              });
            }
          }
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

        match client.subscribe_many(filters).await {
          Ok(_) => debug!("V5 subscribe request sent"),
          Err(e) => {
            error!("Failed to subscribe: {}", e);
            handler.on_event(ConnectionEvent::Error {
              error: format!("Subscribe failed: {}", e),
            });
          }
        }
      }
      None => {}
    },

    Command::Unsubscribe(topics) => match inner {
      Some(ClientInner::V311 { client, .. }) => {
        for topic in topics {
          match client.unsubscribe(&topic).await {
            Ok(_) => debug!("Unsubscribed from {}", topic),
            Err(e) => {
              error!("Failed to unsubscribe from {}: {}", topic, e);
              handler.on_event(ConnectionEvent::Error {
                error: format!("Unsubscribe failed: {}", e),
              });
            }
          }
        }
      }
      Some(ClientInner::V5 { client, .. }) => {
        for topic in topics {
          match client.unsubscribe(&topic).await {
            Ok(_) => debug!("Unsubscribed from {}", topic),
            Err(e) => {
              error!("Failed to unsubscribe from {}: {}", topic, e);
              handler.on_event(ConnectionEvent::Error {
                error: format!("Unsubscribe failed: {}", e),
              });
            }
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
    } => match inner {
      Some(ClientInner::V311 { client, .. }) => {
        match client.publish(&topic, qos.into(), retain, payload).await {
          Ok(_) => debug!("Published to {}", topic),
          Err(e) => {
            error!("Failed to publish to {}: {}", topic, e);
            handler.on_event(ConnectionEvent::Error {
              error: format!("Publish failed: {}", e),
            });
          }
        }
      }
      Some(ClientInner::V5 { client, .. }) => {
        let has_props = content_type.is_some()
          || response_topic.is_some()
          || correlation_data.is_some()
          || message_expiry_interval.is_some()
          || payload_format_indicator.is_some()
          || !user_properties.is_empty();

        let result = if has_props {
          use rumqttc::v5::mqttbytes::v5::PublishProperties;

          let props = PublishProperties {
            content_type,
            response_topic,
            correlation_data: correlation_data.map(Into::into),
            message_expiry_interval,
            payload_format_indicator,
            user_properties: user_properties
              .into_iter()
              .map(|p| (p.key, p.value))
              .collect(),
            ..Default::default()
          };

          client
            .publish_with_properties(&topic, qos.into(), retain, payload, props)
            .await
        } else {
          client.publish(&topic, qos.into(), retain, payload).await
        };

        match result {
          Ok(_) => debug!("Published to {}", topic),
          Err(e) => {
            error!("Failed to publish to {}: {}", topic, e);
            handler.on_event(ConnectionEvent::Error {
              error: format!("Publish failed: {}", e),
            });
          }
        }
      }
      None => {}
    },
  }
}

// ---------------------------------------------------------------------------
// Client creation
// ---------------------------------------------------------------------------

fn create_client(config: &ConnectionConfig) -> Result<ClientInner, MqttError> {
  let max_packet_size = config.max_packet_size.unwrap_or(256 * 1024) as usize;

  match config.mqtt_version {
    MqttVersion::V311 => create_v311_client(config, max_packet_size),
    MqttVersion::V5 => create_v5_client(config, max_packet_size),
  }
}
