# Connection Proxy Design

**Date:** 2026-06-14
**Feature:** Per-host HTTP CONNECT / SOCKS5 proxy for SSH connections on restricted networks
**Priority:** P1 (Security & identity)

---

## Goal

Let a host reach its SSH server through an outbound proxy, for networks where direct TCP to
the server is blocked but a corporate HTTP CONNECT or SOCKS5 proxy is available. This
complements — does not replace — the existing multi-hop jump chain: a proxy is how the local
machine makes its *first* outbound TCP connection; jump hops then tunnel over SSH as today.

Decisions (from brainstorming):
- **Both proxy types**: HTTP CONNECT and SOCKS5.
- **Optional auth**: HTTP Basic (`Proxy-Authorization`) and SOCKS5 username/password (RFC 1929);
  empty credentials → no-auth. Proxy password lives in secure storage, never in synced JSON.
- **Scope = local-originated dials**: the proxy on a host applies whenever that host's IP:port
  is dialed *directly from the local machine* — i.e. a direct connect to the target, or hop0
  (the first bastion) of a jump chain. Hops reached via `forwardLocal` (over a previous SSH
  hop) never use a proxy. `testConnection` uses the same path so it reflects reality.
- **SOCKS5 remote DNS**: the target hostname is sent as a domain address (ATYP `0x03`), so DNS
  resolves at the proxy — important when local DNS can't see internal names.

Out of scope: proxy for RDP (separate Rust engine), proxy chains (multiple proxies in series),
PAC / proxy auto-detect, SOCKS4.

---

## Key facts about the current code

`SshService` obtains the SSH transport as an `SSHSocket` (the public abstract class in the
dartssh2 fork, `packages/dartssh2/lib/src/socket/ssh_socket.dart`) in three local-originated
spots:
- `connect` direct: `socket = await SSHSocket.connect(host.host, host.port)` (`ssh_service.dart:248`).
- `dialHop` hop0: `over ?? await SSHSocket.connect(hop.host, hop.port)` — `over == null` means
  the first bastion, dialed from local (`ssh_service.dart:330`).
- `testConnection` direct: `SSHSocket.connect(host.host, host.port).timeout(...)` (`ssh_service.dart:521`).

`SSHClient` takes any `SSHSocket`. The fork's `_SSHNativeSocket` (private) simply wraps a
`dart:io Socket` (which is itself a `Stream<Uint8List>` + sink). So a proxied transport is just
another `SSHSocket` whose stream/sink ride a socket we connected to the proxy and handshook.

The app is desktop-only (`dart:io` always present); no web/`ssh_socket_js` concern.

---

## Architecture (app-side, no dartssh2 fork change)

### 1. `app/lib/models/proxy_settings.dart` (new)

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

### 2. `app/lib/services/proxy_handshake.dart` (new, pure)

Byte-level handshake logic, testable against in-memory stream/sink. Operates over a small
buffered byte reader (`ByteReader`, public so tests can construct it over a fake stream) so it
can read exactly the handshake bytes and return any over-read tail.

```dart
class ProxyException implements Exception {
  final String message;
  ProxyException(this.message);
  @override String toString() => 'ProxyException: $message';
}

/// Result of a successful handshake: bytes already read from the socket that
/// belong to the tunneled stream (e.g. the start of the SSH banner) and must
/// be re-emitted ahead of further socket data.
typedef HandshakeLeftover = Uint8List;

/// Performs the HTTP CONNECT handshake. Writes the CONNECT request (+ optional
/// Basic auth), reads response headers up to `\r\n\r\n`, requires a `200`
/// status. Throws [ProxyException] on any non-200 (e.g. 407/403) or malformed
/// response. Returns bytes read past the header terminator.
Future<HandshakeLeftover> httpConnectHandshake(
  _ByteReader reader,
  StreamSink<List<int>> sink, {
  required String targetHost,
  required int targetPort,
  String? username,
  String? password,
});

/// Performs the SOCKS5 handshake: greeting (no-auth + optional user/pass
/// methods), optional RFC 1929 auth, then a CONNECT request with the target as
/// a domain address (ATYP 0x03 → remote DNS). Throws [ProxyException] on a
/// non-zero reply (mapped to a human message) or auth failure. Returns any
/// over-read tail.
Future<HandshakeLeftover> socks5Handshake(
  _ByteReader reader,
  StreamSink<List<int>> sink, {
  required String targetHost,
  required int targetPort,
  String? username,
  String? password,
});
```

`ByteReader` is a small helper over the socket stream: `readExactly(n)` and
`readUntil(delimiter)` accumulate from the live subscription into a buffer; whatever remains
buffered when the handshake finishes is the leftover. (The reader keeps the single socket
subscription so no bytes are lost between handshake and tunneled traffic.) The handshake
functions take a `ByteReader` (not a private type) so the public API has no private-type leak.

HTTP request shape:
```
CONNECT host:port HTTP/1.1\r\n
Host: host:port\r\n
[Proxy-Authorization: Basic base64(user:pass)\r\n]
\r\n
```
SOCKS5 reply-code → message map: `0x01` general failure, `0x02` not allowed by ruleset, `0x03`
network unreachable, `0x04` host unreachable, `0x05` connection refused, `0x06` TTL expired,
`0x07` command not supported, `0x08` address type not supported.

### 3. `app/lib/services/connection_proxy.dart` (new)

```dart
class ConnectionProxy {
  /// Connects to [settings.host:port], runs the type-specific handshake to
  /// open a tunnel to [targetHost:targetPort], and returns an [SSHSocket]
  /// whose stream re-emits any handshake leftover before further socket data.
  static Future<SSHSocket> connect({
    required ProxySettings settings,
    required String targetHost,
    required int targetPort,
    Duration? timeout,
  });
}
```
Flow: `Socket.connect(settings.host, settings.port)` → build `ByteReader` over the socket → run
`httpConnectHandshake` or `socks5Handshake` → wrap as `_ProxiedSocket(socket, leftover)`. When
`timeout` is given it bounds the **whole** connect-plus-handshake (the returned future is
`.timeout(timeout)`-wrapped), not just the TCP connect. On any handshake error or timeout the
socket is destroyed before the exception propagates.

`_ProxiedSocket implements SSHSocket`: `stream` yields `leftover` (if non-empty) then the
socket stream; `sink`/`done`/`close`/`destroy` delegate to the socket.

### 4. `app/lib/models/host.dart`

Add (next to the existing flat fields):
- `ProxyType proxyType` (default `ProxyType.none`)
- `String? proxyHost`
- `int? proxyPort`
- `String? proxyUsername`

toJson/fromJson/copyWith for all four. `proxyType` serializes by `.name` and parses with a
safe fallback to `none`. The proxy **password is not** in JSON.

### 5. `StorageService`

Proxy password via the existing generic-secret helpers, key `proxy_pw_<hostId>`:
`saveGenericSecret('proxy_pw_$id', pw)` / `loadGenericSecret('proxy_pw_$id')` /
`deleteGenericSecret('proxy_pw_$id')` — same secure-first strategy as `pw_<hostId>`.

### 6. `app/lib/services/ssh_service.dart`

New private helper:
```dart
Future<SSHSocket> _localDial(Host host, {Duration? timeout}) async {
  if (host.proxyType == ProxyType.none) {
    return SSHSocket.connect(host.host, host.port, timeout: timeout);
  }
  final pw = await _storage.loadGenericSecret('proxy_pw_${host.id}');
  return ConnectionProxy.connect(
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
Replace the three local-originated dials:
- `connect`: `socket = await _localDial(host);` (line 248)
- `dialHop`: `over ?? await _localDial(hop)` (line 330)
- `testConnection`: `socket = await _localDial(host, timeout: const Duration(seconds: 10));`
  (line 521 — drop the now-redundant outer `.timeout`)

`_localDial` is `@visibleForTesting` with an injectable dialer seam so the proxy-vs-direct
branch is unit-testable without real sockets (a `ConnectionProxy.connect` function pointer,
defaulting to the real one).

### 7. `app/lib/widgets/host_detail_panel.dart`

A PROXY section inside the existing SSH-only (`!_isRdp`) block:
- `ProxyType` dropdown (None / HTTP CONNECT / SOCKS5).
- When not None: proxy host, port (numeric), username (optional), password (optional, obscured).
- `_save` writes `proxyType`/`proxyHost`/`proxyPort`/`proxyUsername` onto the Host and persists
  the password via `proxy_pw_<hostId>` (cleared when type is None or password emptied).

---

## Data flow

```
SshService._localDial(host)
  ├─ proxyType == none ─▶ SSHSocket.connect(target)                 (unchanged)
  └─ proxyType != none ─▶ Socket.connect(proxy)
                           └─▶ handshake (CONNECT / SOCKS5 + auth)
                                └─▶ _ProxiedSocket(socket, leftover) ─▶ SSHClient(socket, …)
```

---

## Error handling

- Proxy host unreachable / slow → `Socket.connect` error or `timeout` surfaces (error tab /
  testConnection result).
- HTTP non-200 (407 auth required, 403 forbidden, …) → `ProxyException('HTTP proxy refused: 407 …')`.
- SOCKS5 reply ≠ 0 or auth failure → `ProxyException` with the mapped reason.
- Any handshake failure destroys the proxy socket before rethrowing — no leaked sockets.
- Missing `proxyHost`/`proxyPort` while `proxyType != none` is prevented by the panel
  (validated) and guarded in `_localDial` (treated as a config error → `ProxyException`).

---

## Testing

**`test/services/proxy_handshake_test.dart`** (pure, fake stream/sink):
- HTTP: `200 Connection established` → success, leftover preserved when the response chunk
  carries trailing SSH bytes.
- HTTP: `407` → `ProxyException`; Basic header present and correctly base64-encoded when creds
  given; absent when not.
- HTTP: malformed status line → `ProxyException`.
- SOCKS5: no-auth path (server selects `0x00`) → CONNECT reply `0x00` success.
- SOCKS5: user/pass path (server selects `0x02`) → RFC 1929 auth `0x00` then success;
  auth status `0x01` → `ProxyException`.
- SOCKS5: CONNECT request encodes ATYP `0x03` domain + target host + port (assert bytes).
- SOCKS5: reply `0x05` → `ProxyException('connection refused')`.

**`test/services/connection_proxy_test.dart`**: `_ProxiedSocket` emits leftover ahead of socket
stream; `close`/`destroy` delegate. (Uses an in-memory socket pair / fake.)

**`test/models/host_proxy_test.dart`**: defaults (`ProxyType.none`, null fields); round-trip
through toJson/fromJson incl. unknown `proxyType` string → `none`; copyWith.

**`test/services/ssh_service_proxy_test.dart`**: `_localDial` with `proxyType == none` calls the
direct dialer; with `http`/`socks5` calls the injected `ConnectionProxy.connect` with the
resolved `ProxySettings` (host/port/user, password loaded from `proxy_pw_<id>`). Fake dialer +
mock StorageService secret.

**`test/widgets/host_detail_panel_proxy_test.dart`**: dropdown defaults None; selecting HTTP
reveals host/port/user/pass; saving round-trips `proxyType`/`proxyHost`/`proxyPort` onto the
saved Host.
