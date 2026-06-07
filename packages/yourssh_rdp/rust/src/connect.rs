use std::sync::{Arc, Mutex};

use anyhow::Context;
use ironrdp::connector::{self, ClientConnector, Credentials, ServerName};
use ironrdp::pdu::gcc::KeyboardType;
use ironrdp::pdu::rdp::capability_sets::MajorPlatformType;
use ironrdp_cliprdr::CliprdrClient;
use sha2::{Digest, Sha256};
use tokio::net::TcpStream;
use tokio::sync::mpsc::{self, UnboundedReceiver};

use crate::api::{RdpCertInfo, RdpConfig};
use crate::clipboard::{CliprdrMsg, ClipboardShared, SimpleClipboard};

pub struct Connected {
    pub framed: ironrdp_tokio::TokioFramed<ironrdp_tls::TlsStream<TcpStream>>,
    pub connection_result: connector::ConnectionResult,
    pub cert: RdpCertInfo,
    pub cliprdr_rx: UnboundedReceiver<CliprdrMsg>,
    pub clipboard_shared: Arc<Mutex<ClipboardShared>>,
}

/// Connection outcome: either fully connected, or aborted pre-auth because
/// the server certificate does not match the pinned fingerprint.
pub enum ConnectOutcome {
    Connected(Box<Connected>),
    /// The TLS certificate's fingerprint differs from `expected_fingerprint`.
    /// CredSSP never ran — no credentials were sent.
    CertMismatch { fingerprint: String },
}

pub fn build_connector_config(cfg: &RdpConfig) -> connector::Config {
    connector::Config {
        credentials: Credentials::UsernamePassword {
            username: cfg.username.clone(),
            password: cfg.password.clone(),
        },
        domain: cfg.domain.clone(),
        enable_tls: true,
        enable_credssp: cfg.security != "tls",
        desktop_size: connector::DesktopSize { width: cfg.width, height: cfg.height },
        desktop_scale_factor: 0,
        bitmap: None,
        client_build: 0,
        client_name: "yourssh".to_owned(),
        client_dir: "C:\\Windows\\System32\\mstscax.dll".to_owned(),
        platform: MajorPlatformType::UNSPECIFIED,
        enable_server_pointer: false,
        autologon: true,
        pointer_software_rendering: true,
        request_data: None,
        hardware_id: None,
        keyboard_type: KeyboardType::IbmEnhanced,
        keyboard_subtype: 0,
        keyboard_functional_keys_count: 12,
        keyboard_layout: 0x0409, // en-US
        ime_file_name: String::new(),
        dig_product_id: String::new(),
        alternate_shell: String::new(),
        work_dir: String::new(),
        enable_audio_playback: false,
        performance_flags: Default::default(),
        license_cache: None,
        timezone_info: Default::default(),
        compression_type: None,
        multitransport_flags: None,
    }
}

pub async fn rdp_connect_stage(cfg: &RdpConfig) -> anyhow::Result<ConnectOutcome> {
    let addr = format!("{}:{}", cfg.target_host, cfg.target_port);
    let stream = TcpStream::connect(&addr).await.context("TCP connect")?;
    let client_addr = stream.local_addr().context("local addr")?;

    let mut framed = ironrdp_tokio::TokioFramed::new(stream);
    let mut connector = ClientConnector::new(build_connector_config(cfg), client_addr);

    // Attach clipboard SVC before negotiation so the channel is announced.
    let (cliprdr_tx, cliprdr_rx) = mpsc::unbounded_channel::<CliprdrMsg>();
    let clipboard_shared = Arc::new(Mutex::new(ClipboardShared::default()));
    let backend = SimpleClipboard::new(cliprdr_tx, Arc::clone(&clipboard_shared));
    connector.attach_static_channel(CliprdrClient::new(Box::new(backend)));

    let should_upgrade = ironrdp_tokio::connect_begin(&mut framed, &mut connector).await?;

    let initial_stream = framed.into_inner_no_leftover();
    let (upgraded_stream, tls_cert) =
        ironrdp_tls::upgrade(initial_stream, &cfg.target_host).await?;
    let upgraded = ironrdp_tokio::mark_as_upgraded(should_upgrade, &mut connector);

    // Hard-fail on extraction: degrading to an empty key would make every
    // such server hash to the constant empty-input SHA-256, silently
    // defeating fingerprint pinning (and weakening CredSSP channel binding).
    let server_public_key = ironrdp_tls::extract_tls_server_public_key(&tls_cert)
        .map(|b| b.to_vec())
        .context("extract TLS server public key")?;
    let fingerprint = hex(&Sha256::digest(&server_public_key));

    // Pinned-fingerprint check BEFORE CredSSP — a mismatch must abort without
    // transmitting credentials to a possibly-MITM endpoint.
    if let Some(expected) = &cfg.expected_fingerprint {
        if !expected.eq_ignore_ascii_case(&fingerprint) {
            return Ok(ConnectOutcome::CertMismatch { fingerprint });
        }
    }

    let cert = RdpCertInfo {
        sha256_fingerprint: fingerprint,
        subject: cfg.target_host.clone(),
    };

    let mut framed = ironrdp_tokio::TokioFramed::new(upgraded_stream);
    let server_name = ServerName::try_from(cfg.target_host.clone())
        .context("invalid server name")?;

    let mut network_client = ironrdp_tokio::reqwest::ReqwestNetworkClient::new();
    let connection_result = ironrdp_tokio::connect_finalize(
        upgraded,
        connector,
        &mut framed,
        &mut network_client,
        server_name,
        server_public_key,
        None,
    )
    .await?;

    Ok(ConnectOutcome::Connected(Box::new(Connected {
        framed,
        connection_result,
        cert,
        cliprdr_rx,
        clipboard_shared,
    })))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cfg(security: &str) -> RdpConfig {
        RdpConfig {
            target_host: "h".into(),
            target_port: 3389,
            username: "u".into(),
            password: "p".into(),
            domain: None,
            width: 1280,
            height: 800,
            security: security.into(),
            expected_fingerprint: None,
        }
    }

    #[test]
    fn tls_mode_disables_credssp() {
        assert!(!build_connector_config(&cfg("tls")).enable_credssp);
        assert!(build_connector_config(&cfg("auto")).enable_credssp);
        assert!(build_connector_config(&cfg("nla")).enable_credssp);
    }

    #[test]
    fn hex_lowercase() {
        assert_eq!(hex(&[0xAB, 0x01]), "ab01");
    }
}
