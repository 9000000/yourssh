import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';

void main() {
  test('vnc default port is 5900', () {
    expect(HostProtocol.vnc.defaultPort, 5900);
  });

  test('vnc protocol round-trips through json', () {
    final h = Host(
      label: 'desktop',
      host: '10.0.0.5',
      port: 5900,
      username: 'u',
      protocol: HostProtocol.vnc,
    );
    final json = h.toJson();
    expect(json['protocol'], 'vnc');

    final back = Host.fromJson(json);
    expect(back.protocol, HostProtocol.vnc);
    expect(back.port, 5900);
  });

  test('unknown protocol still falls back to ssh', () {
    final back = Host.fromJson({
      'id': 'x',
      'label': 'l',
      'host': 'h',
      'port': 22,
      'username': 'u',
      'protocol': 'telnet',
    });
    expect(back.protocol, HostProtocol.ssh);
  });
}
