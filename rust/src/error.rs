use thiserror::Error;

#[derive(Debug, Error, uniffi::Error)]
pub enum MqttError {
    #[error("Connection failed: {0}")]
    ConnectionFailed(String),

    #[error("Not connected to broker")]
    NotConnected,

    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),

    #[error("TLS error: {0}")]
    TlsError(String),

    #[error("Internal error: {0}")]
    InternalError(String),
}

impl From<rumqttc::ClientError> for MqttError {
    fn from(err: rumqttc::ClientError) -> Self {
        MqttError::InternalError(err.to_string())
    }
}

impl From<rumqttc::v5::ClientError> for MqttError {
    fn from(err: rumqttc::v5::ClientError) -> Self {
        MqttError::InternalError(err.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn connection_failed_display_includes_message() {
        let err = MqttError::ConnectionFailed("timeout".into());
        assert_eq!(format!("{err}"), "Connection failed: timeout");
    }

    #[test]
    fn not_connected_display() {
        let err = MqttError::NotConnected;
        assert_eq!(format!("{err}"), "Not connected to broker");
    }

    #[test]
    fn invalid_config_display_includes_message() {
        let err = MqttError::InvalidConfig("bad port".into());
        assert_eq!(format!("{err}"), "Invalid configuration: bad port");
    }

    #[test]
    fn tls_error_display() {
        let err = MqttError::TlsError("cert expired".into());
        assert_eq!(format!("{err}"), "TLS error: cert expired");
    }

    #[test]
    fn internal_error_display() {
        let err = MqttError::InternalError("oops".into());
        assert_eq!(format!("{err}"), "Internal error: oops");
    }

    #[test]
    fn from_v311_client_error_produces_internal_error() {
        let client_err =
            rumqttc::ClientError::Request(rumqttc::Request::Disconnect(rumqttc::Disconnect));
        let mqtt_err: MqttError = client_err.into();
        match mqtt_err {
            MqttError::InternalError(msg) => assert!(!msg.is_empty()),
            other => panic!("expected InternalError, got: {other:?}"),
        }
    }
}
