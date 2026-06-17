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
  /// first use). Safe to call repeatedly and from concurrent callers; a
  /// failed attempt resets so the next call retries.
  static Future<void> ensureInitialized() {
    return _initFuture ??=
        RustLib.init(externalLibrary: loadYoursshVncLibrary()).catchError(
      (Object e) {
        _initFuture = null;
        throw e;
      },
    );
  }

  /// Broadcast stream of all events emitted by the Rust session.
  Stream<VncEvent> get events => _eventCtrl.stream;

  /// Completes when the session is fully torn down (after Disconnected or Error).
  Future<void> get done => _done.future;

  bool get isConnected => _sessionId != null;

  /// Start the VNC session. Returns when [VncEvent.connected] is received, or
  /// throws if the connection fails before a [VncEvent.connected] arrives.
  Future<void> connect() async {
    if (_sessionId != null) throw StateError('Already connected');
    await ensureInitialized();

    final connectedCompleter = Completer<void>();

    _sub = vncConnect(config: config).listen(
      (event) {
        switch (event) {
          case VncEvent_Started(:final sessionId):
            _sessionId = sessionId;
            // disconnect() was called before the Started event arrived —
            // honor it now so the Rust session doesn't run orphaned.
            if (_disconnectRequested) {
              unawaited(vncDisconnect(sessionId: sessionId));
            }

          case VncEvent_Connected():
            if (!connectedCompleter.isCompleted) {
              connectedCompleter.complete();
            }

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

  void _finish(
    VncEvent event,
    Completer<void> connectedCompleter,
    String reason,
  ) {
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
      if (_done.isCompleted) return; // already fully torn down
      // Started not yet observed — flag the intent so the session is torn
      // down as soon as its id arrives (instead of orphaning the Rust loop).
      _disconnectRequested = true;
      return;
    }
    await vncDisconnect(sessionId: id);
    await done;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    if (!_eventCtrl.isClosed) _eventCtrl.close();
  }
}
