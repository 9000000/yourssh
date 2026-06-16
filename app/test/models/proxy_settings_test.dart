import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/proxy_settings.dart';

void main() {
  test('ProxyType has none/http/socks5', () {
    expect(ProxyType.values, [ProxyType.none, ProxyType.http, ProxyType.socks5]);
  });

  test('ProxySettings holds its fields', () {
    const s = ProxySettings(
        type: ProxyType.socks5, host: 'p', port: 1080, username: 'u', password: 'x');
    expect(s.type, ProxyType.socks5);
    expect(s.host, 'p');
    expect(s.port, 1080);
    expect(s.username, 'u');
    expect(s.password, 'x');
  });
}
