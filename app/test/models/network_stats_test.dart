// app/test/models/network_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/network_stats.dart';

void main() {
  group('NetworkStats.fromProcNetDev', () {
    const linuxOutput = '''
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 12345678       0    0    0    0     0          0         0 12345678       0    0    0    0     0       0          0
  eth0: 987654321   12345    0    0    0     0          0      1234 112233445   54321    0    0    0     0       0          0
''';

    test('parses eth0 rx and tx bytes', () {
      final stats = NetworkStats.fromProcNetDev(linuxOutput, interface: 'eth0');
      expect(stats.rxBytes, 987654321);
      expect(stats.txBytes, 112233445);
      expect(stats.interface, 'eth0');
    });

    test('returns zero stats when interface not found', () {
      final stats = NetworkStats.fromProcNetDev(linuxOutput, interface: 'wlan0');
      expect(stats.rxBytes, 0);
      expect(stats.txBytes, 0);
    });
  });

  group('NetworkStats.formatBytes', () {
    test('formats bytes correctly', () {
      expect(NetworkStats.formatBytes(512), '512 B/s');
      expect(NetworkStats.formatBytes(1536), '1.5 KB/s');
      expect(NetworkStats.formatBytes(1572864), '1.5 MB/s');
    });
  });

  group('NetworkStats.delta', () {
    test('computes per-second rates from two snapshots', () {
      final s1 = NetworkStats(interface: 'eth0', rxBytes: 1000, txBytes: 500, timestamp: DateTime(2024, 1, 1, 0, 0, 0));
      final s2 = NetworkStats(interface: 'eth0', rxBytes: 3000, txBytes: 1500, timestamp: DateTime(2024, 1, 1, 0, 0, 2));
      final delta = s2.delta(s1);
      expect(delta.rxBytesPerSec, 1000); // (3000-1000)/2s
      expect(delta.txBytesPerSec, 500);  // (1500-500)/2s
    });
  });
}
