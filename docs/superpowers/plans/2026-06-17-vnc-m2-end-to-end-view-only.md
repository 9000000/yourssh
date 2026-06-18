# VNC Milestone 2 — End-to-End View-Only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the M1 `yourssh_vnc` crate into the Flutter app so a user can create a VNC host, connect to it directly (no SSH tunnel yet), and watch the live remote framebuffer in a tab — view-only (no mouse/keyboard input).

**Architecture:** Mirror the existing RDP app integration one-to-one. Add `HostProtocol.vnc`; a `VncSession` (`ChangeNotifier implements AppSession`) that owns a `VncClient`, reallocates its framebuffer to the server-negotiated size, and decodes frames latest-wins into a `ui.Image`; a `SessionProvider.connectVnc` reached through the existing `connectAny` router; a minimal `VncWorkspace` that paints the image via a `CustomPainter`; and a `VncSession → VncWorkspace` branch in `MainScreen`. VNC has **no TLS/cert layer**, so all RDP cert-pinning wiring is deliberately omitted.

**Tech Stack:** Flutter (Dart), `provider`, `package:yourssh_vnc` (flutter_rust_bridge v2), `dart:ui` image decode.

**Scope boundary (do NOT build here — later milestones):** mouse/keyboard input (M3); clipboard, auto-resize UI, SSH tunnel via loopback proxy, fullscreen, generalized protocol badge, dashboard polish (M4); integration screenshots (M5). Direct (untunneled) connections only.

**Reference files (read for patterns, do not modify unless a task says so):**
- `app/lib/models/rdp_session.dart` — the model this mirrors
- `app/lib/providers/session_provider.dart` — `connectRdp` (lines 181–272), `_watchRdpStatus` (276–323), `connectAny` (176–179), `closeSession` RDP branch (504–530), `_metadataHostId` (611–615), `reconnectRdp` (325–330)
- `app/lib/widgets/rdp_workspace.dart` — render pipeline (`_FramePainter`, lines 410–438)
- `app/lib/widgets/host_detail_panel.dart` — protocol selector + `_isRdp` gating
- `packages/yourssh_vnc/rust/src/api.rs` — the exact `VncConfig`/`VncEvent` shapes

**`VncEvent` / `VncConfig` shapes (from `api.rs`, what the generated Dart exposes):**
- `VncConfig(targetHost: String, targetPort: int, username: String, password: String)` — **no width/height** (the server dictates framebuffer size).
- Sealed `VncEvent` factory constructors (for tests): `VncEvent.started(sessionId: int)`, `VncEvent.connected(width: int, height: int)`, `VncEvent.resize(width: int, height: int)`, `VncEvent.frameUpdate(x: int, y: int, width: int, height: int, rgba: Uint8List)`, `VncEvent.clipboardText(text: String)`, `VncEvent.bell()`, `VncEvent.disconnected(reason: String)`, `VncEvent.error(message: String)`.
- Pattern-match subclasses (for the model `switch`): `VncEvent_Started`, `VncEvent_Connected`, `VncEvent_Resize`, `VncEvent_FrameUpdate`, `VncEvent_ClipboardText`, `VncEvent_Bell`, `VncEvent_Disconnected`, `VncEvent_Error`. These live in `package:yourssh_vnc/src/generated/api.dart` (import with `// ignore: implementation_imports`, alias `frb`), exactly like `rdp_session.dart`.

---

## Task 1: Add `HostProtocol.vnc`

**Files:**
- Modify: `app/lib/models/host.dart:12-21` (the `HostProtocol` enum)
- Test: `app/test/models/host_vnc_test.dart` (create)

Serialization already works for any enum value: `toJson` writes `protocol.name`, and `fromJson`'s `parseProtocol()` uses `HostProtocol.values.asNameMap()[name] ?? HostProtocol.ssh`. Adding the variant is all that's needed — these tests lock that in.

- [ ] **Step 1: Write the failing test**

Create `app/test/models/host_vnc_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';

void main() {
  test('vnc default port is 5900', () {
    expect(HostProtocol.vnc.defaultPort, 5900);
  });

  test('vnc protocol round-trips through json', () {
    final h = Host(
      label: 'desktop',
      host: '10.0.0.5',
      port: 5900,
      username: 'u',
      protocol: HostProtocol.vnc,
    );
    final json = h.toJson();
    expect(json['protocol'], 'vnc');

    final back = Host.fromJson(json);
    expect(back.protocol, HostProtocol.vnc);
    expect(back.port, 5900);
  });

  test('unknown protocol still falls back to ssh', () {
    final back = Host.fromJson({
      'id': 'x',
      'label': 'l',
      'host': 'h',
      'port': 22,
      'username': 'u',
      'protocol': 'telnet',
    });
    expect(back.protocol, HostProtocol.ssh);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/models/host_vnc_test.dart`
Expected: FAIL — compile error, `vnc` is not a member of `HostProtocol`.

- [ ] **Step 3: Add the enum variant**

In `app/lib/models/host.dart`, change the enum (lines 12–21) from:

```dart
enum HostProtocol {
  ssh(defaultPort: 22),
  rdp(defaultPort: 3389);
```

to:

```dart
enum HostProtocol {
  ssh(defaultPort: 22),
  rdp(defaultPort: 3389),
  vnc(defaultPort: 5900);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app && flutter test test/models/host_vnc_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/models/host.dart app/test/models/host_vnc_test.dart
git commit -m "feat(vnc): add HostProtocol.vnc (default port 5900)"
```

---

## Task 2: `VncSession` model

**Files:**
- Create: `app/lib/models/vnc_session.dart`
- Test: `app/test/models/vnc_session_test.dart`

Mirrors `RdpSession` (`app/lib/models/rdp_session.dart`) minus everything cert/TLS and tunnel-related. The constructor takes **no** width/height — VNC starts at 0×0 and reallocates on the `Connected` event (and on `Resize`).

- [ ] **Step 1: Write the failing test**

Create `app/test/models/vnc_session_test.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/vnc_session.dart';
import 'package:yourssh_vnc/yourssh_vnc.dart' show VncClient, VncConfig;
// ignore: implementation_imports
import 'package:yourssh_vnc/src/generated/api.dart' as frb;

Host _host() => Host(
    id: 'v1',
    label: 'desktop',
    host: '10.0.0.5',
    port: 5900,
    username: 'u',
    protocol: HostProtocol.vnc);

// The VncClient constructor only stores config + creates controllers; it does
// NOT load the native library (that happens in ensureInitialized/connect),
// so it is safe to build in a unit test.
VncClient _client() => VncClient(VncConfig(
    targetHost: '10.0.0.5', targetPort: 5900, username: 'u', password: ''));

void main() {
  test('status transitions connecting -> connected -> disconnected', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    expect(s.status, VncSessionStatus.connecting);

    events.add(const frb.VncEvent.started(sessionId: 1));
    events.add(const frb.VncEvent.connected(width: 800, height: 600));
    await Future<void>.delayed(Duration.zero);
    expect(s.status, VncSessionStatus.connected);
    expect(s.width, 800);
    expect(s.height, 600);

    events.add(const frb.VncEvent.disconnected(reason: 'bye'));
    await Future<void>.delayed(Duration.zero);
    expect(s.status, VncSessionStatus.disconnected);
    expect(s.lastMessage, 'bye');
    await events.close();
  });

  test('error event sets error status and message', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.error(message: 'connection refused'));
    await Future<void>.delayed(Duration.zero);
    expect(s.status, VncSessionStatus.error);
    expect(s.lastMessage, 'connection refused');
    await events.close();
  });

  test('framebuffer reallocates to server size on connected', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.connected(width: 4, height: 2));
    await Future<void>.delayed(Duration.zero);
    expect(s.framebuffer.length, 4 * 2 * 4);
    await events.close();
  });

  test('resize reallocates the framebuffer', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.connected(width: 4, height: 2));
    await Future<void>.delayed(Duration.zero);
    events.add(const frb.VncEvent.resize(width: 8, height: 8));
    await Future<void>.delayed(Duration.zero);
    expect(s.width, 8);
    expect(s.height, 8);
    expect(s.framebuffer.length, 8 * 8 * 4);
    await events.close();
  });

  test('out-of-bounds frame update is dropped without crashing', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.connected(width: 4, height: 4));
    await Future<void>.delayed(Duration.zero);
    events.add(frb.VncEvent.frameUpdate(
        x: 3, y: 3, width: 4, height: 4, rgba: Uint8List(4 * 4 * 4)));
    await Future<void>.delayed(Duration.zero);
    expect(s.framebuffer.length, 4 * 4 * 4); // unchanged, no throw
    await events.close();
  });

  test('frame update patches the framebuffer row-by-row', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.connected(width: 2, height: 1));
    await Future<void>.delayed(Duration.zero);
    final px = Uint8List.fromList([10, 20, 30, 255, 40, 50, 60, 255]);
    events.add(
        frb.VncEvent.frameUpdate(x: 0, y: 0, width: 2, height: 1, rgba: px));
    await Future<void>.delayed(Duration.zero);
    expect(s.framebuffer.sublist(0, 8), [10, 20, 30, 255, 40, 50, 60, 255]);
    await events.close();
  });

  test('tab label falls back to host label, honours custom override', () {
    final s = VncSession(host: _host(), client: _client());
    expect(s.tabLabel, 'desktop');
    s.customLabel = 'My VM';
    expect(s.tabLabel, 'My VM');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/models/vnc_session_test.dart`
Expected: FAIL — `vnc_session.dart` does not exist (URI doesn't resolve).

- [ ] **Step 3: Create the model**

Create `app/lib/models/vnc_session.dart`:

```dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:yourssh_vnc/yourssh_vnc.dart';
// ignore: implementation_imports
import 'package:yourssh_vnc/src/generated/api.dart' as frb;

import 'app_session.dart';
import 'host.dart';

enum VncSessionStatus { connecting, connected, disconnected, error }

/// One VNC tab. Mirrors [RdpSession] but with no TLS/cert layer (plain VNC has
/// none — security is the SSH tunnel, added in a later milestone) and no
/// tunnel proxy yet (direct connections only in this milestone).
class VncSession extends ChangeNotifier implements AppSession {
  VncSession({required this.host, required this.client});

  final Host host;
  final VncClient client;

  /// Desktop size. Starts at 0×0; replaced by the server's framebuffer size
  /// from the Connected event and any later Resize (frame coordinates arrive
  /// in this space).
  int get width => _width;
  int get height => _height;
  int _width = 0;
  int _height = 0;

  Uint8List framebuffer = Uint8List(0);

  @override
  String get id => _id;
  final String _id = 'vnc_${DateTime.now().microsecondsSinceEpoch}';

  VncSessionStatus status = VncSessionStatus.connecting;
  String? lastMessage;
  bool _closed = false;

  /// Latest decoded frame for painting; rebuilt lazily after patches.
  ui.Image? image;
  bool _decodeInFlight = false;
  bool _dirtyAgain = false;
  StreamSubscription<frb.VncEvent>? _sub;

  @override
  String? customLabel;
  @override
  String? colorTag;
  @override
  bool isPinned = false;
  @override
  String get tabLabel => customLabel ?? host.label;

  void attach(Stream<frb.VncEvent> events) {
    _sub = events.listen(_onEvent, onError: (Object e) {
      status = VncSessionStatus.error;
      lastMessage = '$e';
      notifyListeners();
    });
  }

  void _onEvent(frb.VncEvent ev) {
    switch (ev) {
      case frb.VncEvent_Started():
        return; // id captured inside VncClient.connect
      case frb.VncEvent_Connected(:final width, :final height):
        _applyDesktopSize(width, height);
        status = VncSessionStatus.connected;
      case frb.VncEvent_Resize(:final width, :final height):
        _applyDesktopSize(width, height);
      case frb.VncEvent_FrameUpdate(
          :final x,
          :final y,
          :final width,
          :final height,
          :final rgba
        ):
        _patch(x, y, width, height, rgba);
      case frb.VncEvent_ClipboardText():
        return; // clipboard handling is a later milestone; ignore for now
      case frb.VncEvent_Bell():
        return; // no visual state change
      case frb.VncEvent_Disconnected(:final reason):
        status = VncSessionStatus.disconnected;
        lastMessage = reason;
      case frb.VncEvent_Error(:final message):
        status = VncSessionStatus.error;
        lastMessage = message;
    }
    notifyListeners();
  }

  void _applyDesktopSize(int w, int h) {
    if (w == _width && h == _height) return;
    _width = w;
    _height = h;
    framebuffer = Uint8List(w * h * 4);
  }

  void _patch(int x, int y, int w, int h, Uint8List rgba) {
    final fbStride = _width * 4;
    // Defense in depth: Rust clamps regions to the negotiated size, but a
    // malformed event must never crash the stream listener.
    if (x + w > _width || y + h > _height || rgba.length < w * h * 4) return;
    for (var row = 0; row < h; row++) {
      final dst = (y + row) * fbStride + x * 4;
      final src = row * w * 4;
      framebuffer.setRange(dst, dst + w * 4, rgba, src);
    }
    _scheduleDecode();
  }

  void _scheduleDecode() {
    // One decode at a time, latest-wins: patches landing while a decode is
    // running set a flag and a single follow-up decode picks them all up.
    if (_decodeInFlight) {
      _dirtyAgain = true;
      return;
    }
    _decodeInFlight = true;
    scheduleMicrotask(_decodeLoop);
  }

  Future<void> _decodeLoop() async {
    do {
      _dirtyAgain = false;
      // fromUint8List snapshots synchronously, so the decoded image is
      // internally consistent even if a patch lands during the await.
      final buf = await ui.ImmutableBuffer.fromUint8List(framebuffer);
      final desc = ui.ImageDescriptor.raw(buf,
          width: _width, height: _height, pixelFormat: ui.PixelFormat.rgba8888);
      final codec = await desc.instantiateCodec();
      final decoded = (await codec.getNextFrame()).image;
      if (_closed) {
        decoded.dispose();
        break;
      }
      image?.dispose();
      image = decoded;
      notifyListeners();
    } while (_dirtyAgain);
    _decodeInFlight = false;
  }

  Future<void> close() async {
    _closed = true;
    await _sub?.cancel();
    try {
      // A wedged transport can stall the graceful disconnect indefinitely.
      await client.disconnect().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // Rust side will die with the process; nothing more to do.
    } finally {
      client.dispose();
      image?.dispose();
      image = null;
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app && flutter test test/models/vnc_session_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/models/vnc_session.dart app/test/models/vnc_session_test.dart
git commit -m "feat(vnc): VncSession model (framebuffer realloc + latest-wins decode)"
```

---

## Task 3: `SessionProvider.connectVnc` + router + status watch + close + reconnect

**Files:**
- Modify: `app/lib/providers/session_provider.dart` (imports; `connectAny` 176–179; add `connectVnc` + `_watchVncStatus` + `reconnectVnc`; `closeSession` 504–530; `_metadataHostId` 611–615)
- Test: `app/test/providers/session_provider_app_session_test.dart` (extend)

**Testing note (read before writing tests):** `connectVnc` calls `VncClient.ensureInitialized()`, which `dlopen`s the native dylib — in `flutter test` that risks the macOS provenance SIGKILL and is exactly why the existing RDP provider tests never call `connectRdp`. So this task's tests cover only the native-safe surface (type hierarchy), mirroring `session_provider_app_session_test.dart`'s RDP coverage. The `connectVnc`/watch/close behavior is validated end-to-end in M5 (live VNC container), the same depth RDP has.

- [ ] **Step 1: Write the failing test**

Append to `app/test/providers/session_provider_app_session_test.dart`. First add imports near the top (after the existing model imports on line 5–7):

```dart
import 'package:yourssh/models/vnc_session.dart';
import 'package:yourssh_vnc/yourssh_vnc.dart' show VncClient, VncConfig;
```

Add a host + client builder next to `_rdpClient()` (after line 35):

```dart
Host _vncHost() => Host(
    id: 'vnc1',
    label: 'desktop',
    host: '10.0.0.5',
    port: 5900,
    username: 'u',
    protocol: HostProtocol.vnc);

VncClient _vncClient() => VncClient(VncConfig(
    targetHost: '10.0.0.5', targetPort: 5900, username: 'u', password: ''));
```

Add two tests inside the `group('AppSession type hierarchy', ...)` block (after the RDP case on line 64):

```dart
    test('VncSession is not a TerminalSession', () {
      final s = VncSession(host: _vncHost(), client: _vncClient());
      expect(s is TerminalSession, isFalse);
    });

    test('VncSession is an AppSession', () {
      final s = VncSession(host: _vncHost(), client: _vncClient());
      expect(s, isA<AppSession>());
    });
```

Add the `AppSession` import at the top if not already present:

```dart
import 'package:yourssh/models/app_session.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/providers/session_provider_app_session_test.dart`
Expected: FAIL — `VncSession` URI unresolved.

- [ ] **Step 3: Add VNC imports to the provider**

In `app/lib/providers/session_provider.dart`, after the existing `import 'package:yourssh_rdp/yourssh_rdp.dart';` (line 4), add:

```dart
import 'package:yourssh_vnc/yourssh_vnc.dart';
```

And with the other model imports add:

```dart
import '../models/vnc_session.dart';
```

- [ ] **Step 4: Route `vnc` in `connectAny`**

Change `connectAny` (lines 176–179) from:

```dart
  Future<AppSession?> connectAny(Host host, {String? initialCommand}) {
    if (host.protocol == HostProtocol.rdp) return connectRdp(host);
    return connect(host, initialCommand: initialCommand).then((_) => null);
  }
```

to:

```dart
  Future<AppSession?> connectAny(Host host, {String? initialCommand}) {
    if (host.protocol == HostProtocol.rdp) return connectRdp(host);
    if (host.protocol == HostProtocol.vnc) return connectVnc(host);
    return connect(host, initialCommand: initialCommand).then((_) => null);
  }
```

- [ ] **Step 5: Add `connectVnc`, `_watchVncStatus`, and `reconnectVnc`**

Add these three methods next to `connectRdp`/`_watchRdpStatus`/`reconnectRdp` in `app/lib/providers/session_provider.dart` (e.g. right after `reconnectRdp`, line 330):

```dart
  /// Opens a VNC tab. Mirrors [connectRdp] but with no TLS/cert pinning (plain
  /// VNC has none) and no SSH tunnel yet (direct connections only).
  Future<VncSession?> connectVnc(Host host) async {
    final password = await _ssh.loadPassword(host.id) ?? '';

    String? setupError;
    try {
      // Lazy bridge init: a missing/corrupt dylib surfaces as an error tab
      // instead of an uncatchable LateInitializationError in the bindings.
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

    await _applyTabMetadata(session, host.id);

    if (setupError != null) {
      session.status = VncSessionStatus.error;
      session.lastMessage = setupError;
    } else {
      session.attach(client.events);
      // Failures surface through the event stream (status/lastMessage);
      // swallow the future's mirror error so it can't hit the root zone.
      unawaited(client.connect().then((_) {}, onError: (_) {}));
    }

    _watchVncStatus(session);
    session.addListener(_safeNotify);
    _sessions.add(session);
    _activeSessionId = session.id;
    if (session.isPinned) _sortSessions();
    _safeNotify();
    return session;
  }

  /// Audits VNC connect/disconnect transitions and feeds the notification
  /// bell — parity with [_watchRdpStatus] (no cert flows to special-case).
  void _watchVncStatus(VncSession session) {
    var last = session.status;
    session.addListener(() {
      final now = session.status;
      if (now == last) return;
      final was = last;
      last = now;
      final host = session.host;
      if (was == VncSessionStatus.connecting &&
          now == VncSessionStatus.connected) {
        audit?.record(AuditEvent.now(
            type: AuditEventType.connect,
            host: host,
            sessionId: session.id,
            meta: const {'source': 'vnc'}));
      } else if (was == VncSessionStatus.connecting &&
          (now == VncSessionStatus.error ||
              now == VncSessionStatus.disconnected)) {
        audit?.record(AuditEvent.now(
            type: AuditEventType.connect,
            host: host,
            sessionId: session.id,
            meta: {
              'source': 'vnc',
              'error': session.lastMessage ?? 'connection failed',
            }));
        onSessionDropped?.call(session, session.lastMessage);
      } else if (was == VncSessionStatus.connected) {
        final userClosed = session.lastMessage == 'disconnected by user';
        audit?.record(AuditEvent.now(
            type: AuditEventType.disconnect,
            host: host,
            sessionId: session.id,
            meta: {
              'source': 'vnc',
              'reason': userClosed ? 'user-closed' : 'dropped',
            }));
        if (!userClosed) {
          onSessionDropped?.call(session, session.lastMessage);
        }
      }
    });
  }

  Future<void> reconnectVnc(VncSession old) async {
    // Label/color/pin are persisted on every edit and reloaded by connectVnc's
    // tab-metadata pass — no manual carry-over needed.
    closeSession(old.id);
    await connectVnc(old.host);
  }
```

- [ ] **Step 6: Handle `VncSession` in `closeSession`**

In `closeSession`, immediately after the closing `}` of the `if (session is RdpSession) { ... return; }` block (the RDP branch ends at line 530), add a parallel VNC branch:

```dart
    if (session is VncSession) {
      final hostId = session.host.id;
      // Mirror the SSH/RDP path: a live tab the user closes gets its own row
      // (a dead tab was already audited on the drop/error transition).
      if (session.status == VncSessionStatus.connected) {
        audit?.record(AuditEvent.now(
            type: AuditEventType.disconnect,
            host: session.host,
            sessionId: sessionId,
            meta: const {'source': 'vnc', 'reason': 'user-closed'}));
      }
      session.removeListener(_safeNotify);
      unawaited(session.close());
      _sessions.remove(session);
      if (_activeSessionId == sessionId) {
        _activeSessionId = _sessions.isNotEmpty ? _sessions.last.id : null;
      }
      // No-op for direct VNC; releases the SSH tunnel client once tunneling
      // lands in a later milestone (parity with the RDP branch).
      if (!_sessions.any((s) => s is VncSession && s.host.id == hostId)) {
        _ssh.disconnect(hostId);
      }
      _safeNotify();
      return;
    }
```

- [ ] **Step 7: Add `VncSession` to `_metadataHostId`**

Change `_metadataHostId` (lines 611–615) from:

```dart
  String? _metadataHostId(AppSession s) => switch (s) {
        SshSession ssh => ssh.isWatch ? null : ssh.host.id,
        RdpSession rdp => rdp.host.id,
        _ => null,
      };
```

to:

```dart
  String? _metadataHostId(AppSession s) => switch (s) {
        SshSession ssh => ssh.isWatch ? null : ssh.host.id,
        RdpSession rdp => rdp.host.id,
        VncSession vnc => vnc.host.id,
        _ => null,
      };
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `cd app && flutter test test/providers/session_provider_app_session_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 9: Analyze (no new warnings)**

Run: `cd app && flutter analyze lib/providers/session_provider.dart`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add app/lib/providers/session_provider.dart app/test/providers/session_provider_app_session_test.dart
git commit -m "feat(vnc): route + connect VNC sessions in SessionProvider"
```

---

## Task 4: `VncWorkspace` widget

**Files:**
- Create: `app/lib/widgets/vnc_workspace.dart`
- Test: `app/test/widgets/vnc_workspace_test.dart`

Minimal view-only mirror of `RdpWorkspace`: status overlays, a `CustomPaint`/`_FramePainter` that blits `session.image`, and a 34px toolbar with only a Disconnect button (no input/clipboard/fullscreen — later milestones).

- [ ] **Step 1: Write the failing test**

Create `app/test/widgets/vnc_workspace_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/vnc_session.dart';
import 'package:yourssh/widgets/vnc_workspace.dart';
import 'package:yourssh_vnc/yourssh_vnc.dart' show VncClient, VncConfig;
// ignore: implementation_imports
import 'package:yourssh_vnc/src/generated/api.dart' as frb;

Host _host() => Host(
    id: 'v1',
    label: 'desktop',
    host: '10.0.0.5',
    port: 5900,
    username: 'u',
    protocol: HostProtocol.vnc);

VncClient _client() => VncClient(VncConfig(
    targetHost: '10.0.0.5', targetPort: 5900, username: 'u', password: ''));

void main() {
  testWidgets('shows connecting overlay, then error overlay with retry',
      (tester) async {
    final events = StreamController<frb.VncEvent>();
    final session = VncSession(host: _host(), client: _client());
    session.attach(events.stream);
    var retried = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VncWorkspace(
          session: session,
          onReconnect: () => retried = true,
        ),
      ),
    ));
    expect(find.textContaining('Connecting'), findsOneWidget);

    events.add(const frb.VncEvent.error(message: 'connection refused'));
    await tester.pump();
    expect(find.textContaining('connection refused'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    await events.close();
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/widgets/vnc_workspace_test.dart`
Expected: FAIL — `vnc_workspace.dart` does not exist.

- [ ] **Step 3: Create the widget**

Create `app/lib/widgets/vnc_workspace.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/vnc_session.dart';
import '../theme/app_theme.dart';

/// View-only VNC framebuffer surface. Mirrors RdpWorkspace's render pipeline:
/// the widget rebuilds only on status change, while frames repaint through the
/// painter's `repaint: session` listenable. Input/clipboard/fullscreen are
/// later milestones.
class VncWorkspace extends StatefulWidget {
  const VncWorkspace({super.key, required this.session, this.onReconnect});

  final VncSession session;
  final VoidCallback? onReconnect;

  @override
  State<VncWorkspace> createState() => _VncWorkspaceState();
}

class _VncWorkspaceState extends State<VncWorkspace> {
  VncSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
  }

  @override
  void didUpdateWidget(VncWorkspace old) {
    super.didUpdateWidget(old);
    if (!identical(old.session, widget.session)) {
      old.session.removeListener(_onSessionChanged);
      session.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Toolbar(session: session),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    switch (session.status) {
      case VncSessionStatus.connecting:
        return const Center(
            child: Text('Connecting…',
                style: TextStyle(color: AppColors.textSecondary)));
      case VncSessionStatus.error:
      case VncSessionStatus.disconnected:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(session.lastMessage ?? 'Disconnected',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: widget.onReconnect, child: const Text('Retry')),
          ]),
        );
      case VncSessionStatus.connected:
        return LayoutBuilder(builder: (context, constraints) {
          final img = session.image;
          if (img == null) {
            return const Center(
                child: Text('Waiting for first frame…',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          final scale = math.min(constraints.maxWidth / img.width,
              constraints.maxHeight / img.height);
          final dw = img.width * scale;
          final dh = img.height * scale;
          final offX = (constraints.maxWidth - dw) / 2;
          final offY = (constraints.maxHeight - dh) / 2;
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _FramePainter(session, offX, offY, scale),
          );
        });
    }
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.session});
  final VncSession session;

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
          tooltip: 'Disconnect',
          icon: const Icon(Icons.power_settings_new, size: 16),
          onPressed: () => session.client.disconnect(),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }
}

class _FramePainter extends CustomPainter {
  /// `repaint: session` redraws on every decoded frame without rebuilding the
  /// surrounding widget tree (the workspace only rebuilds on status changes).
  _FramePainter(this.session, this.offX, this.offY, this.scale)
      : super(repaint: session);

  final VncSession session;
  final double offX, offY, scale;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? img = session.image;
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(offX, offY, img.width * scale, img.height * scale),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      !identical(old.session, session) ||
      old.scale != scale ||
      old.offX != offX ||
      old.offY != offY;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app && flutter test test/widgets/vnc_workspace_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/vnc_workspace.dart app/test/widgets/vnc_workspace_test.dart
git commit -m "feat(vnc): minimal view-only VncWorkspace (framebuffer paint)"
```

---

## Task 5: Route `VncSession` to `VncWorkspace` in `MainScreen`

**Files:**
- Modify: `app/lib/screens/main_screen.dart` (imports; `_buildForeground` routing ~778–786; add `_retryVnc`)

- [ ] **Step 1: Add imports**

In `app/lib/screens/main_screen.dart`, with the other model/widget imports, add:

```dart
import '../models/vnc_session.dart';
import '../widgets/vnc_workspace.dart';
```

- [ ] **Step 2: Add the routing branch**

In `_buildForeground`, immediately after the existing RDP block (which ends with its closing `}` around line 786):

```dart
    if (_viewingTerminal && active is RdpSession) {
      return RdpWorkspace(
        session: active,
        onReconnect: () => _retryRdp(active),
        isFullscreen: _rdpFullscreen,
        onFullscreenChanged: (on) => unawaited(_setRdpFullscreen(on)),
      );
    }
```

add:

```dart
    if (_viewingTerminal && active is VncSession) {
      return VncWorkspace(
        session: active,
        onReconnect: () => _retryVnc(active),
      );
    }
```

- [ ] **Step 3: Add the `_retryVnc` method**

Next to `_retryRdp` (it ends at line 913), add:

```dart
  Future<void> _retryVnc(VncSession old) async {
    if (!mounted) return;
    await context.read<SessionProvider>().reconnectVnc(old);
  }
```

- [ ] **Step 4: Analyze the screen compiles cleanly**

Run: `cd app && flutter analyze lib/screens/main_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: Run the full app test suite (nothing regressed)**

Run: `cd app && flutter test`
Expected: PASS — all tests pass (this includes Tasks 1–4's tests).

- [ ] **Step 6: Commit**

```bash
git add app/lib/screens/main_screen.dart
git commit -m "feat(vnc): render VncSession tabs via VncWorkspace in MainScreen"
```

---

## Task 6: VNC option in `HostDetailPanel`

**Files:**
- Modify: `app/lib/widgets/host_detail_panel.dart`
- Test: `app/test/widgets/host_detail_panel_vnc_test.dart` (create)

Lets the user create/edit a VNC host. VNC reuses RDP's "non-SSH" behavior (password-only auth; SSH-only sections hidden) but has **no** domain or RDP-security sections. Introduce `_isGraphical` (`protocol != ssh`) for the SSH-only hiding, and keep `_isRdp` for the RDP-only sections.

**Exact `_isRdp` site disposition** (from `grep -n _isRdp`):
- Keep `_isRdp`: line 88 (getter), 220 (`domain`), 480 (domain field), 490 (RDP SECURITY + SSH TUNNEL), 1090 (RDP spacer), 1147 (RDP badge).
- Change to `_isGraphical`: lines 224, 225, 228, 231, 233, 234 (`_save` flags), 572 (`if (!_isRdp)` SSH-only sections), and the 1089 comment.
- Line 433: replace the 2-way label with a 3-way switch.

- [ ] **Step 1: Write the failing test**

Create `app/test/widgets/host_detail_panel_vnc_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/providers/host_provider.dart';
import 'package:yourssh/providers/key_provider.dart';
import 'package:yourssh/services/agent_probe.dart';
import 'package:yourssh/services/ssh_service.dart';
import 'package:yourssh/services/storage_service.dart';
import 'package:yourssh/widgets/host_detail_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Host? saved;

  Future<void> pumpPanel(WidgetTester tester, {Host? existing}) async {
    saved = null;
    await tester.binding.setSurfaceSize(const Size(500, 3600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final hostProvider = HostProvider(StorageService());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<KeyProvider>(create: (_) => KeyProvider()),
          ChangeNotifierProvider<HostProvider>.value(value: hostProvider),
          Provider<SshService>(create: (_) => SshService(StorageService())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HostDetailPanel(
              existing: existing,
              initialProtocol: existing == null ? HostProtocol.vnc : null,
              agentProbe: () async => const AgentProbeSystem(1),
              onClose: () {},
              onSave: (host, _) async => saved = host,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Host vncHost() => Host(
        id: 'vnc-1',
        label: 'desktop',
        host: '10.0.0.5',
        port: 5900,
        username: 'u',
        protocol: HostProtocol.vnc,
      );

  testWidgets('VNC mode hides SSH-only and RDP-only sections', (tester) async {
    await pumpPanel(tester, existing: vncHost());
    expect(find.text('VNC on'), findsOneWidget);
    // SSH-only:
    expect(find.text('AUTH METHOD'), findsNothing);
    // RDP-only:
    expect(find.text('RDP SECURITY'), findsNothing);
    expect(find.widgetWithText(TextField, 'Domain (optional)'), findsNothing);
  });

  testWidgets('panel exposes a VNC protocol segment', (tester) async {
    await pumpPanel(tester);
    expect(find.text('VNC'), findsWidgets);
  });
}
```

> If `HostDetailPanel`'s constructor does not accept `initialProtocol`, confirm against `app/lib/widgets/host_detail_panel.dart:94` (`widget.initialProtocol`) — it does. The save button label is `SAVE ONLY` (see `host_detail_panel_rdp_test.dart:52`) if a save assertion is added later.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/widgets/host_detail_panel_vnc_test.dart`
Expected: FAIL — no `VNC` segment; `'VNC on'` not found.

- [ ] **Step 3: Add the `_isGraphical` getter**

After line 88 (`bool get _isRdp => _protocol == HostProtocol.rdp;`), add:

```dart
  bool get _isVnc => _protocol == HostProtocol.vnc;
  /// True for any graphical (non-SSH) protocol — these share password-only
  /// auth and hide all SSH-only sections.
  bool get _isGraphical => _protocol != HostProtocol.ssh;
```

- [ ] **Step 4: Add the VNC segment to the protocol selector**

In the `SegmentedButton<HostProtocol>` `segments` list (lines 332–343), after the RDP `ButtonSegment`, add a third segment:

```dart
                      ButtonSegment(
                        value: HostProtocol.rdp,
                        label: Text('RDP'),
                        icon: Icon(Icons.desktop_windows_outlined, size: 14),
                      ),
                      ButtonSegment(
                        value: HostProtocol.vnc,
                        label: Text('VNC'),
                        icon: Icon(Icons.cast_outlined, size: 14),
                      ),
```

- [ ] **Step 5: Force password auth for any graphical protocol**

In `_onProtocolChanged` (line 183), change:

```dart
      if (next == HostProtocol.rdp) {
        // RDP supports password auth only.
        _authType = AuthType.password;
        _selectedKeyId = null;
      }
```

to:

```dart
      if (next != HostProtocol.ssh) {
        // RDP and VNC support password auth only.
        _authType = AuthType.password;
        _selectedKeyId = null;
      }
```

- [ ] **Step 6: Switch the SSH-only `_save` flags to `_isGraphical`**

In `_save` (lines 224–234), change these six lines from `_isRdp` to `_isGraphical` (leave line 220 `domain:` and line 223 `rdpSecurity:` exactly as they are):

```dart
      authType: _isGraphical ? AuthType.password : _authType,
      keyId: !_isGraphical && _authType == AuthType.privateKey ? _selectedKeyId : null,
```
```dart
      autoRecord: !_isGraphical && _autoRecord,
```
```dart
      agentForwarding: !_isGraphical && _agentForwarding,
```
```dart
      sftpMode: _isGraphical ? SftpMode.normal : _sftpMode,
      sftpServerCommand: !_isGraphical && _sftpMode == SftpMode.custom
          ? _sftpCommand.text.trim()
          : null,
```

- [ ] **Step 7: Make the protocol label 3-way**

Change line 433 from:

```dart
                      Text(_isRdp ? 'RDP on' : 'SSH on', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
```

to:

```dart
                      Text(
                          switch (_protocol) {
                            HostProtocol.ssh => 'SSH on',
                            HostProtocol.rdp => 'RDP on',
                            HostProtocol.vnc => 'VNC on',
                          },
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
```

- [ ] **Step 8: Hide the SSH-only sections for any graphical protocol**

Change line 572 from:

```dart
                  if (!_isRdp) ...[
```

to:

```dart
                  if (!_isGraphical) ...[
```

And update the matching comment at line 1089 from `// end !_isRdp (SSH-only sections)` to `// end !_isGraphical (SSH-only sections)`.

- [ ] **Step 9: Run the test to verify it passes**

Run: `cd app && flutter test test/widgets/host_detail_panel_vnc_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 10: Verify RDP panel behavior is unchanged**

Run: `cd app && flutter test test/widgets/host_detail_panel_rdp_test.dart`
Expected: PASS — the RDP path still hides SSH sections and shows domain/security (no regression from the `_isRdp`→`_isGraphical` split).

- [ ] **Step 11: Commit**

```bash
git add app/lib/widgets/host_detail_panel.dart app/test/widgets/host_detail_panel_vnc_test.dart
git commit -m "feat(vnc): VNC protocol option in HostDetailPanel"
```

---

## Final verification

- [ ] **Analyze the whole app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Run the full test suite**

Run: `cd app && flutter test`
Expected: all tests pass.

- [ ] **(Optional, requires a live server) Manual smoke test**

Start a local VNC server (e.g. `x11vnc -display :0 -rfbport 5900 -passwd secret`, or a TigerVNC/TightVNC container), create a VNC host in the app (host/port 5900/password), connect, and confirm the remote framebuffer renders and updates. Disconnect from the toolbar and confirm the tab shows "disconnected" with a working Retry.

---

## Self-Review

**1. Spec coverage** (umbrella `2026-06-16-vnc-support-design.md`, Milestone 2 = "End-to-end view-only"):
- `HostProtocol.vnc` (default 5900) → Task 1. ✓
- `VncSession implements AppSession` (framebuffer realloc, latest-wins decode, status, `close()` timeout) → Task 2. ✓
- `SessionProvider.connectVnc` (lazy init → error tab, tab metadata, audit `source: vnc`, drop watch) → Task 3. ✓
- Minimal `VncWorkspace` rendering the framebuffer → Task 4. ✓
- Reachable end-to-end: `connectAny` route (Task 3) + `MainScreen` branch (Task 5) + create-a-VNC-host UI (Task 6). ✓
- Deliberately deferred (documented): cert pinning (N/A for VNC), SSH tunnel, input, clipboard, fullscreen, protocol badge, dashboard polish, integration screenshots. ✓

**2. Placeholder scan:** No TBD/"handle errors"/"similar to Task N"; every code step has complete code. ✓

**3. Type consistency:** `VncSessionStatus.{connecting,connected,disconnected,error}` used identically in the model, provider watch/close, and workspace. `VncSession({required host, required client})` (no width/height) used identically across model, provider, and all tests. `VncWorkspace({required session, onReconnect})` matches its test and the MainScreen call site. Event subclass names (`VncEvent_Connected(:final width, :final height)`, `VncEvent_FrameUpdate(:final x,:final y,:final width,:final height,:final rgba)`) match `api.rs`. ✓
