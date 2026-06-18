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
/// In vnc-rs 0.5.3, `recv_event()` only ever fails with `ClientNotRunning` once
/// the session ends: a clean server EOF is swallowed by the decode thread, which
/// then closes the event channel. Mid-stream protocol/IO failures arrive
/// separately as `Ok(VncEvent::Error(_))` and never reach this function.
pub fn disconnect_reason(e: &VncError) -> Option<String> {
    match e {
        VncError::ClientNotRunning => Some("connection closed".to_string()),
        _ => None,
    }
}

/// Translates an input `SessionCmd` into the `vnc-rs` event to feed
/// `client.input()`. Returns `None` for non-input commands (Disconnect).
pub fn input_event(cmd: &SessionCmd) -> Option<vnc::X11Event> {
    match cmd {
        SessionCmd::Pointer { x, y, button_mask } => {
            Some(vnc::X11Event::PointerEvent(vnc::ClientMouseEvent {
                position_x: *x,
                position_y: *y,
                bottons: *button_mask,
            }))
        }
        SessionCmd::Key { keysym, down } => Some(vnc::X11Event::KeyEvent(
            vnc::ClientKeyEvent { keycode: *keysym, down: *down },
        )),
        SessionCmd::ClipboardText(text) => {
            Some(vnc::X11Event::CopyText(text.clone()))
        }
        SessionCmd::Disconnect => None,
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
    // Don't replay refresh ticks that piled up while the loop was busy decoding a
    // burst of frames — one incremental request on resume is enough.
    refresh.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        tokio::select! {
            // `biased` ensures cmd_rx is checked first every iteration so a
            // Disconnect command is never starved by a high-frequency frame stream.
            biased;

            cmd = cmd_rx.recv() => {
                match cmd {
                    None => {
                        let _ = vnc.close().await;
                        return Ok("session closed".into());
                    }
                    Some(SessionCmd::Disconnect) => {
                        // error = already closed; still emit Disconnected
                        let _ = vnc.close().await;
                        return Ok("disconnected by user".into());
                    }
                    Some(input) => {
                        // Ignore send errors — if the client is closed,
                        // recv_event() surfaces it on the next iteration.
                        if let Some(ev) = input_event(&input) {
                            let _ = vnc.input(ev).await;
                        }
                    }
                }
            }
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
                    // SetPixelFormat: we called set_pixel_format(rgba()) on the
                    // connector, so this variant should never arrive. Ignore if it does.
                    Ok(vnc::VncEvent::SetPixelFormat(_)) => {}
                    // CopyRect / Tight-JPEG / cursor: encodings not negotiated; ignore.
                    Ok(vnc::VncEvent::Copy(..))
                    | Ok(vnc::VncEvent::JpegImage(..))
                    | Ok(vnc::VncEvent::SetCursor(..)) => {}
                    // Catch-all for any variants added in future vnc-rs releases.
                    Ok(_) => {}
                    Err(e) => {
                        return match disconnect_reason(&e) {
                            Some(reason) => Ok(reason),
                            None => Err(e.into()),
                        };
                    }
                }
            }
            _ = refresh.tick() => {
                // Ignore send errors — if the client is closed, recv_event() will
                // surface it on the next iteration.
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

    #[test]
    fn input_event_maps_pointer() {
        match input_event(&SessionCmd::Pointer { x: 10, y: 20, button_mask: 0x05 }) {
            Some(vnc::X11Event::PointerEvent(m)) => {
                assert_eq!(m.position_x, 10);
                assert_eq!(m.position_y, 20);
                assert_eq!(m.bottons, 0x05);
            }
            other => panic!("expected PointerEvent, got {other:?}"),
        }
    }

    #[test]
    fn input_event_maps_key() {
        match input_event(&SessionCmd::Key { keysym: 0xFF0D, down: true }) {
            Some(vnc::X11Event::KeyEvent(k)) => {
                assert_eq!(k.keycode, 0xFF0D);
                assert!(k.down);
            }
            other => panic!("expected KeyEvent, got {other:?}"),
        }
    }

    #[test]
    fn input_event_none_for_disconnect() {
        assert!(input_event(&SessionCmd::Disconnect).is_none());
    }

    #[test]
    fn input_event_maps_clipboard() {
        match input_event(&SessionCmd::ClipboardText("hi".into())) {
            Some(vnc::X11Event::CopyText(t)) => assert_eq!(t, "hi"),
            other => panic!("expected CopyText, got {other:?}"),
        }
    }
}
