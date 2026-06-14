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
