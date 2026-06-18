# VNC Milestone 4 (Parity) + Milestone 5 (Screenshots) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring VNC to feature parity with RDP — clipboard (both directions), SSH-tunnel connections, fullscreen, a protocol badge, the host-panel SSH-tunnel dropdown, dashboard polish — and add a manual screenshots integration test.

**Architecture:** Mirror RDP one-to-one. Generalize the protocol-neutral `RdpTunnelProxy` into a shared `LoopbackTunnelProxy` used by both protocols; add a clipboard command path (Dart → FFI → `vnc.input(X11Event::CopyText)`) and surface server cut-text to the system clipboard; mirror RDP's fullscreen (owned by `MainScreen`), generalize `RdpBadge` → `ProtocolBadge`, and extend the host panel + dashboard for VNC.

**Tech Stack:** Flutter (Dart), `package:yourssh_vnc` (flutter_rust_bridge v2), `vnc-rs` 0.5.3, `windowManager`, `dart:ui`.

## Global Constraints

- `flutter_rust_bridge` pinned `=2.12.0` (codegen + runtime). Install codegen if missing: `cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked`.
- Never add "Generated with Claude", co-author trailers, or any AI-tool mention anywhere (commits, code, docs).
- Work directly on `develop` (user-authorized). Commit per task.
- After any in-session `build.sh` on macOS, rewrite the dylib to a fresh inode or `dlopen`/`flutter test` dies with exit 137 — see Task 3 Step 5.
- Built native libs under `packages/yourssh_vnc/assets/native/` are gitignored — never `git add` them.
- VNC has **no TLS/cert layer** — no TOFU, no cert pinning anywhere.
- Resize is **receive-only**: the server drives size via `VncEvent.resize` (already handled in `VncSession._applyDesktopSize`); this plan does NOT add client-initiated `SetDesktopSize`. Task 8 fixes the painter so a server resize renders correctly.

---

## Task 1: Generalize `RdpTunnelProxy` → `LoopbackTunnelProxy`

**Files:**
- Rename: `app/lib/services/rdp_tunnel_proxy.dart` → `app/lib/services/loopback_tunnel_proxy.dart`
- Modify: `app/lib/models/rdp_session.dart` (import + field type), `app/lib/providers/session_provider.dart` (import + usage)
- Rename test: `app/test/services/rdp_tunnel_proxy_test.dart` → `app/test/services/loopback_tunnel_proxy_test.dart`

**Interfaces:**
- Produces: `class LoopbackTunnelProxy { LoopbackTunnelProxy({void Function()? onClosed}); Future<int> start(Future<TunnelEnd> Function() openTunnel); Future<void> stop(); }` and `class TunnelEnd { TunnelEnd({required Stream<List<int>> stream, required StreamSink<List<int>> sink, required void Function() close}); }`.

The proxy is byte-pure (no RDP specifics) — this is a pure rename. RDP behavior must be preserved (its test still passes).

- [ ] **Step 1: Rename the source file + class**

```bash
git mv app/lib/services/rdp_tunnel_proxy.dart app/lib/services/loopback_tunnel_proxy.dart
```
In `app/lib/services/loopback_tunnel_proxy.dart`, rename the class `RdpTunnelProxy` → `LoopbackTunnelProxy` (constructor name too). Update the class doc comment from "for SSH-tunneled RDP connections" to "for SSH-tunneled RDP/VNC connections". Leave `TunnelEnd` unchanged.

- [ ] **Step 2: Rename the test file + update references**

```bash
git mv app/test/services/rdp_tunnel_proxy_test.dart app/test/services/loopback_tunnel_proxy_test.dart
```
In `loopback_tunnel_proxy_test.dart`: change the import to `package:yourssh/services/loopback_tunnel_proxy.dart` and replace every `RdpTunnelProxy(` with `LoopbackTunnelProxy(` (4 sites).

- [ ] **Step 3: Update `rdp_session.dart`**

Change the import from `import '../services/rdp_tunnel_proxy.dart';` to `import '../services/loopback_tunnel_proxy.dart';` and the field type `final RdpTunnelProxy? tunnelProxy;` → `final LoopbackTunnelProxy? tunnelProxy;`.

- [ ] **Step 4: Update `session_provider.dart`**

Change the import to `import '../services/loopback_tunnel_proxy.dart';`. In `connectRdp`, change the proxy type and instantiation: `LoopbackTunnelProxy? proxy;` and `proxy = LoopbackTunnelProxy(onClosed: () => session?.markTunnelClosed());`.

- [ ] **Step 5: Verify rename is complete + tests pass**

Run: `cd app && grep -rn "RdpTunnelProxy" lib test` → expect **no matches**.
Run: `cd app && flutter test test/services/loopback_tunnel_proxy_test.dart` → PASS.
Run: `cd app && flutter analyze lib/services/loopback_tunnel_proxy.dart lib/models/rdp_session.dart lib/providers/session_provider.dart` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A app/lib/services app/test/services app/lib/models/rdp_session.dart app/lib/providers/session_provider.dart
git commit -m "refactor(vnc): rename RdpTunnelProxy to protocol-neutral LoopbackTunnelProxy"
```

---

## Task 2: VNC SSH-tunnel connection path

**Files:**
- Modify: `app/lib/models/vnc_session.dart` (tunnel field, markTunnelClosed, close, disconnect message)
- Modify: `app/lib/providers/session_provider.dart` (`connectVnc` tunnel block)
- Test: `app/test/models/vnc_session_test.dart` (add a markTunnelClosed case)

**Interfaces:**
- Consumes: `LoopbackTunnelProxy` (Task 1); `SshService.openTunnelSocket(String jumpHostId, String targetHost, int targetPort, String forHostId) -> Future<SSHSocket>`.
- Produces: `VncSession({required Host host, required VncClient client, LoopbackTunnelProxy? tunnelProxy})`; `VncSession.markTunnelClosed()`.

- [ ] **Step 1: Write the failing test**

Add to `app/test/models/vnc_session_test.dart` (it already imports the needed symbols):

```dart
  test('tunnel-closed marks the disconnect reason', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    s.markTunnelClosed();
    events.add(const frb.VncEvent.disconnected(reason: 'connection closed'));
    await Future<void>.delayed(Duration.zero);
    expect(s.lastMessage, 'SSH tunnel closed');
    await events.close();
  });
```

- [ ] **Step 2: Run to confirm FAIL**

Run: `cd app && flutter test test/models/vnc_session_test.dart`
Expected: FAIL — `markTunnelClosed` not defined.

- [ ] **Step 3: Add the tunnel plumbing to `VncSession`**

In `app/lib/models/vnc_session.dart`:

Add the import:
```dart
import '../services/loopback_tunnel_proxy.dart';
```

Change the constructor + fields:
```dart
  VncSession({required this.host, required this.client, this.tunnelProxy});

  final Host host;
  final VncClient client;

  /// Non-null when this session runs through an SSH tunnel; owned by the
  /// session and stopped on [close].
  final LoopbackTunnelProxy? tunnelProxy;
  bool _tunnelClosed = false;
```

Add the method (next to other methods):
```dart
  /// Called by the tunnel proxy when the SSH side collapsed, so the
  /// disconnect message names the real cause.
  void markTunnelClosed() => _tunnelClosed = true;
```

In `_onEvent`, change the Disconnected/Error arms to prefer the tunnel reason:
```dart
      case frb.VncEvent_Disconnected(:final reason):
        status = VncSessionStatus.disconnected;
        lastMessage = _tunnelClosed ? 'SSH tunnel closed' : reason;
      case frb.VncEvent_Error(:final message):
        status = VncSessionStatus.error;
        lastMessage = _tunnelClosed ? 'SSH tunnel closed' : message;
```

In `close()`, stop the proxy in the `finally` (after `client.dispose()`):
```dart
    } finally {
      client.dispose();
      await tunnelProxy?.stop();
      image?.dispose();
      image = null;
    }
```

- [ ] **Step 4: Add the tunnel block to `connectVnc`**

In `app/lib/providers/session_provider.dart`, in `connectVnc`, replace the direct config build with a tunnel-aware one. Change the start of `connectVnc` from:
```dart
  Future<VncSession?> connectVnc(Host host) async {
    final password = await _ssh.loadPassword(host.id) ?? '';

    String? setupError;
    try {
      await VncClient.ensureInitialized();
    } catch (e) {
      setupError = '$e';
    }

    final config = VncConfig(
      targetHost: host.host,
      targetPort: host.port,
      username: host.username,
      password: password,
    );
    final client = VncClient(config);
    final session = VncSession(host: host, client: client);
```
to:
```dart
  Future<VncSession?> connectVnc(Host host) async {
    final password = await _ssh.loadPassword(host.id) ?? '';

    var targetHost = host.host;
    var targetPort = host.port;
    LoopbackTunnelProxy? proxy;
    VncSession? session;
    String? setupError;

    try {
      await VncClient.ensureInitialized();
      if (host.jumpHostId != null) {
        proxy = LoopbackTunnelProxy(onClosed: () => session?.markTunnelClosed());
        final port = await proxy.start(() async {
          final sshSocket = await _ssh.openTunnelSocket(
              host.jumpHostId!, host.host, host.port, host.id);
          return TunnelEnd(
              stream: sshSocket.stream,
              sink: sshSocket.sink,
              close: sshSocket.destroy);
        });
        targetHost = '127.0.0.1';
        targetPort = port;
      }
    } catch (e) {
      setupError = '$e';
    }

    final config = VncConfig(
      targetHost: targetHost,
      targetPort: targetPort,
      username: host.username,
      password: password,
    );
    final client = VncClient(config);
    session = VncSession(host: host, client: client, tunnelProxy: proxy);
```
(The rest of `connectVnc` — `_applyTabMetadata`, attach/connect, `_watchVncStatus`, add to `_sessions`, etc. — is unchanged. Note `session` is now declared as `VncSession?` above and assigned here; the later `session.xxx` calls still work since it's non-null from this point. If the analyzer complains about nullable access after assignment, change them to `session!` or keep a local `final s = session;` — match whatever connectRdp does.)

Confirm the import `import '../services/loopback_tunnel_proxy.dart';` is present (added in Task 1).

- [ ] **Step 5: Run tests + analyze**

Run: `cd app && flutter test test/models/vnc_session_test.dart` → PASS.
Run: `cd app && flutter analyze lib/models/vnc_session.dart lib/providers/session_provider.dart` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/models/vnc_session.dart app/lib/providers/session_provider.dart app/test/models/vnc_session_test.dart
git commit -m "feat(vnc): SSH-tunnel connections via shared loopback proxy"
```

---

## Task 3: Rust clipboard-send command + FFI + regenerate

**Files:**
- Modify: `packages/yourssh_vnc/rust/src/session.rs`, `rust/src/run_loop.rs`, `rust/src/api.rs`
- Regenerate: `packages/yourssh_vnc/lib/src/generated/**`, `rust/src/frb_generated.rs`
- Rebuild: the native dylib (gitignored)

**Interfaces:**
- Produces: generated `vncSendClipboardText({required int sessionId, required String text})`.

- [ ] **Step 1: Add the command variant**

In `packages/yourssh_vnc/rust/src/session.rs`, add to `SessionCmd`:
```rust
    /// Send local clipboard text to the server (RFB ClientCutText).
    ClipboardText(String),
```
(Place it before `Disconnect`.)

- [ ] **Step 2: Add a failing test for the mapping**

In `packages/yourssh_vnc/rust/src/run_loop.rs`, add to the `#[cfg(test)] mod tests` block:
```rust
    #[test]
    fn input_event_maps_clipboard() {
        match input_event(&SessionCmd::ClipboardText("hi".into())) {
            Some(vnc::X11Event::CopyText(t)) => assert_eq!(t, "hi"),
            other => panic!("expected CopyText, got {other:?}"),
        }
    }
```

- [ ] **Step 3: Run to confirm FAIL**

Run: `cargo test --manifest-path packages/yourssh_vnc/rust/Cargo.toml input_event_maps_clipboard`
Expected: FAIL — the `ClipboardText` arm doesn't exist (non-exhaustive match or wrong result).

- [ ] **Step 4: Handle ClipboardText in `input_event`**

In `packages/yourssh_vnc/rust/src/run_loop.rs`, `input_event` currently matches `*cmd` (Copy). A `String` can't be moved out of a `&`, so switch to matching by reference. Replace the whole `input_event` fn with:
```rust
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
```
(The run-loop `Some(input)` arm already routes through `input_event`, so clipboard now flows to `vnc.input(X11Event::CopyText)` automatically. No change to the select! arm.)

- [ ] **Step 5: Add the FFI fn**

In `packages/yourssh_vnc/rust/src/api.rs`, after `vnc_send_key`, add:
```rust
pub fn vnc_send_clipboard_text(session_id: u32, text: String) {
    registry::send(session_id, SessionCmd::ClipboardText(text));
}
```

- [ ] **Step 6: Build + regenerate + rebuild dylib**

```bash
cargo test --manifest-path packages/yourssh_vnc/rust/Cargo.toml   # input_event tests pass
cd packages/yourssh_vnc && flutter_rust_bridge_codegen generate
grep -n "vncSendClipboardText" packages/yourssh_vnc/lib/src/generated/api.dart   # present
bash packages/yourssh_vnc/build.sh
```
Then macOS provenance rewrite (skip on Linux):
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

- [ ] **Step 7: Verify the bridge loads**

Run: `cd packages/yourssh_vnc && flutter test` → PASS (roundtrip; re-run the rewrite if exit 137).

- [ ] **Step 8: Commit (Rust + generated Dart + generated Rust glue; NOT the dylib)**

```bash
git add packages/yourssh_vnc/rust/src/session.rs packages/yourssh_vnc/rust/src/run_loop.rs packages/yourssh_vnc/rust/src/api.rs packages/yourssh_vnc/rust/src/frb_generated.rs packages/yourssh_vnc/lib/src/generated
git status --porcelain packages/yourssh_vnc/assets   # must be empty
git commit -m "feat(vnc): clipboard-send command + FFI + regenerated bindings"
```
(Note: `rust/src/frb_generated.rs` IS regenerated by codegen and MUST be committed — the M3 omission lesson.)

---

## Task 4: Dart clipboard — both directions

**Files:**
- Modify: `packages/yourssh_vnc/lib/src/vnc_client.dart` (`sendClipboardText`)
- Modify: `app/lib/models/vnc_session.dart` (`onRemoteClipboardText` + event wiring)
- Modify: `app/lib/providers/session_provider.dart` (`connectVnc` wires the callback)
- Modify: `app/lib/widgets/vnc_workspace.dart` (focus-gain push + toolbar button)
- Test: `packages/yourssh_vnc/test/vnc_client_input_test.dart`, `app/test/models/vnc_session_test.dart`

**Interfaces:**
- Consumes: generated `vncSendClipboardText` (Task 3).
- Produces: `VncClient.sendClipboardText(String)`; `VncSession.onRemoteClipboardText` (`void Function(String)?`).

- [ ] **Step 1: Failing tests**

In `packages/yourssh_vnc/test/vnc_client_input_test.dart`, add:
```dart
  test('sendClipboardText is a no-op before connect', () {
    expect(() => client().sendClipboardText('x'), returnsNormally);
  });
```
In `app/test/models/vnc_session_test.dart`, add:
```dart
  test('server cut-text invokes the clipboard callback (no repaint)', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    String? got;
    s.onRemoteClipboardText = (t) => got = t;
    s.attach(events.stream);
    events.add(const frb.VncEvent.clipboardText(text: 'hello'));
    await Future<void>.delayed(Duration.zero);
    expect(got, 'hello');
    await events.close();
  });
```

- [ ] **Step 2: Run to confirm FAIL**

Run: `cd packages/yourssh_vnc && flutter test test/vnc_client_input_test.dart` and `cd app && flutter test test/models/vnc_session_test.dart`
Expected: FAIL (`sendClipboardText`/`onRemoteClipboardText` undefined).

- [ ] **Step 3: `VncClient.sendClipboardText`**

In `packages/yourssh_vnc/lib/src/vnc_client.dart`, add next to `sendKey`:
```dart
  /// Send local clipboard text to the remote. No-op until started.
  void sendClipboardText(String text) {
    final id = _sessionId;
    if (id == null) return;
    vncSendClipboardText(sessionId: id, text: text);
  }
```

- [ ] **Step 4: `VncSession.onRemoteClipboardText` + wire the event**

In `app/lib/models/vnc_session.dart`, add a field (near `image`):
```dart
  void Function(String text)? onRemoteClipboardText;
```
Change the `_onEvent` ClipboardText arm from the M2 ignore:
```dart
      case frb.VncEvent_ClipboardText():
        return; // clipboard handling is a later milestone; ignore for now
```
to:
```dart
      case frb.VncEvent_ClipboardText(:final text):
        onRemoteClipboardText?.call(text);
        return; // no repaint needed
```

- [ ] **Step 5: Wire the callback in `connectVnc`**

In `app/lib/providers/session_provider.dart` `connectVnc`, after the `session = VncSession(...)` line, add:
```dart
    session.onRemoteClipboardText =
        (t) => Clipboard.setData(ClipboardData(text: t));
```
(Confirm `import 'package:flutter/services.dart';` is present in session_provider.dart — connectRdp uses `Clipboard`. If absent, add it.)

- [ ] **Step 6: Workspace — push local clipboard on focus + toolbar button**

In `app/lib/widgets/vnc_workspace.dart`:

Add a State field:
```dart
  String? _lastPushedClipboard;
```
Add `onFocusChange` to the `Focus` in the connected branch (alongside `autofocus`/`onKeyEvent`):
```dart
            onFocusChange: (gained) async {
              if (!gained) return;
              // Push local clipboard to the remote on focus gain, deduped so
              // alt-tabbing doesn't re-send identical content.
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              final text = data?.text;
              if (text != null &&
                  text.isNotEmpty &&
                  text != _lastPushedClipboard) {
                _lastPushedClipboard = text;
                session.client.sendClipboardText(text);
              }
            },
```
Add a "push clipboard" button to `_Toolbar` (before the Disconnect button):
```dart
        IconButton(
          tooltip: 'Push clipboard to remote',
          icon: const Icon(Icons.content_paste_go, size: 16),
          onPressed: () => _pushClipboard(session),
        ),
```
And add the helper as a top-level function (near `_vncButtonMask`):
```dart
Future<void> _pushClipboard(VncSession session) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  if (data?.text != null) {
    session.client.sendClipboardText(data!.text!);
  }
}
```
(`Clipboard`/`ClipboardData` come from `package:flutter/services.dart`, already imported in vnc_workspace.dart.)

- [ ] **Step 7: Run tests + analyze**

Run: `cd packages/yourssh_vnc && flutter test test/vnc_client_input_test.dart` → PASS.
Run: `cd app && flutter test test/models/vnc_session_test.dart` → PASS.
Run: `cd app && flutter analyze lib/models/vnc_session.dart lib/widgets/vnc_workspace.dart lib/providers/session_provider.dart` → clean.

- [ ] **Step 8: Commit**

```bash
git add packages/yourssh_vnc/lib/src/vnc_client.dart packages/yourssh_vnc/test/vnc_client_input_test.dart app/lib/models/vnc_session.dart app/lib/providers/session_provider.dart app/lib/widgets/vnc_workspace.dart app/test/models/vnc_session_test.dart
git commit -m "feat(vnc): clipboard both directions (server cut-text + focus/button push)"
```

---

## Task 5: `ProtocolBadge` (generalize `RdpBadge`)

**Files:**
- Create: `app/lib/widgets/protocol_badge.dart`
- Delete: `app/lib/widgets/rdp_badge.dart`
- Modify: `app/lib/widgets/hosts_dashboard.dart` (2 sites), `app/lib/widgets/host_detail_panel.dart` (1 site)
- Test: `app/test/widgets/protocol_badge_test.dart`

**Interfaces:**
- Produces: `class ProtocolBadge extends StatelessWidget { const ProtocolBadge(this.protocol, {super.key}); final HostProtocol protocol; }` — renders "RDP" (blue) or "VNC" (a distinct accent); renders nothing for `ssh`.

- [ ] **Step 1: Failing test**

Create `app/test/widgets/protocol_badge_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/widgets/protocol_badge.dart';

void main() {
  testWidgets('renders RDP / VNC labels, nothing for SSH', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ProtocolBadge(HostProtocol.rdp),
          ProtocolBadge(HostProtocol.vnc),
          ProtocolBadge(HostProtocol.ssh),
        ]),
      ),
    ));
    expect(find.text('RDP'), findsOneWidget);
    expect(find.text('VNC'), findsOneWidget);
    expect(find.text('SSH'), findsNothing);
  });
}
```

- [ ] **Step 2: Run to confirm FAIL**

Run: `cd app && flutter test test/widgets/protocol_badge_test.dart` → FAIL (file missing).

- [ ] **Step 3: Create `ProtocolBadge`, delete `RdpBadge`**

Create `app/lib/widgets/protocol_badge.dart`:
```dart
import 'package:flutter/material.dart';

import '../models/host.dart';
import '../theme/app_theme.dart';

/// Small pill marking a remote-desktop host's protocol (RDP / VNC). One widget
/// shared by the dashboard cards, list rows, and the host detail header so a
/// restyle can't leave the call sites visually diverged. SSH renders nothing.
class ProtocolBadge extends StatelessWidget {
  const ProtocolBadge(this.protocol, {super.key});

  final HostProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (protocol) {
      HostProtocol.rdp => ('RDP', AppColors.blue),
      HostProtocol.vnc => ('VNC', AppColors.green),
      HostProtocol.ssh => ('', AppColors.blue),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
```
(Confirm `AppColors.green` exists in `app/lib/theme/app_theme.dart`; if not, use another defined accent — read the file and pick one that exists. Do NOT invent a color.)

Then delete the old badge:
```bash
git rm app/lib/widgets/rdp_badge.dart
```

- [ ] **Step 4: Update the 3 call sites**

In `app/lib/widgets/hosts_dashboard.dart`, replace both:
```dart
                  if (widget.host.protocol == HostProtocol.rdp) ...[
                    const SizedBox(width: 6),
                    const RdpBadge(),
                  ],
```
with:
```dart
                  if (widget.host.protocol != HostProtocol.ssh) ...[
                    const SizedBox(width: 6),
                    ProtocolBadge(widget.host.protocol),
                  ],
```
and change the import `import 'rdp_badge.dart';` → `import 'protocol_badge.dart';`.

In `app/lib/widgets/host_detail_panel.dart`, replace:
```dart
                if (_isRdp) ...[
                  const SizedBox(width: 8),
                  const RdpBadge(),
                ],
```
with:
```dart
                if (_isGraphical) ...[
                  const SizedBox(width: 8),
                  ProtocolBadge(_protocol),
                ],
```
and change the import `import 'rdp_badge.dart';` → `import 'protocol_badge.dart';`. (`_isGraphical` exists from M2; `_protocol` is the panel's current protocol.)

- [ ] **Step 5: Verify + analyze**

Run: `cd app && grep -rn "RdpBadge\|rdp_badge" lib test` → no matches.
Run: `cd app && flutter test test/widgets/protocol_badge_test.dart` → PASS.
Run: `cd app && flutter analyze lib/widgets/protocol_badge.dart lib/widgets/hosts_dashboard.dart lib/widgets/host_detail_panel.dart` → clean.

- [ ] **Step 6: Commit**

```bash
git add -A app/lib/widgets app/test/widgets/protocol_badge_test.dart
git commit -m "feat(vnc): generalize RdpBadge into ProtocolBadge (RDP + VNC)"
```

---

## Task 6: VNC fullscreen

**Files:**
- Modify: `app/lib/widgets/vnc_workspace.dart` (fullscreen props, pill, toolbar button)
- Modify: `app/lib/screens/main_screen.dart` (`_vncFullscreen`, `_setVncFullscreen`, force-exit, construct with props)
- Test: `app/test/widgets/vnc_workspace_test.dart` (fullscreen toggle case)

**Interfaces:**
- Produces: `VncWorkspace({required VncSession session, VoidCallback? onReconnect, bool isFullscreen, ValueChanged<bool>? onFullscreenChanged})`.

- [ ] **Step 1: Failing test**

Add to `app/test/widgets/vnc_workspace_test.dart`:
```dart
  testWidgets('fullscreen button fires onFullscreenChanged when connected',
      (tester) async {
    final events = StreamController<frb.VncEvent>();
    final session = VncSession(host: _host(), client: _client());
    session.attach(events.stream);
    var fs = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VncWorkspace(
          session: session, onFullscreenChanged: (v) => fs = v),
      ),
    ));
    events.add(const frb.VncEvent.connected(width: 800, height: 600));
    await tester.pump();
    await tester.tap(find.byTooltip('Fullscreen'));
    await tester.pump();
    expect(fs, isTrue);
    await events.close();
  });
```
(This test file needs `_host()`/`_client()` helpers + the frb import — copy them from `vnc_workspace_input_test.dart` if the file lacks them.)

- [ ] **Step 2: Run to confirm FAIL**

Run: `cd app && flutter test test/widgets/vnc_workspace_test.dart` → FAIL (no fullscreen param / no Fullscreen button).

- [ ] **Step 3: Add fullscreen to `VncWorkspace`**

In `app/lib/widgets/vnc_workspace.dart`:

Add imports:
```dart
import 'dart:async';
```
Extend the widget:
```dart
  const VncWorkspace({
    super.key,
    required this.session,
    this.onReconnect,
    this.isFullscreen = false,
    this.onFullscreenChanged,
  });

  final VncSession session;
  final VoidCallback? onReconnect;
  final bool isFullscreen;
  final ValueChanged<bool>? onFullscreenChanged;
```
Add hover-pill state + helpers to `_VncWorkspaceState`:
```dart
  bool _hoverBarVisible = false;
  Timer? _hoverBarTimer;

  void _flashHoverBar() {
    setState(() => _hoverBarVisible = true);
    _hoverBarTimer?.cancel();
    _hoverBarTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _hoverBarVisible = false);
    });
  }

  void _showHoverBar() {
    _hoverBarTimer?.cancel();
    if (!_hoverBarVisible) setState(() => _hoverBarVisible = true);
  }

  void _hideHoverBarSoon() {
    _hoverBarTimer?.cancel();
    _hoverBarTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _hoverBarVisible = false);
    });
  }
```
In `initState`, flash on entry:
```dart
    if (widget.isFullscreen) _flashHoverBar();
```
In `didUpdateWidget`, re-flash on entering fullscreen, and request windowed when the session leaves connected:
```dart
    if (widget.isFullscreen && !old.isFullscreen) _flashHoverBar();
    if (widget.isFullscreen && session.status != VncSessionStatus.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFullscreenChanged?.call(false);
      });
    }
```
In `dispose`, cancel the timer (before `_focusNode.dispose()`):
```dart
    _hoverBarTimer?.cancel();
```
Change `build` to branch on fullscreen:
```dart
  @override
  Widget build(BuildContext context) {
    if (widget.isFullscreen) {
      return Stack(children: [
        Positioned.fill(child: _buildBody()),
        Positioned(
          top: 0, left: 0, right: 0, height: 8,
          child: MouseRegion(
            opaque: false,
            onEnter: (_) => _showHoverBar(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: 8, left: 0, right: 0,
          child: Center(
            child: AnimatedOpacity(
              opacity: _hoverBarVisible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: IgnorePointer(
                ignoring: !_hoverBarVisible,
                child: MouseRegion(
                  onEnter: (_) => _showHoverBar(),
                  onExit: (_) => _hideHoverBarSoon(),
                  child: _ExitFullscreenPill(
                    onExit: () => widget.onFullscreenChanged?.call(false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    }
    return Column(children: [
      _Toolbar(
        session: session,
        onEnterFullscreen: widget.onFullscreenChanged == null
            ? null
            : () => widget.onFullscreenChanged!.call(true),
      ),
      Expanded(child: _buildBody()),
    ]);
  }
```
Update `_Toolbar` to take + show the fullscreen button:
```dart
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.session, this.onEnterFullscreen});
  final VncSession session;
  final VoidCallback? onEnterFullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      color: AppColors.card,
      child: Row(children: [
        const SizedBox(width: 8),
        Text(session.tabLabel, style: Theme.of(context).textTheme.labelMedium),
        const Spacer(),
        IconButton(
          tooltip: 'Push clipboard to remote',
          icon: const Icon(Icons.content_paste_go, size: 16),
          onPressed: () => _pushClipboard(session),
        ),
        if (onEnterFullscreen != null)
          IconButton(
            tooltip: 'Fullscreen',
            icon: const Icon(Icons.fullscreen, size: 16),
            onPressed: session.status == VncSessionStatus.connected
                ? onEnterFullscreen
                : null,
          ),
        IconButton(
          tooltip: 'Disconnect',
          icon: const Icon(Icons.power_settings_new, size: 16),
          onPressed: () => session.client.disconnect(),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }
}
```
Add the pill widget at the bottom of the file:
```dart
class _ExitFullscreenPill extends StatelessWidget {
  const _ExitFullscreenPill({required this.onExit});
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onExit,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.fullscreen_exit, size: 16),
            SizedBox(width: 6),
            Text('Exit fullscreen'),
          ]),
        ),
      ),
    );
  }
}
```
(The Task 4 clipboard button is included above; if Task 4 already added it, keep one copy.)

- [ ] **Step 4: Wire fullscreen in `MainScreen`**

In `app/lib/screens/main_screen.dart`:

Add the field next to `_rdpFullscreen`:
```dart
  bool _vncFullscreen = false;
```
Add the setter next to `_setRdpFullscreen`:
```dart
  Future<void> _setVncFullscreen(bool on) async {
    if (_vncFullscreen == on || !mounted) return;
    setState(() => _vncFullscreen = on);
    try {
      await windowManager.setFullScreen(on);
    } catch (_) {
      // Window manager unavailable (tests/headless) — chrome state applied.
    }
  }
```
In `build()`, next to the `rdpFullscreenActive` block, add the VNC equivalent (force-exit + chrome-collapsed return):
```dart
    final vncFullscreenActive =
        _vncFullscreen && _viewingTerminal && activeSession is VncSession;
    if (_vncFullscreen && !vncFullscreenActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_setVncFullscreen(false));
      });
    }
    if (vncFullscreenActive) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: _buildForeground(activeSession),
      );
    }
```
Update the `VncWorkspace` construction in `_buildForeground`:
```dart
    if (_viewingTerminal && active is VncSession) {
      return VncWorkspace(
        session: active,
        onReconnect: () => _retryVnc(active),
        isFullscreen: _vncFullscreen,
        onFullscreenChanged: (on) => unawaited(_setVncFullscreen(on)),
      );
    }
```

- [ ] **Step 5: Run tests + analyze**

Run: `cd app && flutter test test/widgets/vnc_workspace_test.dart test/widgets/vnc_workspace_input_test.dart` → PASS.
Run: `cd app && flutter analyze lib/widgets/vnc_workspace.dart lib/screens/main_screen.dart` → clean.

- [ ] **Step 6: Commit**

```bash
git add app/lib/widgets/vnc_workspace.dart app/lib/screens/main_screen.dart app/test/widgets/vnc_workspace_test.dart
git commit -m "feat(vnc): fullscreen with auto-hide exit pill (mirrors RDP)"
```

---

## Task 7: Host panel — SSH-tunnel dropdown for VNC

**Files:**
- Modify: `app/lib/widgets/host_detail_panel.dart`
- Test: `app/test/widgets/host_detail_panel_vnc_test.dart`

The SSH-TUNNEL `Builder` block currently lives INSIDE the `if (_isRdp) ...[` block (with RDP SECURITY). Extract it so it renders for any graphical protocol, while RDP SECURITY + domain stay RDP-only.

- [ ] **Step 1: Add a failing assertion**

In `app/test/widgets/host_detail_panel_vnc_test.dart`, in the existing "VNC mode hides SSH-only and RDP-only sections" test, add (after seeding a second SSH host so the tunnel dropdown renders — the dropdown hides when there are no SSH hosts):
```dart
  testWidgets('VNC mode shows the SSH TUNNEL dropdown', (tester) async {
    final bastion = Host(
        id: 'b1', label: 'bastion', host: '10.0.0.1', port: 22, username: 'u');
    await pumpPanel(tester, existing: vncHost(), allHosts: [bastion]);
    expect(find.text('SSH TUNNEL'), findsOneWidget);
  });
```
(Update `pumpPanel` to accept `allHosts` and seed them into the `HostProvider` — mirror `host_detail_panel_rdp_test.dart`'s `pumpPanel(allHosts:)`. If the existing `pumpPanel` lacks the param, add it.)

- [ ] **Step 2: Run to confirm FAIL**

Run: `cd app && flutter test test/widgets/host_detail_panel_vnc_test.dart` → FAIL (`SSH TUNNEL` not shown for VNC).

- [ ] **Step 3: Extract the SSH-TUNNEL block**

In `app/lib/widgets/host_detail_panel.dart`, the `if (_isRdp) ...[` block contains RDP SECURITY then the SSH-TUNNEL `Builder`. Move the SSH-TUNNEL `Builder(...)` OUT of that `if (_isRdp)` block into its own gate immediately after it:
```dart
                  ],  // end of the RDP-SECURITY (still _isRdp) block — keep RDP SECURITY + domain here

                  // SSH tunnel applies to any graphical protocol (RDP + VNC).
                  if (_isGraphical)
                    Builder(builder: (context) {
                      final sshHosts = context
                          .watch<HostProvider>()
                          .allHosts
                          .where((h) =>
                              h.protocol == HostProtocol.ssh &&
                              h.id != widget.existing?.id)
                          .toList();
                      if (sshHosts.isEmpty) return const SizedBox.shrink();
                      final current = _jumpHostIds.firstOrNull;
                      final valid =
                          sshHosts.any((h) => h.id == current) ? current : null;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _sectionLabel('SSH TUNNEL'),
                          const SizedBox(height: 6),
                          _Card(children: [
                            _DropdownRow(
                              icon: Icons.alt_route,
                              child: DropdownButton<String?>(
                                value: valid,
                                isExpanded: true,
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 13),
                                dropdownColor: AppColors.card,
                                underline: const SizedBox(),
                                items: [
                                  const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Direct connection')),
                                  for (final h in sshHosts)
                                    DropdownMenuItem<String?>(
                                        value: h.id,
                                        child: Text(
                                            'via ${h.label.isEmpty ? h.host : h.label}')),
                                ],
                                onChanged: (v) => setState(() =>
                                    _jumpHostIds = v == null ? [] : [v]),
                              ),
                            ),
                          ]),
                        ],
                      );
                    }),
```
Concretely: remove the SSH-TUNNEL `Builder` (and its leading content) from inside the `if (_isRdp) ...[ ]` list literal, close that list after RDP SECURITY, and re-add the `Builder` under the new `if (_isGraphical)`. The RDP SECURITY section and the domain field (Task references / M2) remain gated on `_isRdp`.

- [ ] **Step 4: Run tests + analyze**

Run: `cd app && flutter test test/widgets/host_detail_panel_vnc_test.dart test/widgets/host_detail_panel_rdp_test.dart` → both PASS (RDP still shows SSH TUNNEL; VNC now shows it; RDP SECURITY still RDP-only).
Run: `cd app && flutter analyze lib/widgets/host_detail_panel.dart` → clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/host_detail_panel.dart app/test/widgets/host_detail_panel_vnc_test.dart
git commit -m "feat(vnc): SSH-tunnel dropdown in the host panel for VNC hosts"
```

---

## Task 8: Dashboard cosmetics + painter resize fix

**Files:**
- Modify: `app/lib/widgets/hosts_dashboard.dart` (Copy-URL scheme/label, bulk-skip message)
- Modify: `app/lib/widgets/vnc_workspace.dart` (`_FramePainter` self-fits to image dims)
- Test: `app/test/widgets/vnc_workspace_test.dart` (no new test required for the painter; covered by existing render); add a dashboard copy-url assertion only if a dashboard test already exists — otherwise rely on analyze.

- [ ] **Step 1: Copy-URL scheme + label for VNC**

In `app/lib/widgets/hosts_dashboard.dart`, change `_copyHostUrl`:
```dart
    final scheme = widget.host.protocol == HostProtocol.rdp ? 'rdp' : 'ssh';
```
to:
```dart
    final scheme = switch (widget.host.protocol) {
      HostProtocol.rdp => 'rdp',
      HostProtocol.vnc => 'vnc',
      HostProtocol.ssh => 'ssh',
    };
```
And the menu label:
```dart
    _menuItem('copy_url', Icons.link_outlined, isSsh ? 'Copy SSH URL' : 'Copy RDP URL', () => _copyHostUrl(context)),
```
to:
```dart
    _menuItem('copy_url', Icons.link_outlined,
        'Copy ${widget.host.protocol.name.toUpperCase()} URL',
        () => _copyHostUrl(context)),
```

- [ ] **Step 2: Bulk-skip message wording**

In `_selectedSshHosts`, change:
```dart
      content: Text('$skipped RDP host(s) skipped — $action is SSH-only'),
```
to:
```dart
      content: Text('$skipped non-SSH host(s) skipped — $action is SSH-only'),
```

- [ ] **Step 3: Painter self-fits to image dimensions**

In `app/lib/widgets/vnc_workspace.dart`, make `_FramePainter` compute its own letterbox from the image's own dimensions (so a server resize renders the still-old-size frame correctly until the next decode, instead of stretching it to the new session-derived scale). Replace `_FramePainter` with:
```dart
class _FramePainter extends CustomPainter {
  /// `repaint: session` redraws on every decoded frame without rebuilding the
  /// surrounding widget tree (the workspace only rebuilds on status changes).
  _FramePainter(this.session) : super(repaint: session);

  final VncSession session;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? img = session.image;
    if (img == null) return;
    // Fit by the IMAGE's own dimensions, not the session-negotiated size, so a
    // server resize doesn't stretch the still-old frame for a few ms.
    final s = math.min(size.width / img.width, size.height / img.height);
    final dw = img.width * s, dh = img.height * s;
    final ox = (size.width - dw) / 2, oy = (size.height - dh) / 2;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(ox, oy, dw, dh),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => !identical(old.session, session);
}
```
And update the construction in the connected branch (drop the offX/offY/scale args, which were only for the painter — the LayoutBuilder still computes them for the INPUT coordinate transform):
```dart
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _FramePainter(session),
                  ),
                  if (session.image == null)
                    const Center(
                        child: Text('Waiting for first frame…',
                            style: TextStyle(color: AppColors.textSecondary))),
                ],
              ),
```
(Keep the `offX`/`offY`/`scale` locals and the `toFb`/`sendPointer` closures in the LayoutBuilder — input coordinates must still use the session-negotiated size.)

- [ ] **Step 4: Run tests + analyze**

Run: `cd app && flutter test test/widgets/vnc_workspace_test.dart test/widgets/vnc_workspace_input_test.dart` → PASS.
Run: `cd app && flutter analyze lib/widgets/hosts_dashboard.dart lib/widgets/vnc_workspace.dart` → clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/hosts_dashboard.dart app/lib/widgets/vnc_workspace.dart
git commit -m "feat(vnc): vnc:// copy-url, non-SSH bulk-skip wording, resize-correct painter"
```

---

## Task 9 (M5): VNC screenshots integration test

**Files:**
- Create: `app/integration_test/vnc_screenshots_test.dart`
- Modify: `CLAUDE.md` (document the run command + prereqs)

This is a manual-run test (lives under `integration_test/`, which the default `flutter test` skips; needs a live VNC container). Mirror `app/integration_test/rdp_screenshots_test.dart` exactly, swapping the RDP specifics.

- [ ] **Step 1: Create the test**

Create `app/integration_test/vnc_screenshots_test.dart` mirroring `rdp_screenshots_test.dart` with these substitutions (copy that file's `_snap`, `_waitFor`, backup/restore scaffolding verbatim, and adapt):
- Header prereqs:
```dart
// Screenshot capture for the in-app VNC client (incl. fullscreen).
//
// Drives the REAL app against a local x11vnc container and saves PNGs into
// <repo>/screenshots/. Frames are captured from the render tree, so no macOS
// Screen-Recording permission is needed.
//
// Prereqs (a password-auth VNC server on :5900):
//   docker run -d --name yourssh-vnc-demo -p 5900:5900 \
//     -e VNC_PASSWORD=demo12345 consol/ubuntu-xfce-vnc:latest
//   (or any x11vnc/TigerVNC server with password "demo12345" on 5900)
//
// Run:
//   cd app && flutter test integration_test/vnc_screenshots_test.dart -d macos
```
- `const _demoHostId = 'screenshot-vnc-demo';`
- Seed host:
```dart
final demoHost = Host(
  id: _demoHostId,
  label: 'Demo VNC',
  host: '127.0.0.1',
  port: 5900,
  username: '',
  authType: AuthType.password,
  protocol: HostProtocol.vnc,
);
```
- `await storage.savePassword(_demoHostId, 'demo12345');`
- NO TOFU dialog — after the double-tap to connect, go straight to waiting for connected (there is no "Trust … certificate?" dialog for VNC). Session access:
```dart
VncSession vnc() => sessions.sessions.whereType<VncSession>().first;
await _waitFor(tester,
    () => sessions.sessions.whereType<VncSession>().isNotEmpty &&
        vnc().status == VncSessionStatus.connected,
    what: 'VNC connected');
await _waitFor(tester, () => vnc().image != null, what: 'first VNC frame');
```
- Screenshot names: `01-dashboard-vnc-badge`, `02-host-editor-vnc-form`, `03-vnc-workspace-connected`, `04-fullscreen-with-pill`, `05-fullscreen-hover-reveal`, `06-back-to-windowed`.
- Fullscreen steps: tap `find.byTooltip('Fullscreen')`, snap; hover the top edge / wait for the pill, snap; tap the exit pill (`find.text('Exit fullscreen')`), snap.
- Imports: add `package:yourssh/models/vnc_session.dart`; keep the rest from the RDP test (app.main(), SessionProvider, StorageService, Host, etc.).

Use the exact `_outDir` constant from the RDP test (`<repo>/screenshots`).

- [ ] **Step 2: Analyze the test compiles**

Run: `cd app && flutter analyze integration_test/vnc_screenshots_test.dart`
Expected: `No issues found!` (it compiles even without a running container; it only fails at run time without one).

- [ ] **Step 3: Document the command in CLAUDE.md**

In `CLAUDE.md`, under the native-library / screenshots section (near the existing `rdp_screenshots_test.dart` line), add:
```
# VNC feature screenshots (needs a local x11vnc/TigerVNC container on :5900 with
# password demo12345 — see the test header). Manual run, not CI.
cd app && flutter test integration_test/vnc_screenshots_test.dart -d macos
```

- [ ] **Step 4: Commit**

```bash
git add app/integration_test/vnc_screenshots_test.dart CLAUDE.md
git commit -m "test(vnc): manual screenshots integration test + docs"
```

---

## Final verification

- [ ] `cd app && flutter analyze` → no new issues (pre-existing untracked probe-file lints may remain).
- [ ] `cd app && flutter test` → all pass.
- [ ] `cd packages/yourssh_vnc && flutter test` and `cargo test --manifest-path packages/yourssh_vnc/rust/Cargo.toml` → pass.

---

## Self-Review

**1. Spec coverage** (umbrella M4 "Parity" + M5 "Tests/screenshots"):
- Clipboard both directions → Tasks 3 (send command) + 4 (server cut-text → system clipboard, focus/button push). ✓
- Auto-resize → receive-only (already in `_applyDesktopSize`) + painter resize-correctness (Task 8). Client-initiated SetDesktopSize explicitly out of scope (documented). ✓
- SSH tunnel via generalized loopback proxy → Tasks 1 (rename) + 2 (connectVnc tunnel). ✓
- Fullscreen → Task 6. ✓
- ProtocolBadge → Task 5. ✓
- HostDetailPanel VNC mode (SSH-tunnel dropdown) → Task 7. ✓
- Dashboard actions (vnc:// copy URL, bulk-skip wording; Duplicate already copies protocol) → Task 8. ✓
- Screenshots → Task 9 (M5). ✓

**2. Placeholder scan:** every step has complete code/commands; no TBD/"handle errors"/"similar to". The two spots that say "confirm X exists / mirror the RDP test's helper" (AppColors.green, pumpPanel allHosts param, the RDP screenshots scaffolding) name the exact file to copy from — acceptable since the source is concrete and in-repo.

**3. Type consistency:** `LoopbackTunnelProxy`/`TunnelEnd` (Task 1) used identically in Tasks 2. `SessionCmd::ClipboardText(String)` → `input_event` CopyText (Task 3) → `vnc_send_clipboard_text` → generated `vncSendClipboardText(sessionId,text)` → `VncClient.sendClipboardText(String)` (Task 4) → workspace/connectVnc. `VncSession({host, client, tunnelProxy})` + `markTunnelClosed()` + `onRemoteClipboardText` consistent across Tasks 2/4. `ProtocolBadge(HostProtocol)` (Task 5) used in dashboard + panel. `VncWorkspace({session, onReconnect, isFullscreen, onFullscreenChanged})` (Task 6) matches the MainScreen call site and the fullscreen test. `_FramePainter(session)` single-arg (Task 8) — its only construction site is updated in the same task.
