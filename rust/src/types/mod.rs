mod conversions;
#[cfg(test)]
mod tests;

use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum MqttVersion {
  V311,
  V5,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum QosLevel {
  AtMostOnce,
  AtLeastOnce,
  ExactlyOnce,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct ConnectionConfig {
  pub client_id: String,
  pub host: String,
  pub port: u16,
  pub mqtt_version: MqttVersion,
  pub clean_session: bool,
  pub keep_alive_secs: u16,
  pub username: Option<String>,
  pub password: Option<String>,
  pub use_tls: bool,
  pub allow_insecure_tls: bool,
  pub ca_certificate: Option<Vec<u8>>,
  pub client_certificate: Option<Vec<u8>>,
  pub client_key: Option<Vec<u8>>,
  pub last_will: Option<LastWillConfig>,
  pub session_expiry_interval: Option<u32>,
  pub max_packet_size: Option<u32>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct LastWillConfig {
  pub topic: String,
  pub message: String,
  pub qos: QosLevel,
  pub retain: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct UserProperty {
  pub key: String,
  pub value: String,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct MqttMessage {
  pub topic: String,
  pub payload: Vec<u8>,
  pub qos: QosLevel,
  pub retain: bool,
  pub timestamp_ms: u64,
  pub content_type: Option<String>,
  pub response_topic: Option<String>,
  pub correlation_data: Option<Vec<u8>>,
  pub user_properties: Vec<UserProperty>,
  pub payload_format_indicator: Option<u8>,
  pub message_expiry_interval: Option<u32>,
}

impl MqttMessage {
  pub fn new(topic: String, payload: Vec<u8>, qos: QosLevel, retain: bool) -> Self {
    let timestamp_ms = SystemTime::now()
      .duration_since(UNIX_EPOCH)
      .map(|d| d.as_millis() as u64)
      .unwrap_or(0);

    Self {
      topic,
      payload,
      qos,
      retain,
      timestamp_ms,
      content_type: None,
      response_topic: None,
      correlation_data: None,
      user_properties: Vec::new(),
      payload_format_indicator: None,
      message_expiry_interval: None,
    }
  }

  #[allow(clippy::too_many_arguments)]
  pub fn with_v5_properties(
    topic: String,
    payload: Vec<u8>,
    qos: QosLevel,
    retain: bool,
    content_type: Option<String>,
    response_topic: Option<String>,
    correlation_data: Option<Vec<u8>>,
    user_properties: Vec<UserProperty>,
    payload_format_indicator: Option<u8>,
    message_expiry_interval: Option<u32>,
  ) -> Self {
    let timestamp_ms = SystemTime::now()
      .duration_since(UNIX_EPOCH)
      .map(|d| d.as_millis() as u64)
      .unwrap_or(0);

    Self {
      topic,
      payload,
      qos,
      retain,
      timestamp_ms,
      content_type,
      response_topic,
      correlation_data,
      user_properties,
      payload_format_indicator,
      message_expiry_interval,
    }
  }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct SubscriptionRequest {
  pub topic: String,
  pub qos: QosLevel,
  pub no_local: bool,
  pub retain_as_published: bool,
  pub retain_handling: u8,
}

#[derive(Debug, Clone, uniffi::Enum)]
pub enum ConnectionEvent {
  Connected,
  Disconnected {
    reason: String,
    reason_code: Option<String>,
  },
  MessageReceived {
    message: MqttMessage,
  },
  PublishAck {
    packet_id: u16,
  },
  Error {
    error: String,
  },

  SubscribeAck {
    packet_id: u16,
    return_codes: String,
    reason_codes_detail: Option<String>,
  },
  UnsubscribeAck {
    packet_id: u16,
  },

  ConnAckDetails {
    session_present: bool,
    return_code: String,
    reason_string: Option<String>,
    assigned_client_id: Option<String>,
    server_keep_alive: Option<u16>,
    maximum_qos: Option<u8>,
    retain_available: Option<bool>,
    wildcard_subscription_available: Option<bool>,
    subscription_identifiers_available: Option<bool>,
    shared_subscription_available: Option<bool>,
    maximum_packet_size: Option<u32>,
  },
  PubRecReceived {
    packet_id: u16,
  },
  PubRelReceived {
    packet_id: u16,
  },
  PubCompReceived {
    packet_id: u16,
  },
  PingResponseReceived,

  PublishSent {
    packet_id: u16,
  },
  SubscribeSent {
    packet_id: u16,
  },
  UnsubscribeSent {
    packet_id: u16,
  },
  PublishAckSent {
    packet_id: u16,
  },
  PubRecSent {
    packet_id: u16,
  },
  PubCompSent {
    packet_id: u16,
  },
  PingSent,
  DisconnectSent,
}

#[uniffi::export(callback_interface)]
pub trait MqttEventHandler: Send + Sync {
  fn on_event(&self, event: ConnectionEvent);
}
