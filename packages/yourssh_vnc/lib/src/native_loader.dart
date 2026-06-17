import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

/// Locates the yourssh_vnc dynamic library. Search order: bundled release
/// locations (relative to the running executable), plain name (rpath /
/// system lookup), then repo-relative dev paths.
ExternalLibrary loadYoursshVncLibrary() {
  Object? lastError;
  for (final path in _candidates()) {
    try {
      return ExternalLibrary.open(path);
    } catch (e) {
      lastError = e;
    }
  }
  throw StateError('yourssh_vnc native library not found: $lastError');
}

List<String> _candidates() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  if (Platform.isMacOS) {
    return [
      '${File(Platform.resolvedExecutable).parent.parent.path}/Frameworks/libyourssh_vnc.dylib',
      'libyourssh_vnc.dylib',
      '${Directory.current.path}/assets/native/macos/libyourssh_vnc.dylib',
      '${Directory.current.path}/packages/yourssh_vnc/assets/native/macos/libyourssh_vnc.dylib',
      '${Directory.current.path}/../packages/yourssh_vnc/assets/native/macos/libyourssh_vnc.dylib',
    ];
  }
  if (Platform.isLinux) {
    return [
      '$exeDir/lib/libyourssh_vnc.so',
      'libyourssh_vnc.so',
      '${Directory.current.path}/assets/native/linux/libyourssh_vnc.so',
      '${Directory.current.path}/packages/yourssh_vnc/assets/native/linux/libyourssh_vnc.so',
      '${Directory.current.path}/../packages/yourssh_vnc/assets/native/linux/libyourssh_vnc.so',
    ];
  }
  return [
    '$exeDir\\yourssh_vnc.dll',
    'yourssh_vnc.dll',
    '${Directory.current.path}\\assets\\native\\windows\\yourssh_vnc.dll',
    '${Directory.current.path}\\packages\\yourssh_vnc\\assets\\native\\windows\\yourssh_vnc.dll',
    '${Directory.current.path}\\..\\packages\\yourssh_vnc\\assets\\native\\windows\\yourssh_vnc.dll',
  ];
}
