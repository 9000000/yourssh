import 'dart:ui';

class KeywordHighlightRule {
  final RegExp pattern;
  final Color? foreground;
  final Color? background;

  const KeywordHighlightRule({
    required this.pattern,
    this.foreground,
    this.background,
  });
}
