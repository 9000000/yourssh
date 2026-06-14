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
