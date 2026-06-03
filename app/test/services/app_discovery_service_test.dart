// app/test/services/app_discovery_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/app_option.dart';
import 'package:yourssh/services/app_discovery_service.dart';

void main() {
  test('cache returns same list on second call without re-querying', () async {
    var queryCalls = 0;
    final service = AppDiscoveryService.withQuerier((_) async {
      queryCalls++;
      return [
        const AppOption(
            name: 'Test App',
            executablePath: '/usr/bin/test',
            isDefault: false),
      ];
    });

    final first = await service.getAppsFor('/tmp/foo.txt');
    final second = await service.getAppsFor('/tmp/bar.txt');

    expect(queryCalls, 1); // both .txt → same extension → cached
    expect(first, same(second));
    service.dispose();
  });

  test('cache is cleared on dispose', () async {
    var queryCalls = 0;
    final service = AppDiscoveryService.withQuerier((_) async {
      queryCalls++;
      return [];
    });

    await service.getAppsFor('/tmp/foo.txt');
    service.dispose();
    await service.getAppsFor('/tmp/foo.txt');

    expect(queryCalls, 2);
    service.dispose();
  });

  test('returns empty list when querier throws', () async {
    final service = AppDiscoveryService.withQuerier(
        (_) async => throw Exception('platform error'));

    final apps = await service.getAppsFor('/tmp/foo.txt');
    expect(apps, isEmpty);
    service.dispose();
  });
}
