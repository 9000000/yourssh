use futures::FutureExt;
use tokio::sync::mpsc;

use crate::frb_generated::StreamSink;
use crate::session::{registry, SessionCmd};

#[derive(Clone)]
pub struct VncConfig {
    pub target_host: String,
    pub target_port: u16,
    pub username: String,
    pub password: String,
}

#[derive(Clone)]
pub enum VncEvent {
    /// Always the first event. Carries the session id.
    Started { session_id: u32 },
    /// Connection established. Server's initial framebuffer size.
    Connected { width: u16, height: u16 },
    /// Server-driven desktop-size change after connect.
    Resize { width: u16, height: u16 },
    /// A self-contained RGBA patch. `rgba` length is width * height * 4, alpha forced opaque.
    FrameUpdate { x: u16, y: u16, width: u16, height: u16, rgba: Vec<u8> },
    /// Server clipboard (cut-text).
    ClipboardText { text: String },
    /// Server bell.
    Bell,
    Disconnected { reason: String },
    Error { message: String },
}

pub fn vnc_lib_version() -> String {
    format!("yourssh_vnc {}", env!("CARGO_PKG_VERSION"))
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

struct RemoveOnDrop(u32);

impl Drop for RemoveOnDrop {
    fn drop(&mut self) {
        registry::remove(self.0);
    }
}

pub fn vnc_connect(config: VncConfig, sink: StreamSink<VncEvent>) {
    let (tx, rx) = mpsc::unbounded_channel::<SessionCmd>();
    let id = registry::insert(tx);
    let _ = sink.add(VncEvent::Started { session_id: id });
    let emit_sink = sink.clone();
    let panic_sink = sink.clone();
    let emit = move |ev: VncEvent| {
        let _ = emit_sink.add(ev);
    };
    runtime().spawn(async move {
        let _guard = RemoveOnDrop(id);
        let result = std::panic::AssertUnwindSafe(crate::run_loop::run_session(config, rx, emit))
            .catch_unwind()
            .await;
        if let Err(_panic) = result {
            let _ = panic_sink.add(VncEvent::Error {
                message: "vnc session panicked".into(),
            });
        }
    });
}

pub fn vnc_disconnect(session_id: u32) {
    registry::send(session_id, SessionCmd::Disconnect);
}

pub fn vnc_send_pointer(session_id: u32, x: u16, y: u16, button_mask: u8) {
    registry::send(session_id, SessionCmd::Pointer { x, y, button_mask });
}

pub fn vnc_send_key(session_id: u32, keysym: u32, down: bool) {
    registry::send(session_id, SessionCmd::Key { keysym, down });
}
