import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/services/network_stats_service.dart';

void main() {
  test('detectPrimaryInterface returns non-empty string from mock output', () {
    const output = '''
Inter-|   Receive
 face |bytes
    lo:    100
  eth0:  99999
''';
    final iface = NetworkStatsService.detectPrimaryInterface(output);
    expect(iface, 'eth0');
  });

  test('detectPrimaryInterface ignores loopback', () {
    const output = '    lo: 100\n';
    final iface = NetworkStatsService.detectPrimaryInterface(output);
    expect(iface, isNull);
  });
}
