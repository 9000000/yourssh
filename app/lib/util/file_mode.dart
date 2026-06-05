// app/lib/util/file_mode.dart
import 'dart:io';

/// POSIX permission-bit helpers shared by the permissions dialog and the
/// local/remote chmod paths. Only the low 12 bits (0o7777: rwx for
/// owner/group/others plus setuid/setgid/sticky) are considered.

/// Formats the permission bits of [mode] as an octal string, e.g. 0o755 ->
/// '755', 0o4755 -> '4755'. File-type bits (above 0o7777) are masked off.
String modeToOctal(int mode) =>
    (mode & 0xFFF).toRadixString(8).padLeft(3, '0');

/// Parses a 3- or 4-digit octal permission string ('644', '0755', '4755')
/// into permission bits. Returns null when [text] is not valid octal.
int? parseOctal(String text) {
  final t = text.trim();
  if (t.isEmpty || t.length > 4) return null;
  final value = int.tryParse(t, radix: 8);
  if (value == null || value < 0 || value > 0xFFF) return null;
  return value;
}

/// Applies [mode] to a local [path] via the system `chmod` (macOS/Linux
/// only — the caller hides the menu item on Windows).
Future<void> chmodLocal(String path, int mode,
    {bool recursive = false}) async {
  final result = await Process.run('chmod', [
    if (recursive) '-R',
    modeToOctal(mode),
    path,
  ]);
  if (result.exitCode != 0) {
    throw Exception('chmod failed: ${result.stderr}');
  }
}
