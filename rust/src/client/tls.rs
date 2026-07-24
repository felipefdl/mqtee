use std::io::BufReader;
use std::sync::Arc;

use rumqttc::tokio_rustls::rustls;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use tracing::warn;

use crate::error::MqttError;
use crate::types::ConnectionConfig;

pub(super) fn create_tls_config(config: &ConnectionConfig) -> Result<rumqttc::TlsConfiguration, MqttError> {
  let tls_config = if config.allow_insecure_tls {
    warn!("Insecure TLS mode enabled - certificate verification is disabled");

    let builder = rustls::ClientConfig::builder()
      .dangerous()
      .with_custom_certificate_verifier(Arc::new(InsecureCertVerifier));

    if let Some((certs, key)) = parse_client_cert_key(config)? {
      builder
        .with_client_auth_cert(certs, key)
        .map_err(|e| MqttError::TlsError(e.to_string()))?
    } else {
      builder.with_no_client_auth()
    }
  } else {
    let mut root_store = rustls::RootCertStore::empty();

    if let Some(ca_cert) = &config.ca_certificate {
      let mut reader = BufReader::new(ca_cert.as_slice());
      let certs = rustls_pemfile::certs(&mut reader).collect::<Vec<_>>();

      for cert_result in certs {
        match cert_result {
          Ok(cert) => {
            root_store
              .add(cert)
              .map_err(|e| MqttError::TlsError(e.to_string()))?;
          }
          Err(e) => {
            warn!("Skipping unparseable certificate in chain: {}", e);
          }
        }
      }
    } else {
      root_store.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    }

    if let Some((certs, key)) = parse_client_cert_key(config)? {
      rustls::ClientConfig::builder()
        .with_root_certificates(root_store)
        .with_client_auth_cert(certs, key)
        .map_err(|e| MqttError::TlsError(e.to_string()))?
    } else {
      rustls::ClientConfig::builder()
        .with_root_certificates(root_store)
        .with_no_client_auth()
    }
  };

  Ok(rumqttc::TlsConfiguration::Rustls(Arc::new(tls_config)))
}

fn parse_client_cert_key(
  config: &ConnectionConfig,
) -> Result<
  Option<(
    Vec<CertificateDer<'static>>,
    rustls::pki_types::PrivateKeyDer<'static>,
  )>,
  MqttError,
> {
  match (&config.client_certificate, &config.client_key) {
    (Some(client_cert), Some(client_key)) => {
      let mut cert_reader = BufReader::new(client_cert.as_slice());
      let certs: Vec<_> = rustls_pemfile::certs(&mut cert_reader)
        .filter_map(|r| match r {
          Ok(cert) => Some(cert),
          Err(e) => {
            warn!("Skipping unparseable client certificate: {}", e);
            None
          }
        })
        .collect();

      let mut key_reader = BufReader::new(client_key.as_slice());
      let key = rustls_pemfile::private_key(&mut key_reader)
        .map_err(|e| MqttError::TlsError(e.to_string()))?
        .ok_or_else(|| MqttError::TlsError("No private key found".to_string()))?;

      Ok(Some((certs, key)))
    }
    _ => Ok(None),
  }
}

// ---------------------------------------------------------------------------
// Insecure TLS verifier
// ---------------------------------------------------------------------------

#[derive(Debug)]
struct InsecureCertVerifier;

impl ServerCertVerifier for InsecureCertVerifier {
  fn verify_server_cert(
    &self,
    _end_entity: &CertificateDer<'_>,
    _intermediates: &[CertificateDer<'_>],
    _server_name: &ServerName<'_>,
    _ocsp_response: &[u8],
    _now: UnixTime,
  ) -> Result<ServerCertVerified, rustls::Error> {
    Ok(ServerCertVerified::assertion())
  }

  fn verify_tls12_signature(
    &self,
    _message: &[u8],
    _cert: &CertificateDer<'_>,
    _dss: &rustls::DigitallySignedStruct,
  ) -> Result<HandshakeSignatureValid, rustls::Error> {
    Ok(HandshakeSignatureValid::assertion())
  }

  fn verify_tls13_signature(
    &self,
    _message: &[u8],
    _cert: &CertificateDer<'_>,
    _dss: &rustls::DigitallySignedStruct,
  ) -> Result<HandshakeSignatureValid, rustls::Error> {
    Ok(HandshakeSignatureValid::assertion())
  }

  fn supported_verify_schemes(&self) -> Vec<rustls::SignatureScheme> {
    use rustls::SignatureScheme;
    vec![
      SignatureScheme::RSA_PKCS1_SHA256,
      SignatureScheme::RSA_PKCS1_SHA384,
      SignatureScheme::RSA_PKCS1_SHA512,
      SignatureScheme::ECDSA_NISTP256_SHA256,
      SignatureScheme::ECDSA_NISTP384_SHA384,
      SignatureScheme::RSA_PSS_SHA256,
      SignatureScheme::RSA_PSS_SHA384,
      SignatureScheme::RSA_PSS_SHA512,
      SignatureScheme::ED25519,
    ]
  }
}
