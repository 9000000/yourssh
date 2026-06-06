import '../models/host.dart';
import '../theme/terminal_themes.dart';

/// Resolved terminal look for one session: per-host overrides falling back
/// to the global Settings → Terminal values.
class TerminalAppearance {
  final String themeName;
  final String fontFamily;
  final double fontSize;
  const TerminalAppearance({
    required this.themeName,
    required this.fontFamily,
    required this.fontSize,
  });
}

/// Per-host appearance overrides beat the globals; null host or null field
/// = global. An unknown per-host theme name (catalog drift across versions
/// via sync) falls back to the global theme rather than catalog[0].
TerminalAppearance resolveTerminalAppearance({
  required Host? host,
  required String globalTheme,
  required String globalFont,
  required double globalFontSize,
}) {
  final hostTheme = host?.terminalThemeId;
  final themeKnown =
      hostTheme != null && kTerminalThemeNames.contains(hostTheme);
  return TerminalAppearance(
    themeName: themeKnown ? hostTheme : globalTheme,
    fontFamily: host?.fontFamily ?? globalFont,
    fontSize: host?.fontSize ?? globalFontSize,
  );
}
