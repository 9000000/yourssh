import '../models/host.dart';

/// Parsed representation of a hosts filter query.
///
/// Tokens containing a non-empty `key:value` pair (split on the first `:`)
/// become *facets*; everything else (including malformed tokens like `env:` or
/// `:prod`) becomes a free-text *term*. All text is lower-cased.
class HostQuery {
  final Map<String, Set<String>> facets;
  final List<String> terms;

  const HostQuery._(this.facets, this.terms);

  bool get isEmpty => facets.isEmpty && terms.isEmpty;

  factory HostQuery.parse(String raw) {
    final facets = <String, Set<String>>{};
    final terms = <String>[];
    for (final token in raw.toLowerCase().split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final colon = token.indexOf(':');
      if (colon > 0 && colon < token.length - 1) {
        final key = token.substring(0, colon);
        final value = token.substring(colon + 1);
        (facets[key] ??= <String>{}).add(value);
      } else {
        terms.add(token);
      }
    }
    return HostQuery._(facets, terms);
  }
}
