import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh_vnc/src/generated/frb_generated.dart';
import 'package:yourssh_vnc/src/generated/api.dart';
import 'package:yourssh_vnc/src/native_loader.dart';

void main() {
  setUpAll(() async {
    await RustLib.init(externalLibrary: loadYoursshVncLibrary());
  });

  test('vncLibVersion returns crate version', () async {
    expect(await vncLibVersion(), startsWith('yourssh_vnc 0.1.0'));
  });
}
