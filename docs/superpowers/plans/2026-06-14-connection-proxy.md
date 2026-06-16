# Connection Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect a host's SSH session through an outbound HTTP CONNECT or SOCKS5 proxy (optional auth), gated per host, applied to local-originated TCP dials (direct target + first bastion).

**Architecture:** App-side, no dartssh2 fork change. A pure handshake module (`proxy_handshake.dart`) drives a buffered `ByteReader`; `ConnectionProxy.connect` produces an `SSHSocket` whose stream re-emits the handshake leftover ahead of live data. `SshService.localDial` chooses direct vs proxied dialing via two injectable seams and is wired into the three local-originated dial sites.

**Tech Stack:** Dart `dart:io` (`Socket`), `dart:convert` (base64/utf8), dartssh2 fork `SSHSocket` (public interface, unchanged), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-14-connection-proxy-design.md`

**Refinement vs spec:** handshake functions return the leftover `Uint8List` (via `ByteReader.takeLeftover()`); `ByteReader.release()` then yields a stream of *subsequent* live bytes only, and `ConnectionProxy` prepends the leftover. This avoids re-listening to the single-subscription `Socket`.

---

## File structure

- Create: `app/lib/models/proxy_settings.dart` — `ProxyType` enum + `ProxySettings` value.
- Create: `app/lib/services/proxy_handshake.dart` — `ProxyException`, `ByteReader`, `httpConnectHandshake`, `socks5Handshake`.
- Create: `app/lib/services/connection_proxy.dart` — `ConnectionProxy.connect` + `_ProxiedSocket`.
- Modify: `app/lib/models/host.dart` — proxy fields.
- Modify: `app/lib/services/storage_service.dart` — (none needed; reuse generic-secret helpers).
- Modify: `app/lib/services/ssh_service.dart` — proxy password helpers, dial seams, `localDial`, wire 3 sites.
- Modify: `app/lib/widgets/host_detail_panel.dart` — PROXY section + persist proxy password.
- Tests: one per module under `app/test/...` (paths in each task).

All commands run from `/Users/thangnguyen/Projects/Personal/yourssh/app` (Flutter root). Git commands `cd` to the repo root explicitly.

---

### Task 1: `ProxyType` + `ProxySettings`

**Files:**
- Create: `app/lib/models/proxy_settings.dart`
- Test: `app/test/models/proxy_settings_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/models/proxy_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/proxy_settings.dart';

void main() {
  test('ProxyType has none/http/socks5', () {
    expect(ProxyType.values, [ProxyType.none, ProxyType.http, ProxyType.socks5]);
  });

  test('ProxySettings holds its fields', () {
    const s = ProxySettings(
        type: ProxyType.socks5, host: 'p', port: 1080, username: 'u', password: 'x');
    expect(s.type, ProxyType.socks5);
    expect(s.host, 'p');
    expect(s.port, 1080);
    expect(s.username, 'u');
    expect(s.password, 'x');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/proxy_settings_test.dart`
Expected: FAIL — `proxy_settings.dart` / `ProxyType` not found.

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/models/proxy_settings.dart`:

```dart
enum ProxyType { none, http, socks5 }

/// Runtime proxy parameters resolved from a Host plus its stored password.
class ProxySettings {
  final ProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;
  const ProxySettings({
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/proxy_settings_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/thangnguyen/Projects/Personal/yourssh
git add app/lib/models/proxy_settings.dart app/test/models/proxy_settings_test.dart
git commit -m "feat(proxy): ProxyType enum + ProxySettings value"
```

---

### Task 2: `ByteReader` + `ProxyException` + HTTP CONNECT handshake

**Files:**
- Create: `app/lib/services/proxy_handshake.dart`
- Test: `app/test/services/proxy_handshake_http_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/services/proxy_handshake_http_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/services/proxy_handshake.dart';

/// Minimal StreamSink that records everything written.
class _ListSink implements StreamSink<List<int>> {
  final List<int> bytes = [];
  @override void add(List<int> data) => bytes.addAll(data);
  @override void addError(Object error, [StackTrace? st]) {}
  @override Future addStream(Stream<List<int>> stream) => stream.forEach(add);
  @override Future close() async {}
  @override Future get done => Future.value();
}

void main() {
  test('200 success returns leftover bytes', () async {
    final input = StreamController<Uint8List>();
    final sink = _ListSink();
    final reader = ByteReader(input.stream);
    final future = httpConnectHandshake(reader, sink,
        targetHost: 'example.com', targetPort: 22);

    expect(utf8.decode(sink.bytes), contains('CONNECT example.com:22 HTTP/1.1'));
    expect(utf8.decode(sink.bytes), isNot(contains('Proxy-Authorization')));

    input.add(Uint8List.fromList(
        utf8.encode('HTTP/1.1 200 Connection established\r\n\r\nSSHPREFIX')));
    final leftover = await future;
    expect(utf8.decode(leftover), 'SSHPREFIX');
  });

  test('Basic auth header is sent when credentials given', () async {
    final input = StreamController<Uint8List>();
    final sink = _ListSink();
    final reader = ByteReader(input.stream);
    final future = httpConnectHandshake(reader, sink,
        targetHost: 'h', targetPort: 22, username: 'u', password: 'p');
    final expected = base64.encode(utf8.encode('u:p'));
    expect(utf8.decode(sink.bytes), contains('Proxy-Authorization: Basic $expected'));
    input.add(Uint8List.fromList(utf8.encode('HTTP/1.1 200 OK\r\n\r\n')));
    await future;
  });

  test('non-200 throws ProxyException', () async {
    final input = StreamController<Uint8List>();
    final sink = _ListSink();
    final reader = ByteReader(input.stream);
    final future = httpConnectHandshake(reader, sink, targetHost: 'h', targetPort: 22);
    input.add(Uint8List.fromList(
        utf8.encode('HTTP/1.1 407 Proxy Authentication Required\r\n\r\n')));
    await expectLater(future, throwsA(isA<ProxyException>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/proxy_handshake_http_test.dart`
Expected: FAIL — `proxy_handshake.dart` / `ByteReader` / `httpConnectHandshake` not found.

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/services/proxy_handshake.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Raised for any proxy handshake failure (refusal, auth, malformed reply,
/// early close).
class ProxyException implements Exception {
  final String message;
  const ProxyException(this.message);
  @override
  String toString() => 'ProxyException: $message';
}

/// Buffered byte reader over a socket stream. Serves [readExactly]/[readUntil]
/// during the handshake; afterwards [takeLeftover] returns the buffered tail
/// and [release] hands the live remainder out as a stream. Single pending read
/// at a time (handshakes are sequential).
class ByteReader {
  ByteReader(Stream<Uint8List> stream) {
    _sub = stream.listen(_onData, onError: _onError, onDone: _onDone);
  }

  late final StreamSubscription<Uint8List> _sub;
  final List<int> _buf = [];
  bool _done = false;
  Object? _error;
  void Function()? _wake;
  StreamController<Uint8List>? _out;

  void _onData(Uint8List chunk) {
    if (_out != null) {
      _out!.add(chunk);
      return;
    }
    _buf.addAll(chunk);
    _wake?.call();
  }

  void _onError(Object e, StackTrace st) {
    if (_out != null) {
      _out!.addError(e, st);
      return;
    }
    _error = e;
    _wake?.call();
  }

  void _onDone() {
    if (_out != null) {
      _out!.close();
      return;
    }
    _done = true;
    _wake?.call();
  }

  Future<Uint8List> readExactly(int n) {
    final completer = Completer<Uint8List>();
    void attempt() {
      if (completer.isCompleted) return;
      if (_error != null) {
        _wake = null;
        completer.completeError(_error!);
      } else if (_buf.length >= n) {
        final out = Uint8List.fromList(_buf.sublist(0, n));
        _buf.removeRange(0, n);
        _wake = null;
        completer.complete(out);
      } else if (_done) {
        _wake = null;
        completer.completeError(
            const ProxyException('proxy closed connection during handshake'));
      }
    }

    _wake = attempt;
    attempt();
    return completer.future;
  }

  Future<Uint8List> readUntil(List<int> delimiter) {
    final completer = Completer<Uint8List>();
    void attempt() {
      if (completer.isCompleted) return;
      if (_error != null) {
        _wake = null;
        completer.completeError(_error!);
        return;
      }
      final idx = _indexOf(_buf, delimiter);
      if (idx >= 0) {
        final end = idx + delimiter.length;
        final out = Uint8List.fromList(_buf.sublist(0, end));
        _buf.removeRange(0, end);
        _wake = null;
        completer.complete(out);
      } else if (_done) {
        _wake = null;
        completer.completeError(
            const ProxyException('proxy closed connection during handshake'));
      }
    }

    _wake = attempt;
    attempt();
    return completer.future;
  }

  /// The bytes buffered but not consumed by the handshake.
  Uint8List takeLeftover() {
    final out = Uint8List.fromList(_buf);
    _buf.clear();
    return out;
  }

  /// Hands the live remainder of the stream out. Call once, after the
  /// handshake. The buffer must already be drained via [takeLeftover].
  Stream<Uint8List> release() {
    final out = StreamController<Uint8List>();
    _out = out;
    out.onCancel = () => _sub.cancel();
    if (_done) {
      out.close();
    } else if (_error != null) {
      out.addError(_error!);
    }
    return out.stream;
  }

  Future<void> destroy() => _sub.cancel();

  static int _indexOf(List<int> hay, List<int> needle) {
    for (var i = 0; i + needle.length <= hay.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (hay[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}

/// HTTP CONNECT handshake. Writes the request (optional Basic auth), reads
/// response headers up to `\r\n\r\n`, requires a 200 status. Returns the
/// bytes already read past the header terminator.
Future<Uint8List> httpConnectHandshake(
  ByteReader reader,
  StreamSink<List<int>> sink, {
  required String targetHost,
  required int targetPort,
  String? username,
  String? password,
}) async {
  final req = StringBuffer()
    ..write('CONNECT $targetHost:$targetPort HTTP/1.1\r\n')
    ..write('Host: $targetHost:$targetPort\r\n');
  if (username != null && username.isNotEmpty) {
    final cred = base64.encode(utf8.encode('$username:${password ?? ''}'));
    req.write('Proxy-Authorization: Basic $cred\r\n');
  }
  req.write('\r\n');
  sink.add(utf8.encode(req.toString()));

  final header = await reader.readUntil(const [13, 10, 13, 10]); // \r\n\r\n
  final statusLine = ascii.decode(header, allowInvalid: true).split('\r\n').first;
  final parts = statusLine.split(' ');
  if (parts.length < 2 || parts[1] != '200') {
    throw ProxyException('HTTP proxy refused: $statusLine');
  }
  return reader.takeLeftover();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/proxy_handshake_http_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/thangnguyen/Projects/Personal/yourssh
git add app/lib/services/proxy_handshake.dart app/test/services/proxy_handshake_http_test.dart
git commit -m "feat(proxy): ByteReader + HTTP CONNECT handshake"
```

---

### Task 3: SOCKS5 handshake

**Files:**
- Modify: `app/lib/services/proxy_handshake.dart` (append `socks5Handshake` + reply-code map)
- Test: `app/test/services/proxy_handshake_socks5_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/services/proxy_handshake_socks5_test.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/services/proxy_handshake.dart';

class _ListSink implements StreamSink<List<int>> {
  final List<int> bytes = [];
  @override void add(List<int> data) => bytes.addAll(data);
  @override void addError(Object error, [StackTrace? st]) {}
  @override Future addStream(Stream<List<int>> stream) => stream.forEach(add);
  @override Future close() async {}
  @override Future get done => Future.value();
}

void main() {
  test('no-auth path: greeting, CONNECT with domain ATYP, success', () async {
    final input = StreamController<Uint8List>();
    final sink = _ListSink();
    final reader = ByteReader(input.stream);
    final future = socks5Handshake(reader, sink,
        targetHost: 'host.internal', targetPort: 2222);

    // greeting: VER=5, NMETHODS=1, METHOD=0x00
    expect(sink.bytes.sublist(0, 3), [0x05, 0x01, 0x00]);
    input.add(Uint8List.fromList([0x05, 0x00])); // select no-auth

    await Future<void>.delayed(Duration.zero); // let CONNECT be written
    // CONNECT: VER=5, CMD=1, RSV=0, ATYP=3, len, host..., port hi, port lo
    final host = 'host.internal'.codeUnits;
    final expected = [0x05, 0x01, 0x00, 0x03, host.length, ...host, 0x08, 0xAE];
    expect(sink.bytes.sublist(3), expected);

    // reply: VER, REP=0, RSV, ATYP=1 (ipv4), 4 addr, 2 port, then SSH leftover
    input.add(Uint8List.fromList(
        [0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0, 0x53, 0x53])); // 'SS' leftover
    final leftover = await future;
    expect(leftover, [0x53, 0x53]);
  });

  test('user/pass path: RFC 1929 auth then success', () async {
    final input = StreamController<Uint8List>();
    final sink = _ListSink();
    final reader = ByteReader(input.stream);
    final future = socks5Handshake(reader, sink,
        targetHost: 'h', targetPort: 22, username: 'u', password: 'p');

    // greeting offers no-auth + user/pass
    expect(sink.bytes.sublist(0, 4), [0x05, 0x02, 0x00, 0x02]);
    input.add(Uint8List.fromList([0x05, 0x02])); // select user/pass

    await Future<void>.delayed(Duration.zero);
    // auth: VER=1, ulen, 'u', plen, 'p'
    final authStart = 4;
    expect(sink.bytes.sublist(authStart, authStart + 5),
        [0x01, 0x01, 'u'.codeUnitAt(0), 0x01, 'p'.codeUnitAt(0)]);
    input.add(Uint8List.fromList([0x01, 0x00])); // auth success

    await Future<void>.delayed(Duration.zero);
    input.add(Uint8List.fromList([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]));
    await future; // completes without throwing
  });

  test('reply 0x05 maps to connection refused', () async {
    final input = StreamController<Uint8List>();
    final sink = _ListSink();
    final reader = ByteReader(input.stream);
    final future = socks5Handshake(reader, sink, targetHost: 'h', targetPort: 22);
    input.add(Uint8List.fromList([0x05, 0x00]));
    await Future<void>.delayed(Duration.zero);
    input.add(Uint8List.fromList([0x05, 0x05, 0x00, 0x01, 0, 0, 0, 0, 0, 0]));
    await expectLater(
        future,
        throwsA(isA<ProxyException>().having(
            (e) => e.message, 'message', contains('refused'))));
  });

  test('auth failure throws', () async {
    final input = StreamController<Uint8List>();
    final sink = _ListSink();
    final reader = ByteReader(input.stream);
    final future = socks5Handshake(reader, sink,
        targetHost: 'h', targetPort: 22, username: 'u', password: 'bad');
    input.add(Uint8List.fromList([0x05, 0x02]));
    await Future<void>.delayed(Duration.zero);
    input.add(Uint8List.fromList([0x01, 0x01])); // auth fail
    await expectLater(future, throwsA(isA<ProxyException>()));
  });
}
```

Note: port 2222 = `0x08AE` (hi `0x08`, lo `0xAE`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/proxy_handshake_socks5_test.dart`
Expected: FAIL — `socks5Handshake` not found.

- [ ] **Step 3: Write minimal implementation**

Append to `app/lib/services/proxy_handshake.dart`:

```dart
/// SOCKS5 handshake: greeting (no-auth + optional user/pass), optional RFC 1929
/// auth, then a CONNECT request with the target as a domain address (ATYP 0x03 →
/// remote DNS). Returns any over-read tail.
Future<Uint8List> socks5Handshake(
  ByteReader reader,
  StreamSink<List<int>> sink, {
  required String targetHost,
  required int targetPort,
  String? username,
  String? password,
}) async {
  final hasAuth = username != null && username.isNotEmpty;
  final methods = hasAuth ? [0x00, 0x02] : [0x00];
  sink.add(Uint8List.fromList([0x05, methods.length, ...methods]));

  final sel = await reader.readExactly(2);
  if (sel[0] != 0x05) throw const ProxyException('not a SOCKS5 proxy');
  final method = sel[1];
  if (method == 0xFF) {
    throw const ProxyException('SOCKS5 proxy rejected all auth methods');
  }
  if (method == 0x02) {
    if (!hasAuth) {
      throw const ProxyException('SOCKS5 proxy requires username/password');
    }
    final u = utf8.encode(username);
    final p = utf8.encode(password ?? '');
    sink.add(Uint8List.fromList([0x01, u.length, ...u, p.length, ...p]));
    final authResp = await reader.readExactly(2);
    if (authResp[1] != 0x00) {
      throw const ProxyException('SOCKS5 authentication failed');
    }
  } else if (method != 0x00) {
    throw ProxyException('SOCKS5 proxy selected unsupported method $method');
  }

  final hostBytes = utf8.encode(targetHost);
  if (hostBytes.length > 255) {
    throw const ProxyException('hostname too long for SOCKS5');
  }
  sink.add(Uint8List.fromList([
    0x05, 0x01, 0x00, 0x03, hostBytes.length, ...hostBytes,
    (targetPort >> 8) & 0xff, targetPort & 0xff,
  ]));

  final head = await reader.readExactly(4); // VER, REP, RSV, ATYP
  if (head[1] != 0x00) throw ProxyException(_socksReplyMessage(head[1]));
  final atyp = head[3];
  int addrLen;
  if (atyp == 0x01) {
    addrLen = 4;
  } else if (atyp == 0x04) {
    addrLen = 16;
  } else if (atyp == 0x03) {
    addrLen = (await reader.readExactly(1))[0];
  } else {
    throw ProxyException('SOCKS5 unsupported address type $atyp');
  }
  await reader.readExactly(addrLen + 2); // bound address + port
  return reader.takeLeftover();
}

String _socksReplyMessage(int rep) {
  switch (rep) {
    case 0x01:
      return 'SOCKS5 general failure';
    case 0x02:
      return 'SOCKS5 connection not allowed by ruleset';
    case 0x03:
      return 'SOCKS5 network unreachable';
    case 0x04:
      return 'SOCKS5 host unreachable';
    case 0x05:
      return 'SOCKS5 connection refused';
    case 0x06:
      return 'SOCKS5 TTL expired';
    case 0x07:
      return 'SOCKS5 command not supported';
    case 0x08:
      return 'SOCKS5 address type not supported';
    default:
      return 'SOCKS5 failed (code $rep)';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/proxy_handshake_socks5_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/thangnguyen/Projects/Personal/yourssh
git add app/lib/services/proxy_handshake.dart app/test/services/proxy_handshake_socks5_test.dart
git commit -m "feat(proxy): SOCKS5 handshake with optional RFC 1929 auth"
```

---

### Task 4: `ConnectionProxy.connect` + `_ProxiedSocket`

**Files:**
- Create: `app/lib/services/connection_proxy.dart`
- Test: `app/test/services/connection_proxy_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/services/connection_proxy_test.dart` (covers the leftover-prepend behavior of the released stream, which is the risky part; the real `Socket.connect` path is exercised by manual smoke):

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/services/proxy_handshake.dart';

void main() {
  test('release() emits live data; takeLeftover returns buffered tail', () async {
    final input = StreamController<Uint8List>();
    final reader = ByteReader(input.stream);

    // Simulate a handshake having read up to a point, leaving trailing bytes.
    input.add(Uint8List.fromList([1, 2, 3, 4]));
    await Future<void>.delayed(Duration.zero);
    final firstTwo = await reader.readExactly(2);
    expect(firstTwo, [1, 2]);

    final leftover = reader.takeLeftover();
    expect(leftover, [3, 4]);

    final live = <int>[];
    final done = Completer<void>();
    reader.release().listen(live.addAll, onDone: done.complete);
    input.add(Uint8List.fromList([5, 6]));
    await Future<void>.delayed(Duration.zero);
    await input.close();
    await done.future;
    expect(live, [5, 6]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/connection_proxy_test.dart`
Expected: this test exercises only `proxy_handshake.dart` and should PASS already once Task 2 is done. (It documents the handoff contract `ConnectionProxy` relies on.) If Task 2 is complete it passes immediately — proceed to write `connection_proxy.dart` anyway in Step 3 since later tasks import it.

- [ ] **Step 3: Write the implementation**

Create `app/lib/services/connection_proxy.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/proxy_settings.dart';
import 'proxy_handshake.dart';

class ConnectionProxy {
  /// Connects to the proxy, runs the type-specific handshake to tunnel to
  /// [targetHost]:[targetPort], and returns an [SSHSocket] whose stream
  /// re-emits the handshake leftover before live data. When [timeout] is set
  /// it bounds the whole connect-plus-handshake. Destroys the socket on any
  /// failure.
  static Future<SSHSocket> connect({
    required ProxySettings settings,
    required String targetHost,
    required int targetPort,
    Duration? timeout,
  }) {
    Future<SSHSocket> run() async {
      final socket = await Socket.connect(settings.host, settings.port);
      try {
        final reader = ByteReader(socket);
        final Uint8List leftover;
        switch (settings.type) {
          case ProxyType.http:
            leftover = await httpConnectHandshake(reader, socket,
                targetHost: targetHost,
                targetPort: targetPort,
                username: settings.username,
                password: settings.password);
          case ProxyType.socks5:
            leftover = await socks5Handshake(reader, socket,
                targetHost: targetHost,
                targetPort: targetPort,
                username: settings.username,
                password: settings.password);
          case ProxyType.none:
            throw const ProxyException(
                'ConnectionProxy.connect called with ProxyType.none');
        }
        return _ProxiedSocket(socket, leftover, reader.release());
      } catch (_) {
        socket.destroy();
        rethrow;
      }
    }

    final fut = run();
    return timeout == null ? fut : fut.timeout(timeout);
  }
}

class _ProxiedSocket implements SSHSocket {
  _ProxiedSocket(this._socket, Uint8List leftover, Stream<Uint8List> live)
      : _stream = _prepend(leftover, live);

  final Socket _socket;
  final Stream<Uint8List> _stream;

  static Stream<Uint8List> _prepend(
      Uint8List head, Stream<Uint8List> tail) async* {
    if (head.isNotEmpty) yield head;
    yield* tail;
  }

  @override
  Stream<Uint8List> get stream => _stream;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() async {
    await _socket.close();
  }

  @override
  void destroy() => _socket.destroy();
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/services/connection_proxy_test.dart`
Expected: PASS (1 test). Also `flutter analyze lib/services/connection_proxy.dart` → no issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/thangnguyen/Projects/Personal/yourssh
git add app/lib/services/connection_proxy.dart app/test/services/connection_proxy_test.dart
git commit -m "feat(proxy): ConnectionProxy.connect producing a proxied SSHSocket"
```

---

### Task 5: Host proxy fields

**Files:**
- Modify: `app/lib/models/host.dart` (import; field block ~48; ctor ~85; toJson ~135; fromJson parse + ~225; copyWith sig ~255 + body ~286)
- Test: `app/test/models/host_proxy_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/models/host_proxy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/proxy_settings.dart';

void main() {
  group('Host proxy fields', () {
    test('defaults: none type, null host/port/username', () {
      final h = Host(label: 'a', host: 'h', username: 'u');
      expect(h.proxyType, ProxyType.none);
      expect(h.proxyHost, isNull);
      expect(h.proxyPort, isNull);
      expect(h.proxyUsername, isNull);
    });

    test('round-trips through toJson/fromJson', () {
      final h = Host(
          label: 'a',
          host: 'h',
          username: 'u',
          proxyType: ProxyType.http,
          proxyHost: 'proxy',
          proxyPort: 8080,
          proxyUsername: 'pu');
      final back = Host.fromJson(h.toJson());
      expect(back.proxyType, ProxyType.http);
      expect(back.proxyHost, 'proxy');
      expect(back.proxyPort, 8080);
      expect(back.proxyUsername, 'pu');
    });

    test('unknown proxyType string falls back to none', () {
      final json = Host(label: 'a', host: 'h', username: 'u').toJson()
        ..['proxyType'] = 'bogus';
      expect(Host.fromJson(json).proxyType, ProxyType.none);
    });

    test('copyWith overrides proxy fields', () {
      final h = Host(label: 'a', host: 'h', username: 'u');
      final c = h.copyWith(
          proxyType: ProxyType.socks5, proxyHost: 'p', proxyPort: 1080);
      expect(c.proxyType, ProxyType.socks5);
      expect(c.proxyHost, 'p');
      expect(c.proxyPort, 1080);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/host_proxy_test.dart`
Expected: FAIL — `proxyType` not a parameter / getter undefined.

- [ ] **Step 3: Write minimal implementation**

In `app/lib/models/host.dart`:

(a) Add import near the other model imports at the top of the file:
```dart
import 'proxy_settings.dart';
```

(b) Field block — after `bool agentForwarding;` (and `bool osc52Clipboard;` from the OSC 52 work; place after the bools, before `SftpMode sftpMode;`):
```dart
  ProxyType proxyType;
  String? proxyHost;
  int? proxyPort;
  String? proxyUsername;
```

(c) Constructor — after `this.agentForwarding = false,` (and `this.osc52Clipboard = false,`):
```dart
    this.proxyType = ProxyType.none,
    this.proxyHost,
    this.proxyPort,
    this.proxyUsername,
```

(d) `toJson` — after `'agentForwarding': agentForwarding,` (and the osc52 line):
```dart
        'proxyType': proxyType.name,
        'proxyHost': proxyHost,
        'proxyPort': proxyPort,
        'proxyUsername': proxyUsername,
```

(e) `fromJson` — add a local parser near the other `parseX` helpers in `fromJson`:
```dart
    ProxyType parseProxyType() {
      final name = json['proxyType'] as String?;
      if (name == null) return ProxyType.none;
      return ProxyType.values.asNameMap()[name] ?? ProxyType.none;
    }
```
and in the returned `Host(...)`, after the `agentForwarding:`/`osc52Clipboard:` lines:
```dart
      proxyType: parseProxyType(),
      proxyHost: json['proxyHost'] as String?,
      proxyPort: (json['proxyPort'] as num?)?.toInt(),
      proxyUsername: json['proxyUsername'] as String?,
```

(f) `copyWith` signature — after `bool? agentForwarding,` (and `bool? osc52Clipboard,`):
```dart
    ProxyType? proxyType,
    String? proxyHost,
    int? proxyPort,
    String? proxyUsername,
```

(g) `copyWith` body — after `agentForwarding: agentForwarding ?? this.agentForwarding,` (and osc52 line):
```dart
        proxyType: proxyType ?? this.proxyType,
        proxyHost: proxyHost ?? this.proxyHost,
        proxyPort: proxyPort ?? this.proxyPort,
        proxyUsername: proxyUsername ?? this.proxyUsername,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/host_proxy_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/thangnguyen/Projects/Personal/yourssh
git add app/lib/models/host.dart app/test/models/host_proxy_test.dart
git commit -m "feat(proxy): add Host proxy fields"
```

---

### Task 6: `SshService` proxy password + `localDial` + wire dials

**Files:**
- Modify: `app/lib/services/ssh_service.dart` (imports; password helpers; dial seams; `localDial`; call sites 248/330/521)
- Test: `app/test/services/ssh_service_proxy_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/services/ssh_service_proxy_test.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/proxy_settings.dart';
import 'package:yourssh/services/ssh_service.dart';
import 'package:yourssh/services/storage_service.dart';

class _FakeSocket implements SSHSocket {
  @override Stream<Uint8List> get stream => const Stream.empty();
  @override StreamSink<List<int>> get sink => throw UnimplementedError();
  @override Future<void> get done => Future.value();
  @override Future<void> close() async {}
  @override void destroy() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('localDial uses the direct dialer when proxyType is none', () async {
    final svc = SshService(StorageService());
    final fake = _FakeSocket();
    String? dialedHost;
    int? dialedPort;
    svc.directDialer = (h, p, {timeout}) async {
      dialedHost = h;
      dialedPort = p;
      return fake;
    };
    svc.proxyDialer = ({required settings, required targetHost, required targetPort, timeout}) async =>
        throw StateError('proxy dialer must not be called');

    final host = Host(label: 'a', host: 'srv', port: 22, username: 'u');
    final s = await svc.localDial(host);

    expect(identical(s, fake), isTrue);
    expect(dialedHost, 'srv');
    expect(dialedPort, 22);
  });

  test('localDial uses the proxy dialer with resolved settings', () async {
    final svc = SshService(StorageService());
    final host = Host(
        label: 'a',
        host: 'target',
        port: 2222,
        username: 'u',
        proxyType: ProxyType.socks5,
        proxyHost: 'proxy',
        proxyPort: 1080,
        proxyUsername: 'pu');
    await svc.saveProxyPassword(host.id, 'secret');

    ProxySettings? got;
    String? gotTarget;
    int? gotPort;
    svc.proxyDialer = ({required settings, required targetHost, required targetPort, timeout}) async {
      got = settings;
      gotTarget = targetHost;
      gotPort = targetPort;
      return _FakeSocket();
    };

    await svc.localDial(host);

    expect(got!.type, ProxyType.socks5);
    expect(got!.host, 'proxy');
    expect(got!.port, 1080);
    expect(got!.username, 'pu');
    expect(got!.password, 'secret');
    expect(gotTarget, 'target');
    expect(gotPort, 2222);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/ssh_service_proxy_test.dart`
Expected: FAIL — `directDialer`/`proxyDialer`/`localDial`/`saveProxyPassword` undefined.

- [ ] **Step 3: Write minimal implementation**

In `app/lib/services/ssh_service.dart`:

(a) Add imports after the existing service imports (alongside the OSC 52 `osc52_clipboard.dart` import):
```dart
import 'connection_proxy.dart';
import 'proxy_handshake.dart';
import '../models/proxy_settings.dart';
```

(b) Add dial seams just before the constructor (near `clipboardWriter`):
```dart
  /// Direct TCP dialer; injectable for tests. Defaults to the native socket.
  @visibleForTesting
  Future<SSHSocket> Function(String host, int port, {Duration? timeout})
      directDialer = SSHSocket.connect;

  /// Proxied dialer; injectable for tests. Defaults to [ConnectionProxy.connect].
  @visibleForTesting
  Future<SSHSocket> Function({
    required ProxySettings settings,
    required String targetHost,
    required int targetPort,
    Duration? timeout,
  }) proxyDialer = ConnectionProxy.connect;
```

(c) Add proxy-password helpers (near the top-level public methods, e.g. after where `loadPassword` is exposed or anywhere in the class body):
```dart
  Future<String?> loadProxyPassword(String hostId) =>
      _storage.loadGenericSecret('proxy_pw_$hostId');

  Future<void> saveProxyPassword(String hostId, String password) =>
      password.isEmpty
          ? _storage.deleteGenericSecret('proxy_pw_$hostId')
          : _storage.saveGenericSecret('proxy_pw_$hostId', password);
```
> Note: if `SshService` has no public `loadPassword`, add one too: `Future<String?> loadPassword(String hostId) => _storage.loadPassword(hostId);` — but it is already used by the host panel (`context.read<SshService>().loadPassword`), so it exists.

(d) Add `localDial`:
```dart
  /// Opens the first local-originated TCP transport for [host], routing through
  /// the host's configured proxy when set. Used for a direct connect, the first
  /// bastion hop, and test-connection.
  @visibleForTesting
  Future<SSHSocket> localDial(Host host, {Duration? timeout}) async {
    if (host.proxyType == ProxyType.none) {
      return directDialer(host.host, host.port, timeout: timeout);
    }
    if (host.proxyHost == null || host.proxyHost!.isEmpty || host.proxyPort == null) {
      throw const ProxyException('Proxy enabled but proxy host/port is missing');
    }
    final pw = await loadProxyPassword(host.id);
    return proxyDialer(
      settings: ProxySettings(
        type: host.proxyType,
        host: host.proxyHost!,
        port: host.proxyPort!,
        username: (host.proxyUsername?.isEmpty ?? true) ? null : host.proxyUsername,
        password: (pw?.isEmpty ?? true) ? null : pw,
      ),
      targetHost: host.host,
      targetPort: host.port,
      timeout: timeout,
    );
  }
```

(e) Wire the three local-originated dial sites:

`connect` (line ~248): replace
```dart
        socket = await SSHSocket.connect(host.host, host.port);
```
with
```dart
        socket = await localDial(host);
```

`dialHop` (line ~330): replace
```dart
      over ?? await SSHSocket.connect(hop.host, hop.port),
```
with
```dart
      over ?? await localDial(hop),
```

`testConnection` (line ~521): replace
```dart
        socket = await SSHSocket.connect(host.host, host.port)
            .timeout(const Duration(seconds: 10));
```
with
```dart
        socket = await localDial(host, timeout: const Duration(seconds: 10));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/ssh_service_proxy_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/thangnguyen/Projects/Personal/yourssh
git add app/lib/services/ssh_service.dart app/test/services/ssh_service_proxy_test.dart
git commit -m "feat(proxy): route local-originated dials through the configured proxy"
```

---

### Task 7: Host panel PROXY section

**Files:**
- Modify: `app/lib/widgets/host_detail_panel.dart` (controllers/state; init incl. proxy password load; `_buildHost`/save proxy fields; persist proxy password; PROXY section UI in the `!_isRdp` block; dispose)
- Test: `app/test/widgets/host_detail_panel_proxy_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/widgets/host_detail_panel_proxy_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/proxy_settings.dart';
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
    await tester.binding.setSurfaceSize(const Size(500, 2800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<KeyProvider>(create: (_) => KeyProvider()),
          ChangeNotifierProvider<HostProvider>(
              create: (_) => HostProvider(StorageService())),
          Provider<SshService>(create: (_) => SshService(StorageService())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HostDetailPanel(
              existing: existing,
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

  testWidgets('proxy dropdown defaults to None and hides fields', (tester) async {
    await pumpPanel(tester, existing: Host(label: 's', host: 'h', username: 'u'));
    final dropdown = find.byKey(const ValueKey('proxy-type-dropdown'));
    await tester.ensureVisible(dropdown);
    expect(find.byKey(const ValueKey('proxy-host-field')), findsNothing);
  });

  testWidgets('selecting HTTP reveals host/port and saving round-trips',
      (tester) async {
    await pumpPanel(tester, existing: Host(label: 's', host: 'h', username: 'u'));

    final dropdown = find.byKey(const ValueKey('proxy-type-dropdown'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('HTTP CONNECT').last);
    await tester.pumpAndSettle();

    final hostField = find.byKey(const ValueKey('proxy-host-field'));
    await tester.ensureVisible(hostField);
    await tester.enterText(hostField, 'proxy.local');
    await tester.enterText(
        find.byKey(const ValueKey('proxy-port-field')), '8080');

    final save = find.text('SAVE ONLY');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.proxyType, ProxyType.http);
    expect(saved!.proxyHost, 'proxy.local');
    expect(saved!.proxyPort, 8080);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/host_detail_panel_proxy_test.dart`
Expected: FAIL — no `proxy-type-dropdown` widget.

- [ ] **Step 3: Write minimal implementation**

In `app/lib/widgets/host_detail_panel.dart`:

(a) State + controllers — after the existing proxy-adjacent state (near `_osc52Clipboard`):
```dart
  ProxyType _proxyType = ProxyType.none;
  bool _obscureProxyPassword = true;
  late final TextEditingController _proxyHostCtrl;
  late final TextEditingController _proxyPortCtrl;
  late final TextEditingController _proxyUsernameCtrl;
  late final TextEditingController _proxyPasswordCtrl;
```
Add `import 'package:yourssh/models/proxy_settings.dart';` to the imports.

(b) Init (in `initState`, alongside the other controller initializers):
```dart
    _proxyType = h?.proxyType ?? ProxyType.none;
    _proxyHostCtrl = TextEditingController(text: h?.proxyHost ?? '');
    _proxyPortCtrl =
        TextEditingController(text: h?.proxyPort?.toString() ?? '');
    _proxyUsernameCtrl = TextEditingController(text: h?.proxyUsername ?? '');
    _proxyPasswordCtrl = TextEditingController();
```
In the async password-loading block that already loads the SSH password (around line 139), also load the proxy password:
```dart
    final proxyPw =
        await context.read<SshService>().loadProxyPassword(hostId);
    if (mounted && proxyPw != null && proxyPw.isNotEmpty &&
        _proxyPasswordCtrl.text.isEmpty) {
      setState(() => _proxyPasswordCtrl.text = proxyPw);
    }
```
(`hostId` is the existing host's id, already computed in that block.)

(c) dispose — add the four controllers to the existing dispose list:
```dart
    _proxyHostCtrl, _proxyPortCtrl, _proxyUsernameCtrl, _proxyPasswordCtrl,
```

(d) `_buildHost` (the `Host(...)` constructed for save/test — around lines 220-235): add after `agentForwarding: !_isRdp && _agentForwarding,` (and the `osc52Clipboard:` line):
```dart
      proxyType: _isRdp ? ProxyType.none : _proxyType,
      proxyHost: _isRdp || _proxyType == ProxyType.none
          ? null
          : _proxyHostCtrl.text.trim(),
      proxyPort: _isRdp || _proxyType == ProxyType.none
          ? null
          : int.tryParse(_proxyPortCtrl.text.trim()),
      proxyUsername: _isRdp || _proxyType == ProxyType.none
          ? null
          : (_proxyUsernameCtrl.text.trim().isEmpty
              ? null
              : _proxyUsernameCtrl.text.trim()),
```

(e) Persist the proxy password in `_save`, right after the host is built and before/after `await widget.onSave(host, _passwordCtrl.text);` (around line 257):
```dart
    await context.read<SshService>().saveProxyPassword(
        host.id,
        (_isRdp || _proxyType == ProxyType.none)
            ? ''
            : _proxyPasswordCtrl.text);
```
(empty string deletes the secret.)

(f) Extend `_PanelField` (class near line ~1266) to allow a key and a numeric keyboard — backward-compatible (existing callers pass neither):
```dart
class _PanelField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  const _PanelField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });
```
and in its `TextFormField`, add `keyboardType: keyboardType,` next to `controller:`.

(g) UI — add a PROXY section inside the SSH-only `if (!_isRdp) ...[` block (e.g. just after the CONNECTION CHAIN section, before SFTP MODE). Note `_PanelField` requires an `icon`; the obscured password uses the existing `_PasswordField` (`controller`/`obscure`/`onToggle`):
```dart
                  const SizedBox(height: 16),
                  _sectionLabel('PROXY'),
                  const SizedBox(height: 6),
                  _Card(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(children: [
                        const Text('Type',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 12),
                        DropdownButton<ProxyType>(
                          key: const ValueKey('proxy-type-dropdown'),
                          value: _proxyType,
                          dropdownColor: AppColors.surface,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                                value: ProxyType.none, child: Text('None')),
                            DropdownMenuItem(
                                value: ProxyType.http,
                                child: Text('HTTP CONNECT')),
                            DropdownMenuItem(
                                value: ProxyType.socks5, child: Text('SOCKS5')),
                          ],
                          onChanged: (v) =>
                              setState(() => _proxyType = v ?? ProxyType.none),
                        ),
                      ]),
                    ),
                    if (_proxyType != ProxyType.none) ...[
                      _PanelField(
                        key: const ValueKey('proxy-host-field'),
                        controller: _proxyHostCtrl,
                        hint: 'Proxy host',
                        icon: Icons.dns,
                      ),
                      _PanelField(
                        key: const ValueKey('proxy-port-field'),
                        controller: _proxyPortCtrl,
                        hint: 'Proxy port',
                        icon: Icons.numbers,
                        keyboardType: TextInputType.number,
                      ),
                      _PanelField(
                        controller: _proxyUsernameCtrl,
                        hint: 'Proxy username (optional)',
                        icon: Icons.person_outline,
                      ),
                      _PasswordField(
                        controller: _proxyPasswordCtrl,
                        obscure: _obscureProxyPassword,
                        onToggle: () => setState(
                            () => _obscureProxyPassword = !_obscureProxyPassword),
                      ),
                    ],
                  ]),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/host_detail_panel_proxy_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/thangnguyen/Projects/Personal/yourssh
git add app/lib/widgets/host_detail_panel.dart app/test/widgets/host_detail_panel_proxy_test.dart
git commit -m "feat(proxy): per-host PROXY section in the host panel"
```

---

### Task 8: Verify whole feature

**Files:** none (verification + wrap-up)

- [ ] **Step 1: Static analysis**

Run: `flutter analyze lib/models/proxy_settings.dart lib/services/proxy_handshake.dart lib/services/connection_proxy.dart lib/models/host.dart lib/services/ssh_service.dart lib/widgets/host_detail_panel.dart`
Expected: No issues found.

- [ ] **Step 2: Run the connection-proxy suite together**

Run:
```bash
flutter test \
  test/models/proxy_settings_test.dart \
  test/services/proxy_handshake_http_test.dart \
  test/services/proxy_handshake_socks5_test.dart \
  test/services/connection_proxy_test.dart \
  test/models/host_proxy_test.dart \
  test/services/ssh_service_proxy_test.dart \
  test/widgets/host_detail_panel_proxy_test.dart
```
Expected: all PASS.

- [ ] **Step 3: Regression — model + host panel suites**

Run:
```bash
flutter test test/models/ test/widgets/host_detail_panel_agent_forwarding_test.dart test/widgets/host_detail_panel_osc52_test.dart
```
Expected: PASS (the new Host fields and panel section must not break existing round-trip / panel tests).

- [ ] **Step 4: Manual smoke (optional, needs a proxy + SSH host)**

Run a local SOCKS5 proxy (e.g. `ssh -D 1080 somehost` or `microsocks`), set a host's proxy to SOCKS5 `127.0.0.1:1080`, connect, and confirm the session opens through the proxy. Repeat with an HTTP CONNECT proxy (e.g. `tinyproxy`).

- [ ] **Step 5: Final docs**

At release time, move the "Connection proxy support" bullet from P1 (Security & identity) to "Already shipped" in `docs/roadmap.md` with the shipping version, and add user-facing notes to `docs/wiki/`. (Defer version bump / CHANGELOG to the release checklist.)

---

## Self-review

**Spec coverage:**
- Both proxy types → Tasks 2 (HTTP) + 3 (SOCKS5). ✓
- Optional auth (HTTP Basic, SOCKS5 RFC 1929) → Task 2/3 tests assert headers/bytes. ✓
- Proxy password in secure storage (`proxy_pw_<id>`) → Task 6 helpers; Task 7 persists. ✓
- Local-originated scope (direct + hop0 + testConnection) → Task 6 wires lines 248/330/521. ✓
- SOCKS5 remote DNS (ATYP 0x03 domain) → Task 3 implementation + byte assertion. ✓
- Leftover preservation (no lost SSH banner bytes) → ByteReader/`_ProxiedSocket` + Task 2/4 tests. ✓
- Host fields + sync round-trip + unknown-type fallback → Task 5. ✓
- Panel section, SSH-only, password persistence → Task 7. ✓
- Error handling (non-200, SOCKS reply codes, auth fail, early close) → Tasks 2/3 tests + `ProxyException`. ✓

**Placeholder scan:** none — every code step has full code, including the `_PanelField` extension (verified against the real constructor: `controller`/`hint`/`icon` required) and the `_PasswordField` reuse for the obscured proxy password.

**Type consistency:** `ProxyType`/`ProxySettings`, `ProxyException`, `ByteReader` (`readExactly`/`readUntil`/`takeLeftover`/`release`/`destroy`), `httpConnectHandshake`/`socks5Handshake` (return `Future<Uint8List>`), `ConnectionProxy.connect` (named params `settings`/`targetHost`/`targetPort`/`timeout`), `SshService.directDialer`/`proxyDialer`/`localDial`/`loadProxyPassword`/`saveProxyPassword`, `Host.proxyType`/`proxyHost`/`proxyPort`/`proxyUsername` — consistent across Tasks 1-7. Panel save button text `SAVE ONLY` matches the existing harness. ✓
```
