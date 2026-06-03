import 'package:yourssh/models/app_release.dart';

/// Network + platform glue for the in-app update flow.
/// Pure helpers (`isNewerVersion`, `assetForPlatform`) are unit-tested;
/// IO methods (`fetchLatestRelease`, `downloadAsset`, `launchInstaller`)
/// are added in later tasks.
class UpdateService {
  UpdateService();

  static final RegExp _versionSuffix = RegExp(r'[-+]');

  /// Returns true when [latest] is a strictly higher semantic version than
  /// [current]. Leading `v` and any `-pre`/`+build` suffix are ignored.
  /// Fails closed: unparseable [current] or [latest] never reports "newer"
  /// unless the parsed numbers genuinely differ.
  bool isNewerVersion(String current, String latest) {
    // Fail closed: an unknown/blank current version must never prompt an update.
    if (current.trim().isEmpty) return false;
    final a = _parse(current);
    final b = _parse(latest);
    for (var i = 0; i < 3; i++) {
      if (b[i] > a[i]) return true;
      if (b[i] < a[i]) return false;
    }
    return false;
  }

  /// Parses `major.minor.patch` into a 3-int list. Strips a leading `v` and
  /// drops anything from the first `-` or `+`. Missing/garbage segments -> 0.
  List<int> _parse(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final cut = s.indexOf(_versionSuffix);
    if (cut != -1) s = s.substring(0, cut);
    final parts = s.split('.');
    final out = <int>[0, 0, 0];
    for (var i = 0; i < 3 && i < parts.length; i++) {
      out[i] = int.tryParse(parts[i]) ?? 0;
    }
    return out;
  }

  /// Picks the best matching asset for [os] (`macos`/`windows`/`linux`) and
  /// [arch] (`arm64`/`x64`/`amd64`). Returns null when no artifact matches
  /// (e.g. macOS x64 — only arm64 is shipped); callers then fall back to the
  /// browser. For each platform the candidate names are tried in preference
  /// order and the first asset whose name matches is returned.
  ReleaseAsset? assetForPlatform(
    AppRelease release, {
    required String os,
    required String arch,
  }) {
    List<String> candidates() {
      switch (os) {
        case 'macos':
          return arch == 'arm64' ? const ['macOS-arm64.dmg'] : const [];
        case 'linux':
          return arch == 'arm64'
              ? const ['_arm64.deb', 'Linux-arm64.tar.gz']
              : const ['_amd64.deb', 'Linux-x86_64.tar.gz'];
        default:
          return const [];
      }
    }

    // Windows needs both an installer-vs-portable preference AND an arch match,
    // so handle it explicitly; other platforms match a single fragment.
    if (os == 'windows') {
      final archFrag = arch == 'arm64' ? 'arm64' : 'x64';
      // Preference: Setup (installer) first, then portable.
      for (final wantSetup in const [true, false]) {
        for (final a in release.assets) {
          final isSetup = a.name.contains('Setup.');
          if (a.name.contains(archFrag) &&
              a.name.endsWith('.exe') &&
              isSetup == wantSetup) {
            return a;
          }
        }
      }
      return null;
    }

    for (final frag in candidates()) {
      for (final a in release.assets) {
        if (a.name.contains(frag)) return a;
      }
    }
    return null;
  }
}
