use std::sync::Arc;

use rumqttc::tokio_rustls::rustls;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, PrivateKeyDer, ServerName, UnixTime};
use rustls_platform_verifier::BuilderVerifierExt;
use tracing::warn;

use crate::error::MqttError;
use crate::types::ConnectionConfig;

pub(super) fn create_tls_config(config: &ConnectionConfig) -> Result<rumqttc::TlsConfiguration, MqttError> {
  let tls_config = if config.allow_insecure_tls {
    warn!("Insecure TLS mode enabled - certificate verification is disabled");

    let builder = rustls::ClientConfig::builder()
      .dangerous()
      .with_custom_certificate_verifier(Arc::new(InsecureCertVerifier));
    with_client_auth(builder, config)?
  } else if let Some(ca_cert) = &config.ca_certificate {
    // A user-supplied CA pins trust to that CA alone (private brokers, self-signed chains).
    let mut root_store = rustls::RootCertStore::empty();
    for cert_result in CertificateDer::pem_slice_iter(ca_cert) {
      match cert_result {
        Ok(cert) => root_store.add(cert).map_err(|e| MqttError::TlsError(e.to_string()))?,
        Err(e) => warn!("Skipping unparseable certificate in chain: {}", e),
      }
    }
    if root_store.is_empty() {
      return Err(MqttError::TlsError("No valid certificate found in CA file".to_string()));
    }

    with_client_auth(
      rustls::ClientConfig::builder().with_root_certificates(root_store),
      config,
    )?
  } else {
    // Default trust comes from the OS (Security.framework): system roots, user and MDM-installed
    // CAs, and Apple's revocation and distrust decisions, updated with the OS instead of the app.
    let builder = rustls::ClientConfig::builder()
      .with_platform_verifier()
      .map_err(|e| MqttError::TlsError(e.to_string()))?;
    with_client_auth(builder, config)?
  };

  Ok(rumqttc::TlsConfiguration::Rustls(Arc::new(tls_config)))
}

fn with_client_auth(
  builder: rustls::ConfigBuilder<rustls::ClientConfig, rustls::client::WantsClientCert>,
  config: &ConnectionConfig,
) -> Result<rustls::ClientConfig, MqttError> {
  match parse_client_cert_key(config)? {
    Some((certs, key)) => builder
      .with_client_auth_cert(certs, key)
      .map_err(|e| MqttError::TlsError(e.to_string())),
    None => Ok(builder.with_no_client_auth()),
  }
}

fn parse_client_cert_key(
  config: &ConnectionConfig,
) -> Result<Option<(Vec<CertificateDer<'static>>, PrivateKeyDer<'static>)>, MqttError> {
  match (&config.client_certificate, &config.client_key) {
    (Some(client_cert), Some(client_key)) => {
      let certs: Vec<_> = CertificateDer::pem_slice_iter(client_cert)
        .filter_map(|r| match r {
          Ok(cert) => Some(cert),
          Err(e) => {
            warn!("Skipping unparseable client certificate: {}", e);
            None
          }
        })
        .collect();

      let key = PrivateKeyDer::from_pem_slice(client_key).map_err(|e| match e {
        rustls::pki_types::pem::Error::NoItemsFound => MqttError::TlsError("No private key found".to_string()),
        e => MqttError::TlsError(e.to_string()),
      })?;

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
