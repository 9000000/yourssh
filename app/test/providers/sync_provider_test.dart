import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourssh/providers/sync_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SyncProvider', () {
    late SyncProvider provider;

    setUp(() {
      provider = SyncProvider();
    });

    tearDown(() => provider.dispose());

    test('initial state: disabled, idle, no error', () {
      expect(provider.enabled, false);
      expect(provider.status, SyncStatus.idle);
      expect(provider.error, isNull);
      expect(provider.lastSynced, isNull);
    });

    test('setEnabled notifies listeners', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.setEnabled(true);
      expect(notified, true);
      expect(provider.enabled, true);
    });

    test('setStatus notifies listeners', () {
      var count = 0;
      provider.addListener(() => count++);
      provider.setStatus(SyncStatus.syncing);
      provider.setStatus(SyncStatus.synced);
      expect(count, 2);
    });

    test('setError stores error message and sets error status', () {
      provider.setError('network failure');
      expect(provider.status, SyncStatus.error);
      expect(provider.error, 'network failure');
    });

    test('setStatus(synced) clears error and sets lastSynced', () {
      provider.setError('old error');
      provider.setStatus(SyncStatus.synced);
      expect(provider.error, isNull);
      expect(provider.lastSynced, isNotNull);
    });
  });
}
