import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh_vnc/yourssh_vnc.dart';

void main() {
  // Before connect, _sessionId is null, so input methods must no-op (never
  // touch the bridge) — this runs without loading the native library.
  VncClient client() => VncClient(VncConfig(
      targetHost: '10.0.0.5', targetPort: 5900, username: 'u', password: ''));

  test('sendPointer is a no-op before connect', () {
    expect(() => client().sendPointer(x: 1, y: 2, buttonMask: 0x1),
        returnsNormally);
  });

  test('sendKey is a no-op before connect', () {
    expect(() => client().sendKey(keysym: 0xFF0D, down: true), returnsNormally);
  });

  test('sendClipboardText is a no-op before connect', () {
    expect(() => client().sendClipboardText('x'), returnsNormally);
  });
}
