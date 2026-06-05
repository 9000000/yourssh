import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';

void main() {
  Host base() => Host(
        label: 'srv',
        host: '1.2.3.4',
        username: 'u',
        authType: AuthType.privateKey,
        keyId: 'key-1',
      );

  group('Host.copyWith keyId sentinel', () {
    test('omitted keyId is preserved', () {
      expect(base().copyWith(label: 'x').keyId, 'key-1');
    });

    test('explicit null clears keyId (auth switched away from key)', () {
      expect(base().copyWith(keyId: null).keyId, isNull);
    });

    test('explicit value replaces keyId', () {
      expect(base().copyWith(keyId: 'key-2').keyId, 'key-2');
    });
  });
}
