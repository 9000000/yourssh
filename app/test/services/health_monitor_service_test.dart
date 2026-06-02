// app/test/services/health_monitor_service_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/session_health.dart';
import 'package:yourssh/services/health_monitor_service.dart';

void main() {
  group('HealthMonitorService.tick', () {
    test('maps measured latency per host to a status', () async {
      final latencies = <String, int?>{'a': 50, 'b': 300, 'c': 700, 'd': null};
      final monitor = HealthMonitorService(
        measure: (id) async => latencies[id],
        connectedHostIds: () => latencies.keys,
        pollSeconds: () => 10,
      );

      await monitor.tick();

      expect(monitor.healthFor('a').status, HealthStatus.healthy);
      expect(monitor.healthFor('b').status, HealthStatus.degraded);
      expect(monitor.healthFor('c').status, HealthStatus.down);
      expect(monitor.healthFor('d').status, HealthStatus.down);
    });

    test('unknown host is offline', () {
      final monitor = HealthMonitorService(
        measure: (id) async => 10,
        connectedHostIds: () => const <String>[],
        pollSeconds: () => 10,
      );
      expect(monitor.healthFor('ghost').status, HealthStatus.offline);
    });

    test('drops health for hosts no longer connected', () async {
      var ids = <String>['a'];
      final monitor = HealthMonitorService(
        measure: (id) async => 10,
        connectedHostIds: () => ids,
        pollSeconds: () => 10,
      );
      await monitor.tick();
      expect(monitor.healthFor('a').status, HealthStatus.healthy);

      ids = <String>[];
      await monitor.tick();
      expect(monitor.healthFor('a').status, HealthStatus.offline);
    });

    test('notifies listeners on each tick', () async {
      var notes = 0;
      final monitor = HealthMonitorService(
        measure: (id) async => 10,
        connectedHostIds: () => const ['a'],
        pollSeconds: () => 10,
      )..addListener(() => notes++);
      await monitor.tick();
      expect(notes, greaterThan(0));
    });

    test('does not re-probe a host whose previous probe is in flight', () async {
      var calls = 0;
      final gate = Completer<void>();
      final monitor = HealthMonitorService(
        measure: (id) async {
          calls++;
          await gate.future; // never completes during the test
          return 10;
        },
        connectedHostIds: () => const ['a'],
        pollSeconds: () => 10,
      );
      // Start two overlapping ticks without awaiting the first.
      final first = monitor.tick();
      await monitor.tick();
      expect(calls, 1);
      gate.complete();
      await first;
    });
  });
}
