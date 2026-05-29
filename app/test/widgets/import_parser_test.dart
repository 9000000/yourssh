import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/widgets/import_panel.dart';

void main() {
  group('parseSshConfig', () {
    test('parses a single Host block', () {
      const input = '''
Host myserver
    HostName 192.168.1.10
    User ubuntu
    Port 2222
''';
      final hosts = parseSshConfig(input);
      expect(hosts.length, 1);
      expect(hosts[0].label, 'myserver');
      expect(hosts[0].host, '192.168.1.10');
      expect(hosts[0].username, 'ubuntu');
      expect(hosts[0].port, 2222);
    });

    test('defaults User to root and Port to 22 when missing', () {
      const input = 'Host bare\n    HostName 10.0.0.1\n';
      final hosts = parseSshConfig(input);
      expect(hosts[0].username, 'root');
      expect(hosts[0].port, 22);
    });

    test('skips Host * wildcard blocks', () {
      const input = '''
Host *
    ServerAliveInterval 60

Host real
    HostName 1.2.3.4
    User admin
''';
      final hosts = parseSshConfig(input);
      expect(hosts.length, 1);
      expect(hosts[0].label, 'real');
    });

    test('parses multiple Host blocks', () {
      const input = '''
Host prod
    HostName prod.example.com
    User deploy

Host staging
    HostName staging.example.com
    User deploy
    Port 2022
''';
      final hosts = parseSshConfig(input);
      expect(hosts.length, 2);
      expect(hosts[1].label, 'staging');
      expect(hosts[1].port, 2022);
    });

    test('returns empty list for empty string', () {
      expect(parseSshConfig(''), isEmpty);
    });
  });

  group('parseJsonHosts', () {
    test('parses a JSON array of hosts', () {
      const input = '''[
  {"label":"Web","host":"web.example.com","port":22,"username":"admin",
   "authType":"password","group":"prod","tags":[]}
]''';
      final hosts = parseJsonHosts(input);
      expect(hosts.length, 1);
      expect(hosts[0].label, 'Web');
      expect(hosts[0].host, 'web.example.com');
      expect(hosts[0].group, 'prod');
    });

    test('assigns new ids (does not reuse imported ids)', () {
      const input = '''[
  {"id":"old-id-123","label":"A","host":"1.2.3.4","port":22,
   "username":"root","authType":"password","group":"","tags":[]}
]''';
      final hosts = parseJsonHosts(input);
      expect(hosts[0].id, isNot('old-id-123'));
    });

    test('returns empty list for invalid JSON', () {
      expect(parseJsonHosts('not json at all'), isEmpty);
    });

    test('returns empty list for empty input', () {
      expect(parseJsonHosts(''), isEmpty);
    });
  });

  group('detectAndParse', () {
    test('detects ssh config when input starts with "Host "', () {
      const input = 'Host server\n    HostName 1.2.3.4\n    User root\n';
      final result = detectAndParse(input);
      expect(result, isNotEmpty);
      expect(result[0].label, 'server');
    });

    test('detects JSON when input starts with [', () {
      const input =
          '[{"label":"X","host":"x.com","port":22,"username":"u","authType":"password","group":"","tags":[]}]';
      final result = detectAndParse(input);
      expect(result, isNotEmpty);
      expect(result[0].label, 'X');
    });

    test('returns empty list for unrecognized format', () {
      expect(detectAndParse('random garbage'), isEmpty);
    });
  });
}
