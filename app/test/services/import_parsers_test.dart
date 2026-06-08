import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/util/import_parsers.dart';

void main() {
  group('PuttyRegParser', () {
    const parser = PuttyRegParser();

    test('parses a single session', () {
      const input = '''Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\MyServer]
"HostName"="192.168.1.1"
"PortNumber"=dword:00000016
"UserName"="root"
''';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].label, 'MyServer');
      expect(result.hosts[0].host, '192.168.1.1');
      expect(result.hosts[0].port, 22);
      expect(result.hosts[0].username, 'root');
      expect(result.warnings, isEmpty);
    });

    test('URL-decodes session name (%20 → space)', () {
      const input = '''Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\My%20Server]
"HostName"="10.0.0.1"
"PortNumber"=dword:00000016
"UserName"="admin"
''';
      final result = parser.parse(input);
      expect(result.hosts[0].label, 'My Server');
    });

    test('skips sections outside Sessions path', () {
      const input = '''Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\SshHostKeys]
"rsa2@22:1.2.3.4"="0x..."
''';
      final result = parser.parse(input);
      expect(result.hosts, isEmpty);
    });

    test('session missing HostName produces a warning', () {
      const input = '''Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\BadSession]
"PortNumber"=dword:00000016
"UserName"="root"
''';
      final result = parser.parse(input);
      expect(result.hosts, isEmpty);
      expect(result.warnings.length, 1);
      expect(result.warnings[0], contains('BadSession'));
    });

    test('empty input returns empty result', () {
      final result = parser.parse('');
      expect(result.hosts, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('parses multiple sessions with correct hex port conversion', () {
      const input = '''Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\ServerA]
"HostName"="1.1.1.1"
"PortNumber"=dword:00000016
"UserName"="admin"

[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\ServerB]
"HostName"="2.2.2.2"
"PortNumber"=dword:0000006f
"UserName"="deploy"
''';
      final result = parser.parse(input);
      expect(result.hosts.length, 2);
      expect(result.hosts[0].label, 'ServerA');
      expect(result.hosts[1].label, 'ServerB');
      expect(result.hosts[1].port, 111);
    });
  });
}
