use futures::FutureExt;
use tokio::sync::mpsc;

use crate::frb_generated::StreamSink;
use crate::session::{registry, SessionCmd};

#[derive(Clone)]
pub struct RdpConfig {
    pub target_host: String,
    pub target_port: u16,
    pub username: String,
    pub password: String,
    pub domain: Option<String>,
    pub width: u16,
    pub height: u16,
    /// "auto" | "nla" | "tls"
    pub security: String,
    /// Previously pinned SHA-256 fingerprint of the server public key.
    /// When set, the TLS handshake result is compared BEFORE CredSSP runs —
    /// a mismatch aborts the connection without ever sending credentials.
    pub expected_fingerprint: Option<String>,
}

#[derive(Clone)]
pub struct RdpCertInfo {
    pub sha256_fingerprint: String,
    pub subject: String,
}

#[derive(Clone)]
pub enum RdpEvent {
    /// Always the first event. Carries session id (FRB discards Rust return
    /// value of StreamSink-taking functions — issue #2233).
    Started { session_id: u32 },
    /// Connection fully established. Carries the server-negotiated desktop
    /// size, which may differ from the requested one — the Dart framebuffer
    /// must be sized from these values, not the request.
    Connected { cert: RdpCertInfo, desktop_width: u16, desktop_height: u16 },
    /// The server's certificate does not match `expected_fingerprint`.
    /// Emitted before any credentials are sent; the session then aborts.
    CertMismatch { fingerprint: String },
    FrameUpdate { x: u16, y: u16, width: u16, height: u16, rgba: Vec<u8> },
    ClipboardText { text: String },
    Disconnected { reason: String },
    Error { message: String },
}

pub fn rdp_lib_version() -> String {
    format!("yourssh_rdp {}", env!("CARGO_PKG_VERSION"))
}

static RUNTIME: std::sync::OnceLock<tokio::runtime::Runtime> = std::sync::OnceLock::new();

fn runtime() -> &'static tokio::runtime::Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .expect("tokio runtime")
    })
}

/// Removes the registry entry even if the spawned future is dropped before
/// completing (runtime shutdown, cancellation) — a bare `registry::remove`
/// at the end of the task body would leak the entry in those cases.
struct RemoveOnDrop(u32);

impl Drop for RemoveOnDrop {
    fn drop(&mut self) {
        registry::remove(self.0);
    }
}

pub fn rdp_connect(config: RdpConfig, sink: StreamSink<RdpEvent>) {
    let (tx, rx) = mpsc::unbounded_channel::<SessionCmd>();
    let id = registry::insert(tx);
    let _ = sink.add(RdpEvent::Started { session_id: id });
    let emit_sink = sink.clone();
    let panic_sink = sink.clone();
    let emit = move |ev: RdpEvent| {
        let _ = emit_sink.add(ev);
    };
    runtime().spawn(async move {
        let _guard = RemoveOnDrop(id);
        let result = std::panic::AssertUnwindSafe(
            crate::run_loop::run_session(config, rx, emit)
        )
        .catch_unwind()
        .await;
        if let Err(_panic) = result {
            let _ = panic_sink.add(RdpEvent::Error {
                message: "rdp session panicked".into(),
            });
        }
    });
}

pub fn rdp_disconnect(session_id: u32) {
    registry::send(session_id, SessionCmd::Disconnect);
}

pub fn rdp_send_mouse(session_id: u32, x: u16, y: u16, button: u8, action: u8) {
    registry::send(session_id, SessionCmd::Mouse { x, y, button, action });
}

pub fn rdp_send_wheel(session_id: u32, delta: i16, horizontal: bool) {
    registry::send(session_id, SessionCmd::Wheel { delta, horizontal });
}

pub fn rdp_send_key(session_id: u32, scancode: u16, extended: bool, down: bool) {
    registry::send(session_id, SessionCmd::Key { scancode, extended, down });
}

pub fn rdp_send_clipboard_text(session_id: u32, text: String) {
    registry::send(session_id, SessionCmd::ClipboardText(text));
}
