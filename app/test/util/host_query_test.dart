import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/util/host_query.dart';

void main() {
  group('HostQuery.parse', () {
    test('empty / whitespace query is empty', () {
      expect(HostQuery.parse('').isEmpty, isTrue);
      expect(HostQuery.parse('   ').isEmpty, isTrue);
    });

    test('key:value token becomes a facet', () {
      final q = HostQuery.parse('env:prod');
      expect(q.facets, {'env': {'prod'}});
      expect(q.terms, isEmpty);
    });

    test('same key collects multiple values', () {
      final q = HostQuery.parse('env:prod env:staging');
      expect(q.facets, {'env': {'prod', 'staging'}});
    });

    test('plain token becomes a free-text term', () {
      final q = HostQuery.parse('web');
      expect(q.terms, ['web']);
      expect(q.facets, isEmpty);
    });

    test('malformed tokens demote to free-text', () {
      final q = HostQuery.parse('env: :prod');
      expect(q.facets, isEmpty);
      expect(q.terms, ['env:', ':prod']);
    });

    test('a:b:c splits on first colon', () {
      final q = HostQuery.parse('a:b:c');
      expect(q.facets, {'a': {'b:c'}});
    });

    test('parsing is case-insensitive (lower-cased)', () {
      final q = HostQuery.parse('Env:Prod WEB');
      expect(q.facets, {'env': {'prod'}});
      expect(q.terms, ['web']);
    });
  });
}
