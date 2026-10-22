mod commands;
mod tls;
mod v311;
mod v5;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, LazyLock};

use tokio::runtime::Runtime;
use tokio::sync::mpsc;
use tracing::{debug, error};

use crate::error::MqttError;
use crate::types::{
  ConnectionConfig, ConnectionEvent, MqttEventHandler, MqttVersion, QosLevel, SubscriptionRequest, UserProperty,
};

use self::commands::{close_gracefully, handle_command};
use self::v5::{create_v5_client, handle_v5_event};
use self::v311::{create_v311_client, handle_v311_event};

/// One small runtime shared by every client. A per-client multi-thread runtime spawned a worker
/// per CPU core for each connection, test connection, and Shortcuts intent.
static RUNTIME: LazyLock<std::io::Result<Runtime>> = LazyLock::new(|| {
  tokio::runtime::Builder::new_multi_thread()
    .worker_threads(2)
    .thread_name("mqtee-core")
    .enable_all()
    .build()
});

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
}

#[uniffi::export]
impl MqttClient {
  #[uniffi::constructor]
  pub fn new(config: ConnectionConfig, handler: Box<dyn MqttEventHandler>) -> Result<Arc<Self>, MqttError> {
    let runtime = RUNTIME.as_ref().map_err(|e| MqttError::InternalError(e.to_string()))?;

    let handler: Arc<dyn MqttEventHandler> = Arc::from(handler);
    let (command_tx, command_rx) = mpsc::channel::<Command>(100);
    let connected = Arc::new(AtomicBool::new(false));

    // The loop ends once this client is dropped and its queued commands are handled.
    runtime.spawn(run_client_loop(config, handler, command_rx, connected.clone()));

    Ok(Arc::new(Self { command_tx, connected }))
  }

  pub fn connect(&self) -> Result<(), MqttError> {
    self.send(Command::Connect)
  }

  pub fn disconnect(&self) -> Result<(), MqttError> {
    self.send(Command::Disconnect)
  }

  pub fn subscribe(&self, subscriptions: Vec<SubscriptionRequest>) -> Result<(), MqttError> {
    self.ensure_connected()?;
    self.send(Command::Subscribe(subscriptions))
  }

  pub fn unsubscribe(&self, topics: Vec<String>) -> Result<(), MqttError> {
    self.ensure_connected()?;
    self.send(Command::Unsubscribe(topics))
  }

  /// `payload` borrows the caller's buffer across the FFI without a copy.
  #[allow(clippy::too_many_arguments)]
  pub fn publish(
    &self,
    topic: String,
    payload: &[u8],
    qos: QosLevel,
    retain: bool,
    content_type: Option<String>,
    response_topic: Option<String>,
    correlation_data: Option<Vec<u8>>,
    message_expiry_interval: Option<u32>,
    payload_format_indicator: Option<u8>,
    user_properties: Vec<UserProperty>,
  ) -> Result<(), MqttError> {
    self.ensure_connected()?;
    self.send(Command::Publish {
      topic,
      payload: payload.to_vec(),
      qos,
      retain,
      content_type,
      response_topic,
      correlation_data,
      message_expiry_interval,
      payload_format_indicator,
      user_properties,
    })
  }

  pub fn is_connected(&self) -> bool {
    self.connected.load(Ordering::Acquire)
  }
}

impl MqttClient {
  fn ensure_connected(&self) -> Result<(), MqttError> {
    if self.connected.load(Ordering::Acquire) {
      Ok(())
    } else {
      Err(MqttError::NotConnected)
    }
  }

  fn send(&self, command: Command) -> Result<(), MqttError> {
    self
      .command_tx
      .try_send(command)
      .map_err(|e| MqttError::InternalError(format!("Command channel error: {}", e)))
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
    let cmd = match &mut inner {
      Some(ClientInner::V311 { eventloop, .. }) => {
        tokio::select! {
          biased;

          cmd = command_rx.recv() => cmd,

          result = eventloop.poll() => {
            match result {
              Ok(event) => handle_v311_event(event, &handler, &connected),
              Err(e) => {
                report_connection_lost(&e.to_string(), &handler, &connected);
                inner = None;
              }
            }
            continue;
          }
        }
      }

      Some(ClientInner::V5 { eventloop, .. }) => {
        tokio::select! {
          biased;

          cmd = command_rx.recv() => cmd,

          result = eventloop.poll() => {
            match result {
              Ok(event) => handle_v5_event(event, &handler, &connected),
              Err(e) => {
                report_connection_lost(&e.to_string(), &handler, &connected);
                inner = None;
              }
            }
            continue;
          }
        }
      }

      None => command_rx.recv().await,
    };

    match cmd {
      Some(cmd) => handle_command(cmd, &mut inner, &connected, &handler, &config).await,
      None => {
        // Every sender is gone: the owning MqttClient was dropped.
        if let Some(ci) = inner.take() {
          close_gracefully(ci, &connected).await;
        }
        debug!("Client dropped, event loop finished");
        break;
      }
    }
  }
}

fn report_connection_lost(reason: &str, handler: &Arc<dyn MqttEventHandler + Send + Sync>, connected: &AtomicBool) {
  error!("Event loop error: {}", reason);
  connected.store(false, Ordering::Release);
  handler.on_event(ConnectionEvent::Error {
    error: reason.to_string(),
  });
  handler.on_event(ConnectionEvent::Disconnected {
    reason: reason.to_string(),
    reason_code: None,
  });
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

/// Interactive client: send each packet immediately instead of letting Nagle's algorithm hold
/// small publishes and acks back to coalesce them.
fn interactive_network_options() -> rumqttc::NetworkOptions {
  let mut options = rumqttc::NetworkOptions::new();
  options.set_tcp_nodelay(true);
  options
}
