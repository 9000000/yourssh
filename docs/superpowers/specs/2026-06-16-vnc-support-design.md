# VNC Support — Design Spec

**Date:** 2026-06-16
**Status:** Approved (architecture); Milestone 1 ready to plan

## Overview

Add a VNC (RFB) client as a first-class connection protocol alongside SSH and
RDP. The implementation mirrors the existing `yourssh_rdp` integration: a new
`packages/yourssh_vnc` Rust crate (engine: `vnc-rs`) bridged via
flutter_rust_bridge v2, a `VncSession` implementing `AppSession`, and a
`VncWorkspace` UI, with SSH tunneling reusing the existing one-shot loopback
proxy. Target servers for the first cut are **Linux VNC servers** (TigerVNC,
x11vnc, TightVNC).

## Scope

**In scope (full feature, decomposed into milestones below):**
- New `packages/yourssh_vnc` crate over `vnc-rs` (async/tokio, RFB client)
- Encodings: Raw, CopyRect, Tight, ZRLE (whatever `vnc-rs` negotiates)
- Auth: `None` + `VNC Authentication` (DES challenge with password)
- `HostProtocol.vnc` (default port 5900), password from secure storage
- `VncSession implements AppSession` — framebuffer + `ui.Image`, status, latest-wins decode
- `VncWorkspace` UI with fullscreen parity (hover pill, toolbar)
- Mouse + keyboard input (X11 keysym mapping)
- Clipboard (`Client/ServerCutText`) + auto-resize (`SetDesktopSize` / ExtendedDesktopSize)
- SSH tunneling via a generalized loopback proxy (shared with RDP)
- Tests: Rust unit, Dart FRB roundtrip, integration screenshots against a VNC container

**Out of scope (initial):**
- macOS Screen Sharing / Apple Remote Desktop auth (DH-based)
- RealVNC RA2 and VeNCrypt/TLS auth
- UltraVNC MS-Logon
- TOFU certificate pinning — **N/A for plain VNC** (no TLS layer; security is the
  SSH tunnel). This is a deliberate divergence from RDP, not a gap.

## Architecture

Parallels `yourssh_rdp` one-to-one. The RDP crate already runs on a tokio
multi-thread runtime and exposes a `StreamSink<RdpEvent>` event bus; `vnc-rs`
is async/tokio so the same run-loop shape applies.

```
Flutter UI (VncWorkspace)
  └── SessionProvider.connectVnc → VncSession (AppSession)
        └── VncClient (FRB) ── StreamSink<VncEvent> ──┐
              └── packages/yourssh_vnc (Rust)         │
                    └── vnc-rs (RFB client over TCP)  │
        └── loopback proxy (SSH-tunneled dials) ──────┘
```

### Package layout (mirrors `yourssh_rdp`)

```
packages/yourssh_vnc/
  build.sh / build.ps1            # build + copy lib into assets/native/ (gitignored)
  rust/Cargo.toml                 # vnc-rs, flutter_rust_bridge =2.12.0, tokio, anyhow
  rust/src/
    lib.rs
    api.rs                        # VncConfig, VncEvent, VncClient surface
    connect.rs                    # TCP connect + RFB handshake + auth
    run_loop.rs                   # framebuffer-update loop → StreamSink<VncEvent>
    input.rs                      # pointer/key → RFB messages
    clipboard.rs                  # cut-text both directions
    session.rs                    # shared session state
  lib/yourssh_vnc.dart
  lib/src/vnc_client.dart
  lib/src/native_loader.dart
  lib/src/generated/...           # frb_generated
  test/frb_roundtrip_test.dart
```

## Components

### Rust crate (`packages/yourssh_vnc`)

- **`VncConfig`** — host, port, username (optional for VNC), password, requested
  encodings/quality, optional shared-flag. No domain, no security mode, no
  expected fingerprint.
- **`VncEvent`** (FRB enum / StreamSink): `connected { width, height, name }`,
  `framebuffer { x, y, width, height, pixels }` (BGRA, latest-wins on the Dart
  side), `clipboard { text }`, `bell`, `disconnected`, `error { message }`,
  `authFailed`.
- **`VncClient`** — `ensureInitialized()` lazy native load + FRB init on first
  connect (no init in `main.dart`, matching `RdpClient`); `connect(config, sink)`;
  `pointerEvent(x, y, buttonMask)`; `keyEvent(keysym, down)`; `setClipboard(text)`;
  `requestResize(width, height)`; `disconnect()`.
- **`connect.rs`** — TCP dial, RFB version handshake, security-type negotiation
  (None / VNC Authentication), DES challenge-response for password auth,
  `ServerInit` → emit `connected` with the server-negotiated size and desktop name.
- **`run_loop.rs`** — drive `vnc-rs`, translate framebuffer updates into
  `VncEvent.framebuffer` (dirty-rect, BGRA), surface cut-text/bell, map a clean
  server close to `disconnected` and protocol/decoder errors to `error`.

### App layer

- **`Host`** — add `HostProtocol.vnc`; `HostProtocol.defaultPort` returns 5900
  for VNC. Port auto-flips between protocol defaults only when still on another
  default (same rule already used for SSH↔RDP). `_save` preserves `protocol`.
  Password reuses the existing `pw_<hostId>` secure-storage path. No new Host
  fields required for the Linux-only cut.
- **`VncSession`** (`extends ChangeNotifier implements AppSession`) — mirrors
  `RdpSession`: holds `VncClient`, `Uint8List framebuffer` (reallocated to the
  server-negotiated size from `connected`; out-of-bounds patches dropped),
  `ui.Image? image` (latest-wins decode, old images disposed on replace/close),
  `VncSessionStatus`, `close()` bounding `disconnect()` with a timeout so tunnel
  teardown always runs, `markTunnelClosed()`.
- **`SessionProvider.connectVnc`** — mirrors `connectRdp`: lazy
  `VncClient.ensureInitialized` (failure → error tab), persists tab metadata via
  the shared `_persistTabMetadata`/`_applyTabMetadata`, writes connect/disconnect
  audit rows (`source: vnc`), watches status for drops, releases the bastion
  client when the last VNC tab of a host closes.
- **Loopback proxy** — generalize `RdpTunnelProxy` into a protocol-neutral
  one-shot loopback proxy (rename + shared usage) so both RDP and VNC tunnel
  SSH-forwarded dials through it. No new proxy implementation.
- **`VncWorkspace`** — mirrors `RdpWorkspace`: framebuffer paint, fullscreen
  (`isFullscreen` + `onFullscreenChanged`, owned by `MainScreen`), auto-hide
  hover pill, toolbar; force-exits fullscreen when the active tab changes or the
  session leaves `connected`.
- **`ProtocolBadge`** — generalize `RdpBadge` to render an RDP **or** VNC badge
  on dashboard cards, list rows, and the panel header.
- **`HostDetailPanel`** — extend the protocol `SegmentedButton` to SSH / RDP /
  VNC; VNC mode shows the SSH-tunnel dropdown and hides SSH-only and RDP-only
  (domain / RDP-security) sections.
- **Dashboard actions** — already protocol-aware for RDP; extend the same
  branches so SFTP/Test hide for VNC, CONNECT ALL counts VNC tabs, Duplicate
  keeps VNC fields, Copy URL uses `vnc://`.

### Input mapping

- Pointer: Flutter pointer events → RFB `PointerEvent` with an X11 button mask
  (left=1, middle=2, right=4, wheel up/down=8/16), coordinates in the
  server-negotiated framebuffer space.
- Keyboard: Flutter key events → RFB `KeyEvent` (X11 keysym + down/up). A
  `LogicalKeyboardKey` → keysym map covers printable keys, modifiers, and the
  common navigation/function keys.

## Milestones

Full parity is large, so it ships as five sub-projects. **Each milestone gets
its own spec → plan → implementation cycle** and its own PR. This document is
the umbrella architecture; Milestone 1 is detailed enough to plan now.

1. **VNC core crate** — `packages/yourssh_vnc` over `vnc-rs`: connect + RFB
   handshake + None/VNC-password auth + framebuffer-update loop + `VncEvent`
   bus + `native_loader` + `build.sh`/`build.ps1` + Rust unit tests + Dart FRB
   roundtrip test. No app wiring yet. **(Detailed below.)**
2. **End-to-end view-only** — `VncSession`, `SessionProvider.connectVnc`,
   `HostProtocol.vnc`, minimal `VncWorkspace` rendering the framebuffer.
3. **Input** — mouse + keyboard (keysym mapping).
4. **Parity** — clipboard, auto-resize, SSH tunnel (generalized loopback proxy),
   fullscreen, `ProtocolBadge`, `HostDetailPanel` VNC mode, dashboard actions.
5. **Tests/screenshots** — integration screenshots against a local VNC container
   (mirrors `rdp_screenshots_test`).

## Milestone 1 detail — VNC core crate

**Deliverables:**
- `packages/yourssh_vnc` crate building `libyourssh_vnc.{dylib,so,dll}` via
  `build.sh`/`build.ps1`, output copied into `assets/native/` (gitignored).
- `VncConfig`, `VncEvent`, `VncClient` FRB surface as above.
- `connect.rs`: RFB version handshake, security negotiation (None + VNC
  Authentication), DES challenge-response, `ServerInit` → `connected`.
- `run_loop.rs`: framebuffer-update → `VncEvent.framebuffer` (BGRA dirty rects),
  clean-close → `disconnected`, errors → `error`, auth failure → `authFailed`.
- `native_loader.dart` resolving the lib from the app bundle (release) or
  `assets/native/` (dev), matching the RDP loader.

**Tests:**
- Rust unit tests for the handshake/auth state machine and pixel-format/rect
  translation (no live server needed — feed canned byte streams).
- `test/frb_roundtrip_test.dart` exercising the generated bridge (config in,
  event enum out) like `yourssh_rdp/test/frb_roundtrip_test.dart`.

**Out of milestone 1:** any Flutter app wiring (`VncSession`, providers, UI).

## Backward compatibility

- Additive only. `HostProtocol` gains a `vnc` variant; existing SSH/RDP hosts are
  untouched. Sync payloads round-trip the new enum value (unknown-protocol hosts
  from older clients already tolerate the RDP precedent).
- Generalizing `RdpTunnelProxy` and `RdpBadge` is a rename/extract; RDP behavior
  is preserved (covered by existing RDP tests).
- The native lib is gitignored like the RDP one — `build.sh` must be run once
  after clone; CI builds it fresh.

## Risks / open questions

- **`vnc-rs` API surface** — confirm during M1 planning that it exposes
  incremental framebuffer requests, cut-text both directions, and
  `SetDesktopSize`. If a needed hook is missing, fall back to a **local fork**
  (the repo already forks `dartssh2`/`flutter_pty`/`xterm` via
  `dependency_overrides` — same pattern, Rust side).
- **Keysym coverage** — X11 keysym mapping is fiddly for non-US layouts; M3
  scopes a pragmatic map (printable + modifiers + nav/function) and iterates.
- **Decode throughput** — Tight/ZRLE decode is CPU-bound; keep latest-wins
  decode (no per-patch pileup) as RDP does.

## Files changed (Milestone 1)

- `packages/yourssh_vnc/**` (new package)
- `app/pubspec.yaml` — add the `yourssh_vnc` path dependency
- `.gitignore` — ignore `packages/yourssh_vnc/assets/native/` (mirror RDP)
