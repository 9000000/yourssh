use std::time::Duration;

use tokio::sync::mpsc::UnboundedReceiver;
use vnc::{PixelFormat, VncEncoding, VncError, VncEvent, X11Event};

use crate::api::{VncConfig, VncEvent as ApiEvent};
use crate::connect::vnc_connect_stage;
use crate::session::SessionCmd;

/// How often the loop pumps an incremental framebuffer-update request.
const REFRESH_INTERVAL_MS: u64 = 16;

/// Forces every pixel's alpha byte to 0xFF. VNC servers typically send 32bpp
/// pixels with the padding (alpha) byte zeroed; rendered as RGBA8888 that is
/// fully transparent, so the patch must be made opaque before it reaches Dart.
pub fn set_opaque(rgba: &mut [u8]) {
    debug_assert!(rgba.len() % 4 == 0, "set_opaque: buffer length must be a multiple of 4 (RGBA pixels)");
    for i in (3..rgba.len()).step_by(4) {
        rgba[i] = 0xFF;
    }
}

/// Maps a `vnc-rs` error to a graceful disconnect reason, or `None` if it is a
/// real error that should surface as `VncEvent::Error`.
///
/// `VncError` in 0.5.3 has no dedicated "server closed" variant; clean
/// server-side shutdowns surface as `IoError` wrapping `ConnectionReset`,
/// `BrokenPipe`, or `UnexpectedEof`.
pub fn disconnect_reason(e: &VncError) -> Option<String> {
    match e {
        VncError::ClientNotRunning => Some("connection closed".to_string()),
        VncError::IoError(io_err) => match io_err.kind() {
            std::io::ErrorKind::ConnectionReset
            | std::io::ErrorKind::BrokenPipe
            | std::io::ErrorKind::UnexpectedEof => Some("server closed the connection".to_string()),
            _ => None,
        },
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_opaque_sets_every_fourth_byte() {
        let mut buf = vec![10, 20, 30, 0, 40, 50, 60, 0];
        set_opaque(&mut buf);
        assert_eq!(buf, vec![10, 20, 30, 0xFF, 40, 50, 60, 0xFF]);
    }

    #[test]
    fn set_opaque_handles_empty() {
        let mut buf: Vec<u8> = vec![];
        set_opaque(&mut buf);
        assert!(buf.is_empty());
    }

    #[test]
    fn disconnect_reason_graceful_on_not_running() {
        assert_eq!(
            disconnect_reason(&VncError::ClientNotRunning),
            Some("connection closed".to_string())
        );
    }

    #[test]
    fn disconnect_reason_none_on_real_error() {
        assert!(disconnect_reason(&VncError::General("boom".into())).is_none());
        assert!(disconnect_reason(&VncError::WrongPassword).is_none());
    }
}
