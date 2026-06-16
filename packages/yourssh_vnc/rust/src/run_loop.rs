use std::time::Duration;

use tokio::sync::mpsc::UnboundedReceiver;
use vnc::VncError;

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

pub async fn run_session(
    cfg: VncConfig,
    mut cmd_rx: UnboundedReceiver<SessionCmd>,
    sink: impl Fn(ApiEvent) + Send + Sync + 'static,
) {
    match run_session_inner(cfg, &mut cmd_rx, &sink).await {
        Ok(reason) => sink(ApiEvent::Disconnected { reason }),
        Err(e) => sink(ApiEvent::Error { message: format!("{e:#}") }),
    }
}

async fn run_session_inner(
    cfg: VncConfig,
    cmd_rx: &mut UnboundedReceiver<SessionCmd>,
    sink: &(impl Fn(ApiEvent) + Send + Sync),
) -> anyhow::Result<String> {
    let vnc = vnc_connect_stage(&cfg).await?;

    let mut connected = false;
    let mut refresh = tokio::time::interval(Duration::from_millis(REFRESH_INTERVAL_MS));

    loop {
        tokio::select! {
            ev = vnc.recv_event() => {
                match ev {
                    Ok(vnc::VncEvent::SetResolution(screen)) => {
                        if !connected {
                            connected = true;
                            sink(ApiEvent::Connected { width: screen.width, height: screen.height });
                        } else {
                            sink(ApiEvent::Resize { width: screen.width, height: screen.height });
                        }
                    }
                    Ok(vnc::VncEvent::RawImage(rect, mut data)) => {
                        set_opaque(&mut data);
                        sink(ApiEvent::FrameUpdate {
                            x: rect.x, y: rect.y, width: rect.width, height: rect.height, rgba: data,
                        });
                    }
                    Ok(vnc::VncEvent::Text(text)) => sink(ApiEvent::ClipboardText { text }),
                    Ok(vnc::VncEvent::Bell) => sink(ApiEvent::Bell),
                    Ok(vnc::VncEvent::Error(msg)) => {
                        return Err(anyhow::anyhow!("{msg}"));
                    }
                    Ok(_) => {}
                    Err(e) => {
                        return match disconnect_reason(&e) {
                            Some(reason) => Ok(reason),
                            None => Err(e.into()),
                        };
                    }
                }
            }
            cmd = cmd_rx.recv() => {
                match cmd {
                    None | Some(SessionCmd::Disconnect) => {
                        let _ = vnc.close().await;
                        return Ok("disconnected by user".into());
                    }
                }
            }
            _ = refresh.tick() => {
                let _ = vnc.input(vnc::X11Event::Refresh).await;
            }
        }
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
