import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/services/share_session_service.dart';

void main() {
  group('generateShareCode', () {
    test('returns 6 characters', () {
      final code = ShareSessionService.generateShareCode();
      expect(code.length, 6);
    });

    test('contains only unambiguous uppercase alphanumeric chars', () {
      for (var i = 0; i < 20; i++) {
        final code = ShareSessionService.generateShareCode();
        expect(RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code), isTrue,
            reason: 'code "$code" contains unexpected chars');
      }
    });

    test('produces different codes on subsequent calls', () {
      final codes = List.generate(10, (_) => ShareSessionService.generateShareCode());
      expect(codes.toSet().length, greaterThan(1));
    });
  });

  group('output buffer', () {
    test('trims buffer when it exceeds max size', () {
      final svc = ShareSessionService.forTest();
      final chunk = 'x' * 10000;
      for (var i = 0; i < 60; i++) {
        svc.appendToBufferForTest(chunk);
      }
      expect(svc.bufferLengthForTest, lessThanOrEqualTo(ShareSessionService.maxBufferLength));
    });

    test('retains recent content after trim', () {
      final svc = ShareSessionService.forTest();
      final chunk = 'x' * 10000;
      for (var i = 0; i < 60; i++) {
        svc.appendToBufferForTest(chunk);
      }
      svc.appendToBufferForTest('MARKER');
      expect(svc.bufferSnapshotForTest, contains('MARKER'));
    });
  });
}
