mod client;
mod error;
mod types;

pub use client::MqttClient;
pub use error::MqttError;
pub use types::{
  ConnectionConfig, ConnectionEvent, LastWillConfig, MqttEventHandler, MqttMessage, MqttVersion, QosLevel,
  SubscriptionRequest, UserProperty,
};

use tracing_subscriber::{EnvFilter, fmt, prelude::*};

#[uniffi::export]
pub fn init_logging() {
  tracing_subscriber::registry()
    .with(fmt::layer().with_ansi(false))
    .with(EnvFilter::from_default_env().add_directive("mqtee_core=debug".parse().expect("static directive must parse")))
    .try_init()
    .ok();
}

uniffi::setup_scaffolding!();
