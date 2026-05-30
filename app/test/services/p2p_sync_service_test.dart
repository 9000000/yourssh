import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/services/p2p_sync_encryption.dart';
import 'package:yourssh/services/p2p_sync_service.dart';

void main() {
  group('P2PSyncService', () {
    late P2PSyncService service;

    setUp(() => service = P2PSyncService());
    tearDown(() => service.stop());

    test('startServer and fetchPayload roundtrip on localhost', () async {
      const payload = 'hello world';
      final url = await service.startServer(
        encryptedPayload: payload,
        hostAddress: '127.0.0.1',
      );
      expect(url, contains('127.0.0.1'));
      expect(url, contains('/sync'));
      final fetched = await service.fetchPayload(url);
      expect(fetched, payload);
    });

    test('server closes after first request', () async {
      const payload = 'data';
      final url = await service.startServer(
        encryptedPayload: payload,
        hostAddress: '127.0.0.1',
      );
      await service.fetchPayload(url);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        () => service.fetchPayload(url),
        throwsA(anything),
      );
    });

    test('getLocalInterfaces returns non-loopback addresses', () async {
      final ifaces = await service.getLocalInterfaces();
      for (final i in ifaces) {
        expect(i.address, isNot(startsWith('127.')));
      }
    });

    test('full encrypt-serve-fetch-decrypt roundtrip', () async {
      final key = P2PSyncEncryption.generateKey();
      const plaintext = '{"hosts":[],"passwords":{}}';
      final encrypted = await P2PSyncEncryption.encrypt(plaintext, key);

      final url = await service.startServer(
        encryptedPayload: encrypted,
        hostAddress: '127.0.0.1',
      );
      final fetched = await service.fetchPayload(url);
      final decrypted = await P2PSyncEncryption.decrypt(fetched, key);
      expect(decrypted, plaintext);
    });
  });
}
