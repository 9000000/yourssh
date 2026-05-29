// app/lib/services/pty_runner.dart
import 'dart:typed_data';
import 'package:flutter_pty/flutter_pty.dart';

abstract class PtyRunner {
  Stream<List<int>> get output;
  void write(Uint8List data);
  void resize(int rows, int cols);
  void kill();
  Future<int> get exitCode;
}

class FlutterPtyRunner implements PtyRunner {
  final Pty _pty;
  FlutterPtyRunner(this._pty);

  @override
  Stream<List<int>> get output => _pty.output.cast<List<int>>();

  @override
  void write(Uint8List data) => _pty.write(data);

  @override
  void resize(int rows, int cols) => _pty.resize(rows, cols);

  @override
  void kill() => _pty.kill();

  @override
  Future<int> get exitCode => _pty.exitCode;
}
