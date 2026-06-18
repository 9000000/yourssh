# VNC Core Crate (Milestone 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `packages/yourssh_vnc` — a Rust VNC (RFB) client wrapping the `vnc-rs` crate behind flutter_rust_bridge v2, exposing a `StreamSink<VncEvent>` of connect/framebuffer/disconnect events — with no Flutter app wiring yet.

**Architecture:** Mirror `packages/yourssh_rdp` one-to-one. A tokio run loop drives `vnc-rs`'s `recv_event()` and translates each event into a `VncEvent` pushed to Dart over a `StreamSink`. Pixel data arrives as self-contained RGBA patches (`RawImage(Rect, data)`); the Dart side (Milestone 2) assembles the framebuffer. The native lib is built via `build.sh` and gitignored, resolved at runtime by `NativeLoader`.

**Tech Stack:** Rust (`vnc-rs` 0.5.3, tokio, flutter_rust_bridge v2), Dart/Flutter.

**Reference reading for the executor (do before Task 2):**
- The template being mirrored: `packages/yourssh_rdp/rust/src/{api,session,connect,run_loop}.rs`, `packages/yourssh_rdp/build.sh`, `packages/yourssh_rdp/lib/src/{native_loader,rdp_client}.dart`, `packages/yourssh_rdp/test/frb_roundtrip_test.dart`, `packages/yourssh_rdp/flutter_rust_bridge.yaml`. This plan is structurally identical with RDP→VNC substitutions.
- `vnc-rs` docs: https://docs.rs/vnc-rs/latest/vnc/ — crate name is `vnc-rs`, **library name is `vnc`** (all paths are `vnc::...`). The `example/src/main.rs` in https://github.com/HsuJv/vnc-rs is the canonical connect + event-loop snippet.
- **Known FRB limitation (drives the design):** a function taking a `StreamSink<T>` parameter is generated as a Dart function returning `Stream<T>`; **its Rust return value is discarded** (FRB issue #2233). The session id therefore travels as the first stream event (`VncEvent::Started`), never as a return value — identical to RDP.

**Milestone-1 scope decisions (deliberate, documented — not silent caps):**
- Encodings negotiated: **Zrle + Raw only.** Both surface as `VncEvent::RawImage` (self-contained RGBA patch), so M1 needs no Rust-side framebuffer, no CopyRect blit, and no Tight/JPEG decode. CopyRect + Tight/JPEG (which require a Rust framebuffer and a JPEG decoder) are a later milestone.
- Client-initiated resize (`SetDesktopSize`/`ExtendedDesktopSize`) is **not in `vnc-rs`** — deferred to the parity milestone (needs a local fork). M1 only *receives* server-driven size via `VncEvent::SetResolution`.
- Input (mouse/keyboard) and clipboard-send are **not** in M1 (Milestones 3/4). M1 emits inbound clipboard (`Text`) and the bell, and implements only `Disconnect` as an inbound command.

---

## Phase 0 — Package scaffolding

### Task 1: Scaffold `packages/yourssh_vnc`

**Files:**
- Create: `packages/yourssh_vnc/pubspec.yaml`
- Create: `packages/yourssh_vnc/lib/yourssh_vnc.dart`
- Create: `packages/yourssh_vnc/lib/src/.gitkeep`
- Create: `packages/yourssh_vnc/flutter_rust_bridge.yaml`
- Create: `packages/yourssh_vnc/rust/Cargo.toml`
- Create: `packages/yourssh_vnc/rust/src/lib.rs`
- Modify: `app/pubspec.yaml`
- Modify: `.gitignore`

- [ ] **Step 1: Create the Dart package skeleton**

`packages/yourssh_vnc/pubspec.yaml`:

```yaml
name: yourssh_vnc
description: In-app VNC (RFB) client for yourssh (vnc-rs via flutter_rust_bridge).
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.12.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_rust_bridge: ^2.12.0
  ffi: ^2.1.3
  freezed_annotation: ^2.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  freezed: ^2.0.0
  build_runner: ^2.0.0
```

`packages/yourssh_vnc/lib/yourssh_vnc.dart`:

```dart
library yourssh_vnc;

export 'src/vnc_client.dart';
```

Create an empty `packages/yourssh_vnc/lib/src/.gitkeep` (the `generated/` and `vnc_client.dart` land in later tasks).

- [ ] **Step 2: Create the FRB codegen config**

`packages/yourssh_vnc/flutter_rust_bridge.yaml`:

```yaml
rust_input: crate::api
rust_root: rust
dart_output: lib/src/generated
```

- [ ] **Step 3: Create the Rust crate manifest**

`packages/yourssh_vnc/rust/Cargo.toml`:

```toml
[package]
name = "yourssh_vnc"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "staticlib"]

[profile.release]
strip = true
lto = "thin"
codegen-units = 1

[dependencies]
flutter_rust_bridge = "=2.12.0"
vnc-rs = "0.5.3"
tokio = { version = "1", features = ["rt-multi-thread", "net", "sync", "macros", "time"] }
anyhow = "1"
futures = "0.3"

[dev-dependencies]
tokio = { version = "1", features = ["test-util"] }
```

- [ ] **Step 4: Create the Rust lib module list**

`packages/yourssh_vnc/rust/src/lib.rs`:

```rust
pub mod api;
pub mod connect;
pub mod run_loop;
pub mod session;
mod frb_generated;
```

(`frb_generated` does not exist yet — `cargo` will not compile until Task 6 runs codegen. That is expected; the next tasks create the modules it lists.)

- [ ] **Step 5: Wire the app dependency**

In `app/pubspec.yaml`, directly below the existing `yourssh_rdp` path dependency (around line 79-80), add:

```yaml
  yourssh_vnc:
    path: ../packages/yourssh_vnc
```

- [ ] **Step 6: Gitignore the built native libs**

In `.gitignore`, below the existing `yourssh_rdp` entries (around line 3-7), add:

```gitignore
/packages/yourssh_vnc/rust/target/

# Built native VNC libraries — rebuilt locally via packages/yourssh_vnc/build.sh
/packages/yourssh_vnc/assets/native/
```

- [ ] **Step 7: Commit**

```bash
git add packages/yourssh_vnc/pubspec.yaml packages/yourssh_vnc/lib packages/yourssh_vnc/flutter_rust_bridge.yaml packages/yourssh_vnc/rust/Cargo.toml packages/yourssh_vnc/rust/src/lib.rs app/pubspec.yaml .gitignore
git commit -m "feat(vnc): scaffold yourssh_vnc package"
```

---

## Phase 1 — Rust crate

### Task 2: Session registry

**Files:**
- Create: `packages/yourssh_vnc/rust/src/session.rs`

- [ ] **Step 1: Write the session module with the registry test**

`packages/yourssh_vnc/rust/src/session.rs`:

```rust
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Mutex;

use tokio::sync::mpsc::UnboundedSender;

/// Commands Dart can push into a running session loop. Milestone 1 only needs
/// Disconnect; input/clipboard-send commands are added in later milestones.
pub enum SessionCmd {
    Disconnect,
}

static NEXT_ID: AtomicU32 = AtomicU32::new(1);
static SESSIONS: Mutex<Option<HashMap<u32, UnboundedSender<SessionCmd>>>> = Mutex::new(None);

pub mod registry {
    use super::*;

    pub fn insert(tx: UnboundedSender<SessionCmd>) -> u32 {
        let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        SESSIONS.lock().unwrap().get_or_insert_with(HashMap::new).insert(id, tx);
        id
    }

    pub fn send(id: u32, cmd: SessionCmd) -> bool {
        let guard = SESSIONS.lock().unwrap();
        match guard.as_ref().and_then(|m| m.get(&id)) {
            Some(tx) => tx.send(cmd).is_ok(),
            None => false,
        }
    }

    pub fn remove(id: u32) {
        if let Some(m) = SESSIONS.lock().unwrap().as_mut() {
            m.remove(&id);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn registry_insert_send_remove() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let id = registry::insert(tx);
        assert!(registry::send(id, SessionCmd::Disconnect));
        assert!(matches!(rx.try_recv().unwrap(), SessionCmd::Disconnect));
        registry::remove(id);
        assert!(!registry::send(id, SessionCmd::Disconnect));
    }
}
```

- [ ] **Step 2: Verify the module compiles in isolation**

The crate cannot build fully until codegen (Task 6), so check just this module's syntax with the standalone test in Task 3's run after `frb_generated` exists. For now, confirm there are no obvious errors by reading the file. (No command yet — `cargo` needs `frb_generated`.)

- [ ] **Step 3: Commit**

```bash
git add packages/yourssh_vnc/rust/src/session.rs
git commit -m "feat(vnc): session command registry"
```

### Task 3: Run-loop pure helpers (TDD)

**Files:**
- Create: `packages/yourssh_vnc/rust/src/run_loop.rs` (helpers + tests only in this task; the async loop is added in Task 5)

- [ ] **Step 1: Write the failing tests for the two pure helpers**

`packages/yourssh_vnc/rust/src/run_loop.rs`:

```rust
use std::time::Duration;

use tokio::sync::mpsc::UnboundedReceiver;
use vnc::{PixelFormat, VncEncoding, VncError, VncEvent, X11Event};

use crate::api::{VncConfig, VncEvent as ApiEvent};
use crate::connect::vnc_connect_stage;
use crate::session::SessionCmd;

/// How often the loop pumps an incremental framebuffer-update request.
/// vnc-rs sends the initial full request itself; everything after that is
/// driven by us (the crate has no auto-continuous refresh).
const REFRESH_INTERVAL_MS: u64 = 16;

/// Forces every pixel's alpha byte to 0xFF. VNC servers typically send 32bpp
/// pixels with the padding (alpha) byte zeroed; rendered as RGBA8888 that is
/// fully transparent, so the patch must be made opaque before it reaches Dart.
pub fn set_opaque(rgba: &mut [u8]) {
    for i in (3..rgba.len()).step_by(4) {
        rgba[i] = 0xFF;
    }
}

/// Maps a `vnc-rs` error to a graceful disconnect reason, or `None` if it is a
/// real error that should surface as `VncEvent::Error`. A closed event channel
/// (`ClientNotRunning`) is the normal end-of-session signal.
pub fn disconnect_reason(e: &VncError) -> Option<String> {
    match e {
        VncError::ClientNotRunning => Some("connection closed".to_string()),
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
```

(The `use` lines reference `api`, `connect`, and the async loop added in Tasks 4-5. They will not compile until those exist; the tests are run together after Task 6.)

- [ ] **Step 2: Commit**

```bash
git add packages/yourssh_vnc/rust/src/run_loop.rs
git commit -m "test(vnc): run-loop pure helpers (opaque alpha, disconnect classify)"
```

### Task 4: API surface — config, events, entrypoints

**Files:**
- Create: `packages/yourssh_vnc/rust/src/api.rs`

- [ ] **Step 1: Write the API module**

`packages/yourssh_vnc/rust/src/api.rs`:

```rust
use futures::FutureExt;
use tokio::sync::mpsc;

use crate::frb_generated::StreamSink;
use crate::session::{registry, SessionCmd};

#[derive(Clone)]
pub struct VncConfig {
    pub target_host: String,
    pub target_port: u16,
    /// Unused by classic VNC auth (password-only) but carried for parity with
    /// the app's Host model and future auth schemes.
    pub username: String,
    pub password: String,
}

#[derive(Clone)]
pub enum VncEvent {
    /// Always the first event. Carries the session id (FRB discards the Rust
    /// return value of StreamSink-taking functions — issue #2233).
    Started { session_id: u32 },
    /// Connection established. Carries the server's initial framebuffer size;
    /// the Dart framebuffer must be sized from these values.
    Connected { width: u16, height: u16 },
    /// Server-driven desktop-size change after connect (e.g. a resized X session).
    Resize { width: u16, height: u16 },
    /// A self-contained RGBA patch at (x, y) of the given size. `rgba` length is
    /// width * height * 4, alpha forced opaque.
    FrameUpdate { x: u16, y: u16, width: u16, height: u16, rgba: Vec<u8> },
    /// Server clipboard (cut-text). Latin-1 from the server.
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

/// Removes the registry entry even if the spawned future is dropped before
/// completing (runtime shutdown, cancellation).
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
```

- [ ] **Step 2: Commit**

```bash
git add packages/yourssh_vnc/rust/src/api.rs
git commit -m "feat(vnc): FRB api surface (VncConfig, VncEvent, connect/disconnect)"
```

### Task 5: Connect stage + run loop

**Files:**
- Create: `packages/yourssh_vnc/rust/src/connect.rs`
- Modify: `packages/yourssh_vnc/rust/src/run_loop.rs` (append the async loop below the helpers)

- [ ] **Step 1: Write the connect stage**

`packages/yourssh_vnc/rust/src/connect.rs`:

```rust
use anyhow::Context;
use tokio::net::TcpStream;
use vnc::{PixelFormat, VncClient, VncConnector, VncEncoding};

use crate::api::VncConfig;

/// Dials the server, performs the RFB handshake + auth, and negotiates the
/// Milestone-1 encoding set (Zrle + Raw — both surface as self-contained RGBA
/// patches). Returns a connected `VncClient`.
pub async fn vnc_connect_stage(cfg: &VncConfig) -> anyhow::Result<VncClient> {
    let addr = format!("{}:{}", cfg.target_host, cfg.target_port);
    let tcp = TcpStream::connect(&addr).await.context("TCP connect")?;

    // The password future is only polled if the server requires VNC auth; for
    // a "None"-auth server vnc-rs never calls it.
    let password = cfg.password.clone();
    let client = VncConnector::new(tcp)
        .set_auth_method(async move { Ok::<_, vnc::VncError>(password) })
        .add_encoding(VncEncoding::Zrle)
        .add_encoding(VncEncoding::Raw)
        .allow_shared(true)
        .set_pixel_format(PixelFormat::rgba())
        .build()
        .context("build VNC connector")?
        .try_start()
        .await
        .context("VNC handshake/auth")?
        .finish()
        .context("finish VNC connect")?;

    Ok(client)
}
```

- [ ] **Step 2: Append the async run loop to `run_loop.rs`**

Add below the existing helpers in `packages/yourssh_vnc/rust/src/run_loop.rs` (after the `disconnect_reason` fn, before `#[cfg(test)]`):

```rust
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
                    Ok(VncEvent::SetResolution(screen)) => {
                        if !connected {
                            connected = true;
                            sink(ApiEvent::Connected { width: screen.width, height: screen.height });
                        } else {
                            sink(ApiEvent::Resize { width: screen.width, height: screen.height });
                        }
                    }
                    Ok(VncEvent::RawImage(rect, mut data)) => {
                        set_opaque(&mut data);
                        sink(ApiEvent::FrameUpdate {
                            x: rect.x, y: rect.y, width: rect.width, height: rect.height, rgba: data,
                        });
                    }
                    Ok(VncEvent::Text(text)) => sink(ApiEvent::ClipboardText { text }),
                    Ok(VncEvent::Bell) => sink(ApiEvent::Bell),
                    // Not negotiated / not handled in Milestone 1:
                    // Copy (CopyRect), JpegImage (Tight), SetCursor, SetPixelFormat.
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
                // Request the next incremental update. Ignore send errors — a
                // dead client surfaces on the next recv_event().
                let _ = vnc.input(X11Event::Refresh).await;
            }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add packages/yourssh_vnc/rust/src/connect.rs packages/yourssh_vnc/rust/src/run_loop.rs
git commit -m "feat(vnc): connect stage + event run loop"
```

### Task 6: Generate FRB bindings and verify the crate builds + tests

**Files:**
- Create (generated): `packages/yourssh_vnc/lib/src/generated/**`, `packages/yourssh_vnc/rust/src/frb_generated.rs`

- [ ] **Step 1: Run flutter_rust_bridge codegen**

Run: `cd packages/yourssh_vnc && flutter_rust_bridge_codegen generate`
(The user's shell aliases this as `n generate` — either works. Install if missing: `cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked`.)
Expected: creates `lib/src/generated/{api.dart,frb_generated.dart,frb_generated.io.dart,api.freezed.dart}` and `rust/src/frb_generated.rs`, with no errors.

- [ ] **Step 2: Type-check the Rust crate**

Run: `cd packages/yourssh_vnc/rust && cargo check`
Expected: compiles clean (warnings about the unused `username` field are acceptable). If `VncEncoding`/`VncEvent`/`X11Event`/`PixelFormat`/`Screen`/`Rect` paths differ from those used here, fix the imports against `vnc-rs` 0.5.3's actual exports (they are re-exported at the `vnc::` root).

- [ ] **Step 3: Run the Rust unit tests**

Run: `cd packages/yourssh_vnc/rust && cargo test`
Expected: PASS — `registry_insert_send_remove`, `set_opaque_sets_every_fourth_byte`, `set_opaque_handles_empty`, `disconnect_reason_graceful_on_not_running`, `disconnect_reason_none_on_real_error`.

- [ ] **Step 4: Commit the generated bindings**

```bash
git add packages/yourssh_vnc/lib/src/generated packages/yourssh_vnc/rust/src/frb_generated.rs
git commit -m "feat(vnc): generate flutter_rust_bridge bindings"
```

---

## Phase 2 — Build script + Dart facade

### Task 7: Native build script

**Files:**
- Create: `packages/yourssh_vnc/build.sh`

- [ ] **Step 1: Write the build script (macOS universal + Linux)**

`packages/yourssh_vnc/build.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/rust"
case "$(uname -s)" in
  Darwin)
    # Universal dylib (Apple Silicon + Intel): build both targets and lipo
    # them together so the one shipped .app runs on either architecture.
    rustup target add aarch64-apple-darwin x86_64-apple-darwin
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    cd ..
    mkdir -p assets/native/macos
    lipo -create \
      rust/target/aarch64-apple-darwin/release/libyourssh_vnc.dylib \
      rust/target/x86_64-apple-darwin/release/libyourssh_vnc.dylib \
      -output assets/native/macos/libyourssh_vnc.dylib ;;
  Linux)
    cargo build --release
    cd ..
    mkdir -p assets/native/linux
    cp rust/target/release/libyourssh_vnc.so assets/native/linux/ ;;
esac
echo "yourssh_vnc native library built"
```

- [ ] **Step 2: Make it executable and commit**

```bash
chmod +x packages/yourssh_vnc/build.sh
git add packages/yourssh_vnc/build.sh
git commit -m "feat(vnc): native build script (macOS universal + Linux)"
```

(Windows `build.ps1` mirrors `packages/yourssh_rdp/build.ps1` and is added when Windows support is needed; M1's target dev platform is macOS.)

### Task 8: Dart native loader + client facade

**Files:**
- Create: `packages/yourssh_vnc/lib/src/native_loader.dart`
- Create: `packages/yourssh_vnc/lib/src/vnc_client.dart`

- [ ] **Step 1: Write the native loader**

`packages/yourssh_vnc/lib/src/native_loader.dart`:

```dart
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

/// Locates the yourssh_vnc dynamic library. Search order: bundled release
/// locations (relative to the running executable), plain name (rpath /
/// system lookup), then repo-relative dev paths.
ExternalLibrary loadYoursshVncLibrary() {
  Object? lastError;
  for (final path in _candidates()) {
    try {
      return ExternalLibrary.open(path);
    } catch (e) {
      lastError = e;
    }
  }
  throw StateError('yourssh_vnc native library not found: $lastError');
}

List<String> _candidates() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  if (Platform.isMacOS) {
    return [
      '${File(Platform.resolvedExecutable).parent.parent.path}/Frameworks/libyourssh_vnc.dylib',
      'libyourssh_vnc.dylib',
      '${Directory.current.path}/assets/native/macos/libyourssh_vnc.dylib',
      '${Directory.current.path}/packages/yourssh_vnc/assets/native/macos/libyourssh_vnc.dylib',
      '${Directory.current.path}/../packages/yourssh_vnc/assets/native/macos/libyourssh_vnc.dylib',
    ];
  }
  if (Platform.isLinux) {
    return [
      '$exeDir/lib/libyourssh_vnc.so',
      'libyourssh_vnc.so',
      '${Directory.current.path}/assets/native/linux/libyourssh_vnc.so',
      '${Directory.current.path}/packages/yourssh_vnc/assets/native/linux/libyourssh_vnc.so',
      '${Directory.current.path}/../packages/yourssh_vnc/assets/native/linux/libyourssh_vnc.so',
    ];
  }
  return [
    '$exeDir\\yourssh_vnc.dll',
    'yourssh_vnc.dll',
    '${Directory.current.path}\\assets\\native\\windows\\yourssh_vnc.dll',
    '${Directory.current.path}\\packages\\yourssh_vnc\\assets\\native\\windows\\yourssh_vnc.dll',
    '${Directory.current.path}\\..\\packages\\yourssh_vnc\\assets\\native\\windows\\yourssh_vnc.dll',
  ];
}
```

- [ ] **Step 2: Write the client facade**

`packages/yourssh_vnc/lib/src/vnc_client.dart`:

```dart
import 'dart:async';

import 'generated/api.dart';
import 'generated/frb_generated.dart';
import 'native_loader.dart';

export 'generated/api.dart' show VncConfig, VncEvent;

/// Lightweight typed facade over the generated FRB bindings.
///
/// Usage:
/// ```dart
/// await VncClient.ensureInitialized();
/// final client = VncClient(VncConfig(...));
/// client.events.listen((event) { ... });
/// await client.connect();
/// await client.disconnect();
/// await client.done;
/// ```
class VncClient {
  final VncConfig config;

  int? _sessionId;
  bool _disconnectRequested = false;
  StreamSubscription<VncEvent>? _sub;
  final _eventCtrl = StreamController<VncEvent>.broadcast();
  final _done = Completer<void>();

  VncClient(this.config);

  static Future<void>? _initFuture;

  /// Initializes the Rust bridge exactly once (loads the native library on
  /// first use). Safe to call repeatedly; a failed attempt resets so the next
  /// call retries.
  static Future<void> ensureInitialized() {
    return _initFuture ??=
        RustLib.init(externalLibrary: loadYoursshVncLibrary()).catchError((Object e) {
      _initFuture = null;
      throw e;
    });
  }

  Stream<VncEvent> get events => _eventCtrl.stream;

  /// Completes when the session is fully torn down (after Disconnected or Error).
  Future<void> get done => _done.future;

  bool get isConnected => _sessionId != null;

  /// Start the VNC session. The returned future completes once the first
  /// [VncEvent.connected] arrives, or throws if the connection fails first.
  Future<void> connect() async {
    if (_sessionId != null) throw StateError('Already connected');
    await ensureInitialized();

    final connectedCompleter = Completer<void>();

    _sub = vncConnect(config: config).listen(
      (event) {
        switch (event) {
          case VncEvent_Started(:final sessionId):
            _sessionId = sessionId;
            if (_disconnectRequested) {
              unawaited(vncDisconnect(sessionId: sessionId));
            }
          case VncEvent_Connected():
            if (!connectedCompleter.isCompleted) connectedCompleter.complete();
          case VncEvent_Disconnected(:final reason):
            _finish(event, connectedCompleter, reason);
            return;
          case VncEvent_Error(:final message):
            _finish(event, connectedCompleter, message);
            return;
          default:
            break;
        }
        _eventCtrl.add(event);
      },
      onError: (Object err) {
        _sessionId = null;
        if (!_done.isCompleted) _done.completeError(err);
        if (!connectedCompleter.isCompleted) connectedCompleter.completeError(err);
      },
      cancelOnError: false,
    );

    return connectedCompleter.future;
  }

  void _finish(VncEvent event, Completer<void> connectedCompleter, String reason) {
    _sessionId = null;
    _eventCtrl.add(event);
    _sub?.cancel();
    _sub = null;
    if (!_done.isCompleted) _done.complete();
    if (!connectedCompleter.isCompleted) {
      connectedCompleter.completeError(
        Exception(reason.isEmpty ? 'connection failed' : reason),
      );
    }
  }

  Future<void> disconnect() async {
    final id = _sessionId;
    if (id == null) {
      _disconnectRequested = true;
      return;
    }
    await vncDisconnect(sessionId: id);
    await done;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _eventCtrl.close();
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add packages/yourssh_vnc/lib/src/native_loader.dart packages/yourssh_vnc/lib/src/vnc_client.dart
git commit -m "feat(vnc): Dart native loader + VncClient facade"
```

### Task 9: FRB roundtrip test + build the native lib + run it

**Files:**
- Create: `packages/yourssh_vnc/test/frb_roundtrip_test.dart`

- [ ] **Step 1: Write the roundtrip test**

`packages/yourssh_vnc/test/frb_roundtrip_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh_vnc/src/generated/frb_generated.dart';
import 'package:yourssh_vnc/src/generated/api.dart';
import 'package:yourssh_vnc/src/native_loader.dart';

void main() {
  setUpAll(() async {
    await RustLib.init(externalLibrary: loadYoursshVncLibrary());
  });

  test('vncLibVersion returns crate version', () async {
    expect(await vncLibVersion(), startsWith('yourssh_vnc 0.1.0'));
  });
}
```

- [ ] **Step 2: Build the native library**

Run: `bash packages/yourssh_vnc/build.sh`
Expected: prints `yourssh_vnc native library built`; produces `packages/yourssh_vnc/assets/native/macos/libyourssh_vnc.dylib` (or `linux/libyourssh_vnc.so`).

- [ ] **Step 3: macOS only — rewrite the dylib to a fresh inode**

On this Mac, a dylib produced by sandboxed Bash carries a `com.apple.provenance` record that makes macOS SIGKILL any process that `mmap()`s it (so `flutter test`'s `dlopen` dies with exit 137). Rewrite the bytes to a clean inode. Run (sandbox disabled):

```bash
python3 - <<'PY'
import os
p = "packages/yourssh_vnc/assets/native/macos/libyourssh_vnc.dylib"
data = open(p, "rb").read()
open(p + ".clean", "wb").write(data)
os.chmod(p + ".clean", 0o755)
os.replace(p + ".clean", p)
print("rewrote", p, len(data), "bytes")
PY
```

(Skip this step on Linux. See the `macos-provenance-mmap-kill` project memory.)

- [ ] **Step 4: Run the Dart roundtrip test**

Run: `cd packages/yourssh_vnc && flutter test`
Expected: PASS — `vncLibVersion returns crate version`. (If it dies with exit code 137, re-run Step 3 — the dlopen hit the provenance kill.)

- [ ] **Step 5: Commit**

```bash
git add packages/yourssh_vnc/test/frb_roundtrip_test.dart
git commit -m "test(vnc): FRB roundtrip (vncLibVersion over the native bridge)"
```

---

## Done criteria for Milestone 1

- `cd packages/yourssh_vnc/rust && cargo test` passes (registry + opaque + disconnect-classify).
- `cd packages/yourssh_vnc && flutter test` passes (FRB roundtrip dlopens the real lib).
- `packages/yourssh_vnc` exposes `VncClient` with `ensureInitialized()` / `connect()` / `events` / `disconnect()` / `done` and emits `VncEvent.{started,connected,resize,frameUpdate,clipboardText,bell,disconnected,error}`.
- No Flutter app wiring yet (that is Milestone 2: `VncSession`, `SessionProvider.connectVnc`, `HostProtocol.vnc`, `VncWorkspace`).

## Self-review notes (addressed)

- **Spec coverage:** M1 spec deliverables (crate over `vnc-rs`, connect + RFB handshake + None/VNC-password auth, framebuffer-update loop, `VncEvent` bus, `native_loader`, `build.sh`, Rust unit + Dart FRB roundtrip tests) each map to Tasks 2-9. ✓
- **Deferred-with-reason (not gaps):** CopyRect, Tight/JPEG, client-resize, and input/clipboard-send are explicitly scoped out of M1 above and assigned to later milestones in the design spec. ✓
- **Type consistency:** `VncConfig`/`VncEvent` field and variant names are identical across `api.rs`, `run_loop.rs` (`ApiEvent` alias), and `vnc_client.dart` (`VncEvent_Started`/`_Connected`/`_Disconnected`/`_Error`). `vnc_connect_stage` is defined in `connect.rs` and consumed in `run_loop.rs`. `set_opaque`/`disconnect_reason` defined and tested in Task 3, used in Task 5. ✓
- **`vnc-rs` API risk:** exact symbol paths (`vnc::VncConnector`, `vnc::VncEncoding`, `vnc::VncEvent`, `vnc::X11Event`, `vnc::PixelFormat`) are from the 0.5.3 source; Task 6 Step 2 calls out fixing any drift against the pinned crate before proceeding.
