import 'dart:async';

import 'generated/api.dart';
import 'generated/frb_generated.dart';
import 'native_loader.dart';

export 'generated/api.dart' show RdpConfig, RdpCertInfo, RdpEvent;

/// Lightweight typed facade over the generated FRB bindings.
///
/// Usage:
/// ```dart
/// await RdpClient.ensureInitialized();
/// final client = RdpClient(RdpConfig(...));
/// client.events.listen((event) { ... });
/// await client.connect();
/// client.sendKey(scancode: 0x1E, extended: false, down: true);
/// await client.disconnect();
/// await client.done;
/// ```
class RdpClient {
  final RdpConfig config;

  int? _sessionId;
  bool _disconnectRequested = false;
  StreamSubscription<RdpEvent>? _sub;
  final _eventCtrl = StreamController<RdpEvent>.broadcast();
  final _done = Completer<void>();

  RdpClient(this.config);

  static Future<void>? _initFuture;

  /// Initializes the Rust bridge exactly once (loads the native library on
  /// first use). Safe to call repeatedly and from concurrent callers; a
  /// failed attempt resets so the next call retries.
  static Future<void> ensureInitialized() {
    return _initFuture ??=
        RustLib.init(externalLibrary: loadYoursshRdpLibrary()).catchError((Object e) {
      _initFuture = null;
      throw e;
    });
  }

  /// Broadcast stream of all events emitted by the Rust session.
  Stream<RdpEvent> get events => _eventCtrl.stream;

  /// Completes when the session is fully torn down (after Disconnected or Error).
  Future<void> get done => _done.future;

  bool get isConnected => _sessionId != null;

  /// Start the RDP session. Returns the [RdpCertInfo] received in the
  /// first [RdpEvent.connected] event, or throws if the connection fails.
  Future<RdpCertInfo> connect() async {
    if (_sessionId != null) throw StateError('Already connected');
    await ensureInitialized();

    final certCompleter = Completer<RdpCertInfo>();

    _sub = rdpConnect(config: config).listen(
      (event) {
        switch (event) {
          case RdpEvent_Started(:final sessionId):
            _sessionId = sessionId;
            // disconnect() was called before the Started event arrived —
            // honor it now so the Rust session doesn't run orphaned.
            if (_disconnectRequested) {
              unawaited(rdpDisconnect(sessionId: sessionId));
            }

          case RdpEvent_Connected(:final cert):
            if (!certCompleter.isCompleted) {
              certCompleter.complete(cert);
            }

          case RdpEvent_Disconnected(:final reason):
            _finish(event, certCompleter, reason);
            return;

          case RdpEvent_Error(:final message):
            _finish(event, certCompleter, message);
            return;

          default:
            break;
        }
        _eventCtrl.add(event);
      },
      onError: (Object err) {
        _sessionId = null;
        if (!_done.isCompleted) _done.completeError(err);
        if (!certCompleter.isCompleted) certCompleter.completeError(err);
      },
      cancelOnError: false,
    );

    return certCompleter.future;
  }

  void _finish(RdpEvent event, Completer<RdpCertInfo> certCompleter, String reason) {
    _sessionId = null;
    _eventCtrl.add(event);
    _sub?.cancel();
    _sub = null;
    if (!_done.isCompleted) _done.complete();
    if (!certCompleter.isCompleted) {
      certCompleter.completeError(
        Exception(reason.isEmpty ? 'connection failed' : reason),
      );
    }
  }

  Future<void> disconnect() async {
    final id = _sessionId;
    if (id == null) {
      // Started not yet observed — flag the intent so the session is torn
      // down as soon as its id arrives (instead of orphaning the Rust loop).
      _disconnectRequested = true;
      return;
    }
    await rdpDisconnect(sessionId: id);
    await done;
  }

  void sendMouse({
    required int x,
    required int y,
    int button = 0,
    int action = 0,
  }) {
    final id = _sessionId;
    if (id == null) return;
    rdpSendMouse(sessionId: id, x: x, y: y, button: button, action: action);
  }

  void sendWheel({required int delta, bool horizontal = false}) {
    final id = _sessionId;
    if (id == null) return;
    rdpSendWheel(sessionId: id, delta: delta, horizontal: horizontal);
  }

  void sendKey({
    required int scancode,
    required bool extended,
    required bool down,
  }) {
    final id = _sessionId;
    if (id == null) return;
    rdpSendKey(sessionId: id, scancode: scancode, extended: extended, down: down);
  }

  void sendClipboardText(String text) {
    final id = _sessionId;
    if (id == null) return;
    rdpSendClipboardText(sessionId: id, text: text);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _eventCtrl.close();
  }
}
