import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/proxy_settings.dart';

void main() {
  group('Host proxy fields', () {
    test('defaults: none type, null host/port/username', () {
      final h = Host(label: 'a', host: 'h', username: 'u');
      expect(h.proxyType, ProxyType.none);
      expect(h.proxyHost, isNull);
      expect(h.proxyPort, isNull);
      expect(h.proxyUsername, isNull);
    });

    test('round-trips through toJson/fromJson', () {
      final h = Host(
          label: 'a',
          host: 'h',
          username: 'u',
          proxyType: ProxyType.http,
          proxyHost: 'proxy',
          proxyPort: 8080,
          proxyUsername: 'pu');
      final back = Host.fromJson(h.toJson());
      expect(back.proxyType, ProxyType.http);
      expect(back.proxyHost, 'proxy');
      expect(back.proxyPort, 8080);
      expect(back.proxyUsername, 'pu');
    });

    test('unknown proxyType string falls back to none', () {
      final json = Host(label: 'a', host: 'h', username: 'u').toJson()
        ..['proxyType'] = 'bogus';
      expect(Host.fromJson(json).proxyType, ProxyType.none);
    });

    test('copyWith overrides proxy fields', () {
      final h = Host(label: 'a', host: 'h', username: 'u');
      final c = h.copyWith(
          proxyType: ProxyType.socks5, proxyHost: 'p', proxyPort: 1080);
      expect(c.proxyType, ProxyType.socks5);
      expect(c.proxyHost, 'p');
      expect(c.proxyPort, 1080);
    });
  });
}
