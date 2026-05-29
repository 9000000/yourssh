// app/lib/models/local_session.dart
import 'package:xterm/xterm.dart';
import 'package:uuid/uuid.dart';
import '../services/pty_runner.dart';

enum LocalSessionStatus { running, exited, error }

class LocalSession {
  final String id;
  final Terminal terminal;
  LocalSessionStatus status;
  String? errorMessage;
  PtyRunner? _pty;

  LocalSession({
    required this.terminal,
    this.status = LocalSessionStatus.running,
  }) : id = const Uuid().v4();

  void attachPty(PtyRunner pty) {
    _pty = pty;
  }

  void kill() {
    _pty?.kill();
    status = LocalSessionStatus.exited;
  }
}
