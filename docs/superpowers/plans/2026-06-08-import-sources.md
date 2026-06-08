# Import Sources Expansion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 9-source import picker with dedicated parsers for PuTTY, MobaXterm, SecureCRT, Ansible, WinSCP, Termius, and SSH URI — plus a grid source-picker UI replacing the current format-agnostic import panel.

**Architecture:** Extract all parsers into `app/lib/util/import_parsers.dart` (no Flutter dep); add `ImportSource` enum, `ImportSourceDef` registry, and source-picker grid to `import_panel.dart`; keep all existing top-level functions (`parseSshConfig`, `parseJsonHosts`, `parseCsvHosts`, `detectAndParse`) unchanged for backward compatibility with existing tests.

**Tech Stack:** Flutter/Dart, `xml ^6.5.0` (already in pubspec at line 115), `file_picker` (already used)

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `app/lib/util/import_parsers.dart` | Create | `ParseResult`, `ImportParser` abstract class, 9 concrete parsers |
| `app/lib/widgets/import_panel.dart` | Modify | `ImportSource` enum, `ImportSourceDef` registry, source-picker grid; keep backward-compat exports |
| `app/test/services/import_parsers_test.dart` | Create | Unit tests for 7 new parsers (PuTTY, MobaXterm, SecureCRT, Ansible, WinSCP, Termius, SSH URI) |

---

### Task 1: Create `import_parsers.dart` + migrate SSH config & CSV parsers

**Files:**
- Create: `app/lib/util/import_parsers.dart`
- Modify: `app/lib/widgets/import_panel.dart`

- [ ] **Step 1: Create `app/lib/util/import_parsers.dart`**

```dart
import 'dart:convert';
import 'package:yourssh/models/host.dart';

typedef ParseResult = ({List<Host> hosts, List<String> warnings});

abstract class ImportParser {
  const ImportParser();
  ParseResult parse(String input);
}

// ── SSH Config ────────────────────────────────────────────

class SshConfigParser extends ImportParser {
  const SshConfigParser();

  @override
  ParseResult parse(String input) {
    final hosts = <Host>[];
    final blockRegex = RegExp(r'^Host\s+(.+)$', multiLine: true, caseSensitive: false);
    final matches = blockRegex.allMatches(input).toList();
    for (var i = 0; i < matches.length; i++) {
      final alias = matches[i].group(1)!.trim();
      if (alias == '*') continue;
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : input.length;
      final block = input.substring(start, end);
      String? hostname;
      String user = 'root';
      int port = 22;
      for (final line in block.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.toLowerCase().startsWith('hostname ')) {
          hostname = trimmed.substring('hostname '.length).trim();
        } else if (trimmed.toLowerCase().startsWith('user ')) {
          user = trimmed.substring('user '.length).trim();
        } else if (trimmed.toLowerCase().startsWith('port ')) {
          port = int.tryParse(trimmed.substring('port '.length).trim()) ?? 22;
        }
      }
      if (hostname == null) continue;
      hosts.add(Host(label: alias, host: hostname, port: port, username: user));
    }
    return (hosts: hosts, warnings: const []);
  }
}

// ── CSV ───────────────────────────────────────────────────

List<String> _splitCsvLine(String line) {
  final fields = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        sb.write('"');
        i += 2;
      } else {
        inQuotes = !inQuotes;
        i++;
      }
    } else if (ch == ',' && !inQuotes) {
      fields.add(sb.toString());
      sb.clear();
      i++;
    } else {
      sb.write(ch);
      i++;
    }
  }
  if (inQuotes) throw FormatException('Unterminated quote in CSV');
  fields.add(sb.toString());
  return fields;
}

class CsvParser extends ImportParser {
  const CsvParser();

  @override
  ParseResult parse(String input) {
    final lines = input.split('\n').map((l) => l.trimRight()).toList();
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    if (lines.isEmpty) return (hosts: [], warnings: []);

    final header =
        _splitCsvLine(lines[0]).map((h) => h.trim().toLowerCase()).toList();
    if (!header.contains('host')) {
      throw FormatException("CSV missing required 'host' column");
    }

    int idx(String name) => header.indexOf(name);
    final hostIdx = idx('host');
    final labelIdx = idx('label');
    final portIdx = idx('port');
    final userIdx = idx('username');
    final authIdx = idx('auth_type');
    final groupIdx = idx('group');
    final tagsIdx = idx('tags');

    final hosts = <Host>[];
    final warnings = <String>[];

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      List<String> cells;
      try {
        cells = _splitCsvLine(line);
      } catch (_) {
        warnings.add('Row ${i + 1}: malformed CSV, skipped');
        continue;
      }

      String cell(int colIdx) =>
          colIdx >= 0 && colIdx < cells.length ? cells[colIdx].trim() : '';

      final hostVal = cell(hostIdx);
      if (hostVal.isEmpty) {
        warnings.add('Row ${i + 1}: missing host, skipped');
        continue;
      }

      int port = 22;
      final portStr = cell(portIdx);
      if (portStr.isNotEmpty) {
        final parsed = int.tryParse(portStr);
        if (parsed == null || parsed < 1 || parsed > 65535) {
          warnings.add("Row ${i + 1}: invalid port '$portStr', skipped");
          continue;
        }
        port = parsed;
      }

      final labelVal = cell(labelIdx);
      final authVal = cell(authIdx).toLowerCase();
      final tagsVal = cell(tagsIdx);

      final authType = switch (authVal) {
        'key' || 'privatekey' => AuthType.privateKey,
        'agent' => AuthType.agent,
        _ => AuthType.password,
      };

      final tags = tagsVal.isEmpty
          ? <String>[]
          : tagsVal
              .split(';')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();

      hosts.add(Host(
        label: labelVal.isEmpty ? hostVal : labelVal,
        host: hostVal,
        port: port,
        username: cell(userIdx),
        authType: authType,
        group: cell(groupIdx),
        tags: tags,
      ));
    }

    return (hosts: hosts, warnings: warnings);
  }
}
```

- [ ] **Step 2: Update `import_panel.dart` — delegate to new parsers, keep exports**

Add at the top of `app/lib/widgets/import_panel.dart` (after existing imports):
```dart
import '../util/import_parsers.dart';
```

Replace `parseSshConfig` (lines 11–38) with:
```dart
List<Host> parseSshConfig(String input) =>
    const SshConfigParser().parse(input).hosts;
```

Remove `_splitCsvLine` (lines 67–94) entirely — it now lives in `import_parsers.dart`.

Replace `parseCsvHosts` (lines 96–176) with:
```dart
({List<Host> hosts, List<String> warnings}) parseCsvHosts(String input) =>
    const CsvParser().parse(input);
```

Leave `parseJsonHosts` and `detectAndParse` unchanged.

- [ ] **Step 3: Run existing tests to verify no regressions**

```bash
cd app && flutter test test/widgets/import_parser_test.dart -v
```

Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add app/lib/util/import_parsers.dart app/lib/widgets/import_panel.dart
git commit -m "refactor(import): extract SshConfigParser + CsvParser into import_parsers.dart"
```

---

### Task 2: PuTTY parser (TDD)

**Files:**
- Create: `app/test/services/import_parsers_test.dart`
- Modify: `app/lib/util/import_parsers.dart`

- [ ] **Step 1: Create test file with PuTTY tests**

Create `app/test/services/import_parsers_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/services/import_parsers_test.dart -v
```

Expected: FAIL — `PuttyRegParser` undefined.

- [ ] **Step 3: Implement `PuttyRegParser` in `import_parsers.dart`**

Add after `CsvParser`:

```dart
// ── PuTTY Registry Export ─────────────────────────────────

class PuttyRegParser extends ImportParser {
  const PuttyRegParser();

  static final _sectionRe = RegExp(
    r'^\[HKEY_[^\]]*\\Sessions\\([^\]]+)\]',
    multiLine: true,
    caseSensitive: false,
  );
  static final _hostRe =
      RegExp(r'^"HostName"="([^"]*)"', multiLine: true);
  static final _portRe =
      RegExp(r'^"PortNumber"=dword:([0-9a-fA-F]+)', multiLine: true);
  static final _userRe =
      RegExp(r'^"UserName"="([^"]*)"', multiLine: true);

  @override
  ParseResult parse(String input) {
    var text = input;
    if (text.startsWith('﻿')) text = text.substring(1); // strip UTF-16 BOM

    final hosts = <Host>[];
    final warnings = <String>[];
    final sections = _sectionRe.allMatches(text).toList();

    for (var i = 0; i < sections.length; i++) {
      final rawName = sections[i].group(1)!;
      final name = Uri.decodeComponent(rawName.replaceAll('+', ' '));
      final start = sections[i].end;
      final end =
          i + 1 < sections.length ? sections[i + 1].start : text.length;
      final block = text.substring(start, end);

      final hostname = _hostRe.firstMatch(block)?.group(1);
      if (hostname == null || hostname.isEmpty) {
        warnings.add('Session "$name": missing HostName, skipped');
        continue;
      }
      final portHex = _portRe.firstMatch(block)?.group(1) ?? '16';
      final port = int.tryParse(portHex, radix: 16) ?? 22;
      final user = _userRe.firstMatch(block)?.group(1) ?? 'root';

      hosts.add(Host(label: name, host: hostname, port: port, username: user));
    }

    return (hosts: hosts, warnings: warnings);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "PuttyRegParser" -v
```

Expected: All PuTTY tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/util/import_parsers.dart app/test/services/import_parsers_test.dart
git commit -m "feat(import): PuTTY .reg parser"
```

---

### Task 3: MobaXterm parser (TDD)

**Files:**
- Modify: `app/test/services/import_parsers_test.dart`
- Modify: `app/lib/util/import_parsers.dart`

- [ ] **Step 1: Add MobaXterm tests to the test file**

Add after the `PuttyRegParser` group in `app/test/services/import_parsers_test.dart`:

```dart
  group('MobaXtermParser', () {
    const parser = MobaXtermParser();

    test('parses a single SSH session', () {
      const input = '[Bookmarks]\n'
          'SubRep=\n'
          'ImgNum=42\n'
          'SSH server1 (root) = 0  192.168.1.1  22  root  -1  -1  0\n';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].label, 'SSH server1 (root)');
      expect(result.hosts[0].host, '192.168.1.1');
      expect(result.hosts[0].port, 22);
      expect(result.hosts[0].username, 'root');
      expect(result.warnings, isEmpty);
    });

    test('skips non-SSH sessions (type != 0)', () {
      const input = '[Bookmarks]\n'
          'Telnet server = 4  10.0.0.1  23  admin  -1\n'
          'SSH server = 0  10.0.0.2  22  root  -1\n';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].host, '10.0.0.2');
    });

    test('parses sessions across multiple [Bookmarks] sections', () {
      const input = '[Bookmarks]\n'
          'Server A = 0  1.1.1.1  22  admin  -1\n'
          '\n'
          '[Bookmarks_1]\n'
          'SubRep=DB\n'
          'Server B = 0  2.2.2.2  2222  deploy  -1\n';
      final result = parser.parse(input);
      expect(result.hosts.length, 2);
      expect(result.hosts[1].port, 2222);
    });

    test('malformed SSH line (< 4 tokens in value) produces a warning', () {
      const input = '[Bookmarks]\nBad = 0  10.0.0.1\n';
      final result = parser.parse(input);
      expect(result.hosts, isEmpty);
      expect(result.warnings.length, 1);
      expect(result.warnings[0], contains('Bad'));
    });

    test('empty input returns empty result', () {
      final result = parser.parse('');
      expect(result.hosts, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "MobaXtermParser" -v
```

Expected: FAIL — `MobaXtermParser` undefined.

- [ ] **Step 3: Implement `MobaXtermParser` in `import_parsers.dart`**

Add after `PuttyRegParser`:

```dart
// ── MobaXterm ─────────────────────────────────────────────

class MobaXtermParser extends ImportParser {
  const MobaXtermParser();

  @override
  ParseResult parse(String input) {
    final hosts = <Host>[];
    final warnings = <String>[];

    for (final raw in input.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('[')) continue;

      final eqIdx = line.indexOf('=');
      if (eqIdx < 0) continue;

      final label = line.substring(0, eqIdx).trim();
      if (label == 'SubRep' || label == 'ImgNum') continue;

      final valuePart = line.substring(eqIdx + 1).trim();
      final tokens = valuePart
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();

      if (tokens.isEmpty || tokens[0] != '0') continue; // SSH only

      if (tokens.length < 4) {
        warnings.add('Session "$label": malformed line, skipped');
        continue;
      }

      final host = tokens[1];
      final port = int.tryParse(tokens[2]) ?? 22;
      final user = tokens[3];

      if (host.isEmpty) {
        warnings.add('Session "$label": missing host, skipped');
        continue;
      }

      hosts.add(Host(label: label, host: host, port: port, username: user));
    }

    return (hosts: hosts, warnings: warnings);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "MobaXtermParser" -v
```

Expected: All MobaXterm tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/util/import_parsers.dart app/test/services/import_parsers_test.dart
git commit -m "feat(import): MobaXterm .mxtsessions parser"
```

---

### Task 4: SecureCRT parser (TDD)

**Files:**
- Modify: `app/test/services/import_parsers_test.dart`
- Modify: `app/lib/util/import_parsers.dart`

- [ ] **Step 1: Add SecureCRT tests**

Add after the `MobaXtermParser` group:

```dart
  group('SecureCrtParser', () {
    const parser = SecureCrtParser();

    test('parses a single session', () {
      const input = '''<?xml version="1.0" encoding="UTF-8"?>
<VanDyke>
  <key name="Sessions">
    <key name="MyServer">
      <value name="Hostname" type="string">192.168.1.1</value>
      <value name="Port" type="dword">22</value>
      <value name="Username" type="string">admin</value>
    </key>
  </key>
</VanDyke>
''';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].label, 'MyServer');
      expect(result.hosts[0].host, '192.168.1.1');
      expect(result.hosts[0].port, 22);
      expect(result.hosts[0].username, 'admin');
      expect(result.warnings, isEmpty);
    });

    test('nested folder becomes group', () {
      const input = '''<?xml version="1.0" encoding="UTF-8"?>
<VanDyke>
  <key name="Sessions">
    <key name="Production">
      <key name="WebServer">
        <value name="Hostname" type="string">prod.example.com</value>
        <value name="Port" type="dword">22</value>
        <value name="Username" type="string">deploy</value>
      </key>
    </key>
  </key>
</VanDyke>
''';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].label, 'WebServer');
      expect(result.hosts[0].group, 'Production');
    });

    test('session missing Hostname is skipped silently', () {
      const input = '''<?xml version="1.0" encoding="UTF-8"?>
<VanDyke>
  <key name="Sessions">
    <key name="NoHost">
      <value name="Port" type="dword">22</value>
    </key>
  </key>
</VanDyke>
''';
      final result = parser.parse(input);
      expect(result.hosts, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('invalid XML returns a warning', () {
      final result = parser.parse('not xml at all');
      expect(result.hosts, isEmpty);
      expect(result.warnings.length, 1);
      expect(result.warnings[0], contains('XML'));
    });

    test('empty input returns empty result', () {
      final result = parser.parse('');
      expect(result.hosts, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "SecureCrtParser" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `SecureCrtParser` in `import_parsers.dart`**

Add the import at the top of the file (after existing imports):
```dart
import 'package:xml/xml.dart' show XmlDocument, XmlElement, XmlException;
```

Add after `MobaXtermParser`:

```dart
// ── SecureCRT XML ─────────────────────────────────────────

class SecureCrtParser extends ImportParser {
  const SecureCrtParser();

  @override
  ParseResult parse(String input) {
    if (input.trim().isEmpty) return (hosts: [], warnings: []);

    XmlDocument doc;
    try {
      doc = XmlDocument.parse(input);
    } on XmlException catch (e) {
      return (hosts: [], warnings: ['Invalid XML: ${e.message}']);
    }

    final sessionsKey = doc
        .findAllElements('key')
        .where((e) => e.getAttribute('name') == 'Sessions')
        .firstOrNull;
    if (sessionsKey == null) {
      return (hosts: [], warnings: ['No Sessions key found in XML']);
    }

    final hosts = <Host>[];
    _walkKeys(sessionsKey, '', hosts);
    return (hosts: hosts, warnings: []);
  }

  void _walkKeys(XmlElement parent, String groupPath, List<Host> hosts) {
    for (final child in parent.childElements) {
      if (child.name.local != 'key') continue;
      final name = child.getAttribute('name') ?? '';

      final hostnameEl = child.childElements
          .where((e) =>
              e.name.local == 'value' &&
              e.getAttribute('name') == 'Hostname')
          .firstOrNull;

      if (hostnameEl != null) {
        final hostname = hostnameEl.innerText.trim();
        if (hostname.isEmpty) continue;

        final portEl = child.childElements
            .where((e) =>
                e.name.local == 'value' && e.getAttribute('name') == 'Port')
            .firstOrNull;
        final port = int.tryParse(portEl?.innerText.trim() ?? '') ?? 22;

        final userEl = child.childElements
            .where((e) =>
                e.name.local == 'value' &&
                e.getAttribute('name') == 'Username')
            .firstOrNull;
        final user = userEl?.innerText.trim() ?? '';

        hosts.add(Host(
          label: name,
          host: hostname,
          port: port,
          username: user,
          group: groupPath,
        ));
      } else {
        final newPath =
            groupPath.isEmpty ? name : '$groupPath/$name';
        _walkKeys(child, newPath, hosts);
      }
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "SecureCrtParser" -v
```

Expected: All SecureCRT tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/util/import_parsers.dart app/test/services/import_parsers_test.dart
git commit -m "feat(import): SecureCRT XML parser"
```

---

### Task 5: Ansible INI parser (TDD)

**Files:**
- Modify: `app/test/services/import_parsers_test.dart`
- Modify: `app/lib/util/import_parsers.dart`

- [ ] **Step 1: Add Ansible tests**

Add after the `SecureCrtParser` group:

```dart
  group('AnsibleParser', () {
    const parser = AnsibleParser();

    test('parses bare hostname in a group', () {
      const input = '[webservers]\nweb1.example.com\n';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].host, 'web1.example.com');
      expect(result.hosts[0].label, 'web1.example.com');
      expect(result.hosts[0].group, 'webservers');
      expect(result.hosts[0].port, 22);
      expect(result.hosts[0].username, 'root');
    });

    test('ansible_host overrides bare hostname', () {
      const input =
          '[db]\ndb-alias ansible_host=10.0.0.5 ansible_user=postgres ansible_port=5432\n';
      final result = parser.parse(input);
      expect(result.hosts[0].host, '10.0.0.5');
      expect(result.hosts[0].label, 'db-alias');
      expect(result.hosts[0].username, 'postgres');
      expect(result.hosts[0].port, 5432);
    });

    test('ansible_ssh_user is accepted as username alias', () {
      const input = '[servers]\nmyhost ansible_ssh_user=ubuntu\n';
      final result = parser.parse(input);
      expect(result.hosts[0].username, 'ubuntu');
    });

    test('skips :vars sections entirely', () {
      const input =
          '[webservers:vars]\nansible_user=deploy\n\n[webservers]\nweb1.example.com\n';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].host, 'web1.example.com');
    });

    test('skips :children sections entirely', () {
      const input = '[all:children]\nwebservers\ndatabases\n';
      final result = parser.parse(input);
      expect(result.hosts, isEmpty);
    });

    test('skips comment lines', () {
      const input = '[servers]\n# this is a comment\nreal-server.com\n';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].host, 'real-server.com');
    });

    test('invalid ansible_port produces a warning and skips the host', () {
      const input = '[servers]\nbad-server ansible_port=notanumber\n';
      final result = parser.parse(input);
      expect(result.hosts, isEmpty);
      expect(result.warnings.length, 1);
      expect(result.warnings[0], contains('ansible_port'));
    });

    test('empty input returns empty result', () {
      final result = parser.parse('');
      expect(result.hosts, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "AnsibleParser" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `AnsibleParser` in `import_parsers.dart`**

Add after `SecureCrtParser`:

```dart
// ── Ansible INI Inventory ─────────────────────────────────

class AnsibleParser extends ImportParser {
  const AnsibleParser();

  static final _sectionRe = RegExp(r'^\[(.+)\]$');
  static final _varRe = RegExp(r'(\S+)=(\S+)');

  @override
  ParseResult parse(String input) {
    final hosts = <Host>[];
    final warnings = <String>[];
    String currentGroup = '';
    bool skipSection = false;

    for (final raw in input.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final sectionMatch = _sectionRe.firstMatch(line);
      if (sectionMatch != null) {
        final sectionName = sectionMatch.group(1)!;
        skipSection =
            sectionName.contains(':vars') || sectionName.contains(':children');
        if (!skipSection) currentGroup = sectionName.split(':').first;
        continue;
      }

      if (skipSection) continue;

      final tokens = line.split(RegExp(r'\s+'));
      final alias = tokens[0];
      final vars = <String, String>{};
      for (final token in tokens.skip(1)) {
        final m = _varRe.firstMatch(token);
        if (m != null) vars[m.group(1)!] = m.group(2)!;
      }

      final hostname = vars['ansible_host'] ?? alias;
      final userVal =
          vars['ansible_user'] ?? vars['ansible_ssh_user'] ?? 'root';

      int port = 22;
      final portStr = vars['ansible_port'];
      if (portStr != null) {
        final parsed = int.tryParse(portStr);
        if (parsed == null || parsed < 1 || parsed > 65535) {
          warnings.add(
              'Host "$alias": invalid ansible_port "$portStr", skipped');
          continue;
        }
        port = parsed;
      }

      hosts.add(Host(
        label: alias,
        host: hostname,
        port: port,
        username: userVal,
        group: currentGroup,
      ));
    }

    return (hosts: hosts, warnings: warnings);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "AnsibleParser" -v
```

Expected: All Ansible tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/util/import_parsers.dart app/test/services/import_parsers_test.dart
git commit -m "feat(import): Ansible INI inventory parser"
```

---

### Task 6: WinSCP parser (TDD)

**Files:**
- Modify: `app/test/services/import_parsers_test.dart`
- Modify: `app/lib/util/import_parsers.dart`

- [ ] **Step 1: Add WinSCP tests**

Add after the `AnsibleParser` group:

```dart
  group('WinScpParser', () {
    const parser = WinScpParser();

    test('parses a single session', () {
      const input = '[Sessions\\MyServer]\nHostName=192.168.1.1\nPortNumber=22\nUserName=admin\n';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].label, 'MyServer');
      expect(result.hosts[0].host, '192.168.1.1');
      expect(result.hosts[0].port, 22);
      expect(result.hosts[0].username, 'admin');
      expect(result.warnings, isEmpty);
    });

    test('URL-decodes session name', () {
      const input =
          '[Sessions\\My%20Server]\nHostName=10.0.0.1\nPortNumber=22\nUserName=root\n';
      final result = parser.parse(input);
      expect(result.hosts[0].label, 'My Server');
    });

    test('skips root [Sessions\\] section', () {
      const input = '[Sessions\\]\nHostName=ignored.example.com\n';
      final result = parser.parse(input);
      expect(result.hosts, isEmpty);
    });

    test('nested path: last component is label, parent components join as group', () {
      const input =
          '[Sessions\\Production\\WebServer]\nHostName=prod.example.com\nPortNumber=22\nUserName=deploy\n';
      final result = parser.parse(input);
      expect(result.hosts[0].label, 'WebServer');
      expect(result.hosts[0].group, 'Production');
    });

    test('session missing HostName is skipped silently', () {
      const input = '[Sessions\\NoHost]\nPortNumber=22\nUserName=admin\n';
      final result = parser.parse(input);
      expect(result.hosts, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('empty input returns empty result', () {
      final result = parser.parse('');
      expect(result.hosts, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "WinScpParser" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `WinScpParser` in `import_parsers.dart`**

Add after `AnsibleParser`:

```dart
// ── WinSCP INI ────────────────────────────────────────────

class WinScpParser extends ImportParser {
  const WinScpParser();

  // Matches [Sessions\path] — backslash escaped in the INI file
  static final _sectionRe = RegExp(r'^\[Sessions\\(.+)\]$');

  @override
  ParseResult parse(String input) {
    final hosts = <Host>[];
    String? currentPath;
    String? hostname;
    int port = 22;
    String username = '';

    void flush() {
      if (currentPath == null) return;
      if (hostname == null || hostname!.isEmpty) {
        currentPath = null;
        hostname = null;
        port = 22;
        username = '';
        return;
      }
      final parts = currentPath!.split(r'\');
      final label =
          Uri.decodeComponent(parts.last.replaceAll('+', ' '));
      final groupParts = parts.sublist(0, parts.length - 1);
      final group = groupParts
          .map((p) => Uri.decodeComponent(p.replaceAll('+', ' ')))
          .join('/');
      hosts.add(Host(
        label: label,
        host: hostname!,
        port: port,
        username: username,
        group: group,
      ));
      currentPath = null;
      hostname = null;
      port = 22;
      username = '';
    }

    for (final raw in input.split('\n')) {
      final line = raw.trim();
      final sectionMatch = _sectionRe.firstMatch(line);
      if (sectionMatch != null) {
        flush();
        final path = sectionMatch.group(1)!;
        // Skip the root [Sessions\] section (empty path or just backslash)
        currentPath = (path.isEmpty || path == r'\') ? null : path;
        continue;
      }
      if (currentPath == null) continue;

      if (line.startsWith('HostName=')) {
        hostname = line.substring('HostName='.length).trim();
      } else if (line.startsWith('PortNumber=')) {
        port = int.tryParse(line.substring('PortNumber='.length).trim()) ?? 22;
      } else if (line.startsWith('UserName=')) {
        username = line.substring('UserName='.length).trim();
      }
    }
    flush();

    return (hosts: hosts, warnings: []);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "WinScpParser" -v
```

Expected: All WinSCP tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/util/import_parsers.dart app/test/services/import_parsers_test.dart
git commit -m "feat(import): WinSCP .ini parser"
```

---

### Task 7: Termius parser (TDD)

**Files:**
- Modify: `app/test/services/import_parsers_test.dart`
- Modify: `app/lib/util/import_parsers.dart`

- [ ] **Step 1: Add Termius tests**

Add after the `WinScpParser` group:

```dart
  group('TermiusParser', () {
    const parser = TermiusParser();

    test('parses Termius JSON export format', () {
      const input = '{"hosts":['
          '{"label":"My Server","address":"192.168.1.1","port":22,'
          '"username":"admin","group":{"label":"Production"}}'
          ']}';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].label, 'My Server');
      expect(result.hosts[0].host, '192.168.1.1');
      expect(result.hosts[0].port, 22);
      expect(result.hosts[0].username, 'admin');
      expect(result.hosts[0].group, 'Production');
      expect(result.warnings, isEmpty);
    });

    test('skips entries missing address', () {
      const input = '{"hosts":[{"label":"Bad","port":22,"username":"root"}]}';
      final result = parser.parse(input);
      expect(result.hosts, isEmpty);
    });

    test('host without group has empty group', () {
      const input =
          '{"hosts":[{"label":"X","address":"10.0.0.1","port":22,"username":"root"}]}';
      final result = parser.parse(input);
      expect(result.hosts[0].group, '');
    });

    test('falls back to YourSSH JSON array format when no hosts key', () {
      const input =
          '[{"label":"Web","host":"web.example.com","port":22,"username":"admin",'
          '"authType":"password","group":"","tags":[]}]';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].label, 'Web');
    });

    test('invalid JSON returns a warning', () {
      final result = parser.parse('not json');
      expect(result.hosts, isEmpty);
      expect(result.warnings.length, 1);
    });

    test('empty input returns empty result', () {
      final result = parser.parse('');
      expect(result.hosts, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "TermiusParser" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `TermiusParser` in `import_parsers.dart`**

Add after `WinScpParser`:

```dart
// ── Termius JSON ──────────────────────────────────────────

class TermiusParser extends ImportParser {
  const TermiusParser();

  @override
  ParseResult parse(String input) {
    if (input.trim().isEmpty) return (hosts: [], warnings: []);

    dynamic decoded;
    try {
      decoded = jsonDecode(input);
    } catch (_) {
      return (hosts: [], warnings: ['Invalid JSON']);
    }

    if (decoded is Map && decoded.containsKey('hosts')) {
      final list = decoded['hosts'];
      if (list is! List) {
        return (hosts: [], warnings: ['hosts field is not an array']);
      }
      final hosts = <Host>[];
      for (final entry in list) {
        if (entry is! Map) continue;
        final address = (entry['address'] as String?)?.trim() ?? '';
        if (address.isEmpty) continue;
        final label = (entry['label'] as String?)?.trim() ?? address;
        final port = (entry['port'] as num?)?.toInt() ?? 22;
        final username = (entry['username'] as String?)?.trim() ?? '';
        final groupMap = entry['group'];
        final group =
            groupMap is Map ? (groupMap['label'] as String?)?.trim() ?? '' : '';
        hosts.add(Host(
            label: label, host: address, port: port, username: username, group: group));
      }
      return (hosts: hosts, warnings: []);
    }

    // Fallback: try as a JSON array in YourSSH export format
    if (decoded is! List) return (hosts: [], warnings: []);
    try {
      final hosts = (decoded as List)
          .whereType<Map<String, dynamic>>()
          .map((e) {
            final map = Map<String, dynamic>.from(e)..remove('id');
            return Host.fromJson({
              'label': map['label'] ?? '',
              'host': map['host'] ?? '',
              'port': map['port'] ?? 22,
              'username': map['username'] ?? 'root',
              'authType': map['authType'] ?? 'password',
              'group': map['group'] ?? '',
              'tags': map['tags'] ?? [],
              'createdAt': DateTime.now().toIso8601String(),
            });
          })
          .where((h) => h.host.isNotEmpty)
          .toList();
      return (hosts: hosts, warnings: []);
    } catch (_) {
      return (hosts: [], warnings: []);
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "TermiusParser" -v
```

Expected: All Termius tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/util/import_parsers.dart app/test/services/import_parsers_test.dart
git commit -m "feat(import): Termius JSON parser"
```

---

### Task 8: SSH URI parser (TDD)

**Files:**
- Modify: `app/test/services/import_parsers_test.dart`
- Modify: `app/lib/util/import_parsers.dart`

- [ ] **Step 1: Add SSH URI tests**

Add after the `TermiusParser` group:

```dart
  group('SshUriParser', () {
    const parser = SshUriParser();

    test('parses ssh://user@host:port', () {
      const input = 'ssh://admin@192.168.1.1:2222';
      final result = parser.parse(input);
      expect(result.hosts.length, 1);
      expect(result.hosts[0].host, '192.168.1.1');
      expect(result.hosts[0].username, 'admin');
      expect(result.hosts[0].port, 2222);
      expect(result.hosts[0].label, 'admin@192.168.1.1');
    });

    test('parses ssh://user@host without port — defaults to 22', () {
      const input = 'ssh://root@10.0.0.1';
      final result = parser.parse(input);
      expect(result.hosts[0].port, 22);
      expect(result.hosts[0].host, '10.0.0.1');
    });

    test('parses multiple URIs, one per line', () {
      const input = 'ssh://admin@server1.com:22\nssh://deploy@server2.com:2222\n';
      final result = parser.parse(input);
      expect(result.hosts.length, 2);
      expect(result.hosts[0].host, 'server1.com');
      expect(result.hosts[1].host, 'server2.com');
    });

    test('skips non-URI lines silently — no warnings', () {
      const input =
          '# comment\nssh://user@host1.com\nnot-a-uri\nssh://user@host2.com\n';
      final result = parser.parse(input);
      expect(result.hosts.length, 2);
      expect(result.warnings, isEmpty);
    });

    test('empty input returns empty result', () {
      final result = parser.parse('');
      expect(result.hosts, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/services/import_parsers_test.dart --name "SshUriParser" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `SshUriParser` in `import_parsers.dart`**

Add after `TermiusParser`:

```dart
// ── SSH URI ───────────────────────────────────────────────

class SshUriParser extends ImportParser {
  const SshUriParser();

  static final _uriRe = RegExp(
    r'ssh://([^@]+)@([^:/?#\s]+)(?::(\d+))?(?:[/?#][^\s]*)?$',
    caseSensitive: false,
  );

  @override
  ParseResult parse(String input) {
    final hosts = <Host>[];
    for (final raw in input.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final m = _uriRe.firstMatch(line);
      if (m == null) continue;
      final user = m.group(1)!;
      final host = m.group(2)!;
      final port = int.tryParse(m.group(3) ?? '') ?? 22;
      hosts.add(Host(label: '$user@$host', host: host, port: port, username: user));
    }
    return (hosts: hosts, warnings: []);
  }
}
```

- [ ] **Step 4: Run all parser tests**

```bash
cd app && flutter test test/services/import_parsers_test.dart -v
```

Expected: All tests PASS.

- [ ] **Step 5: Run backward-compat tests**

```bash
cd app && flutter test test/widgets/import_parser_test.dart -v
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/util/import_parsers.dart app/test/services/import_parsers_test.dart
git commit -m "feat(import): SSH URI parser"
```

---

### Task 9: `ImportSourceDef` registry + source-picker UI

**Files:**
- Modify: `app/lib/widgets/import_panel.dart`

- [ ] **Step 1: Add `ImportSource` enum and `ImportSourceDef` class to `import_panel.dart`**

Add after the imports section, before `parseSshConfig`:

```dart
enum ImportSource {
  sshConfig, csv, putty, mobaXterm, secureCrt,
  ansible, winScp, termius, sshUri,
}

class ImportSourceDef {
  final ImportSource source;
  final String label;
  final IconData icon;
  final Color iconColor;
  final List<String> fileExtensions;
  final String hint;
  final ImportParser parser;

  const ImportSourceDef({
    required this.source,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.fileExtensions,
    required this.hint,
    required this.parser,
  });

  static const all = [
    ImportSourceDef(
      source: ImportSource.sshConfig,
      label: '~/.ssh',
      icon: Icons.terminal,
      iconColor: Color(0xFF4FC3F7),
      fileExtensions: ['config', 'conf', 'txt'],
      hint: 'SSH config file (~/.ssh/config)',
      parser: SshConfigParser(),
    ),
    ImportSourceDef(
      source: ImportSource.csv,
      label: 'CSV',
      icon: Icons.table_chart,
      iconColor: Color(0xFF81C784),
      fileExtensions: ['csv', 'txt'],
      hint: 'CSV with columns: host, label, port, username, auth_type, group, tags',
      parser: CsvParser(),
    ),
    ImportSourceDef(
      source: ImportSource.putty,
      label: 'PuTTY',
      icon: Icons.computer,
      iconColor: Color(0xFFFFB74D),
      fileExtensions: ['reg', 'txt'],
      hint: 'PuTTY → Registry Export (File → Export settings)',
      parser: PuttyRegParser(),
    ),
    ImportSourceDef(
      source: ImportSource.mobaXterm,
      label: 'MobaXterm',
      icon: Icons.grid_view,
      iconColor: Color(0xFFBA68C8),
      fileExtensions: ['mxtsessions', 'txt'],
      hint: 'MobaXterm → Settings → Export sessions (.mxtsessions)',
      parser: MobaXtermParser(),
    ),
    ImportSourceDef(
      source: ImportSource.secureCrt,
      label: 'SecureCRT',
      icon: Icons.lock_outlined,
      iconColor: Color(0xFFFF8A65),
      fileExtensions: ['xml', 'txt'],
      hint: 'SecureCRT → File → Export Sessions → XML format',
      parser: SecureCrtParser(),
    ),
    ImportSourceDef(
      source: ImportSource.ansible,
      label: 'Ansible',
      icon: Icons.settings_suggest,
      iconColor: Color(0xFFEF5350),
      fileExtensions: ['ini', 'yml', 'yaml', 'txt'],
      hint: 'Ansible INI inventory file (hosts, groups, ansible_* vars)',
      parser: AnsibleParser(),
    ),
    ImportSourceDef(
      source: ImportSource.winScp,
      label: 'WinSCP',
      icon: Icons.swap_horiz,
      iconColor: Color(0xFF4DB6AC),
      fileExtensions: ['ini', 'txt'],
      hint: 'WinSCP → Tools → Export/Backup Configuration → Sessions',
      parser: WinScpParser(),
    ),
    ImportSourceDef(
      source: ImportSource.termius,
      label: 'Termius',
      icon: Icons.phonelink,
      iconColor: Color(0xFF7986CB),
      fileExtensions: ['termius', 'json', 'txt'],
      hint: 'Termius → Keychain → Export (.termius or JSON)',
      parser: TermiusParser(),
    ),
    ImportSourceDef(
      source: ImportSource.sshUri,
      label: 'SSH URI',
      icon: Icons.link,
      iconColor: Color(0xFF4DD0E1),
      fileExtensions: ['txt'],
      hint: 'One ssh://user@host:port per line',
      parser: SshUriParser(),
    ),
  ];
}
```

- [ ] **Step 2: Add state + new build methods to `_ImportPanelState`**

Add `_selectedSource` field and getter in `_ImportPanelState`:
```dart
ImportSource? _selectedSource;
ImportSourceDef? get _sourceDef => _selectedSource == null
    ? null
    : ImportSourceDef.all.firstWhere((d) => d.source == _selectedSource);
```

Replace `_buildHeader()`:
```dart
Widget _buildHeader() {
  final def = _sourceDef;
  return Container(
    height: 52,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        if (def != null)
          GestureDetector(
            onTap: () => setState(() {
              _selectedSource = null;
              _parsed = [];
              _parseError = null;
              _csvWarnings = [];
            }),
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.arrow_back, size: 16, color: AppColors.textSecondary),
            ),
          ),
        Expanded(
          child: Text(
            def == null ? 'Import Hosts' : 'Import from ${def.label}',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ),
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}
```

Add source-picker and hint builders:
```dart
Widget _buildSourcePicker() {
  return GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 3,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 1.0,
    children: ImportSourceDef.all
        .map((def) => _SourceCard(
              def: def,
              onTap: () => setState(() {
                _selectedSource = def.source;
                _parsed = [];
                _parseError = null;
                _csvWarnings = [];
              }),
            ))
        .toList(),
  );
}

Widget _buildSourceHint(ImportSourceDef def) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      def.hint,
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
    ),
  );
}
```

Replace `build()`:
```dart
@override
Widget build(BuildContext context) {
  final existingHosts = context.read<HostProvider>().allHosts;
  final def = _sourceDef;
  return Container(
    width: 340,
    decoration: const BoxDecoration(
      color: AppColors.sidebar,
      border: Border(left: BorderSide(color: AppColors.border)),
    ),
    child: Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (def == null) ...[
                _buildSourcePicker(),
              ] else ...[
                _buildSourceHint(def),
                _buildModeToggle(),
                const SizedBox(height: 12),
                if (_mode == _InputMode.file) _buildFileSection(),
                if (_mode == _InputMode.paste) _buildPasteSection(),
                if (_parseError != null) ...[
                  const SizedBox(height: 8),
                  Text(_parseError!,
                      style: const TextStyle(color: AppColors.red, fontSize: 11)),
                ],
                if (_csvWarnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildWarnings(),
                ],
                if (_parsed.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildPreview(existingHosts),
                  const SizedBox(height: 16),
                  _buildImportButton(context, existingHosts),
                ],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Update `_pickFile` to use source-specific extensions**

Replace `_pickFile()`:
```dart
Future<void> _pickFile() async {
  final extensions =
      _sourceDef?.fileExtensions ?? ['json', 'config', 'conf', 'txt', 'csv'];
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  final bytes = result.files.first.bytes;
  if (bytes == null) return;
  _parseInput(utf8.decode(bytes));
}
```

- [ ] **Step 4: Update `_parseInput` to use the selected source's parser**

Replace `_parseInput()`:
```dart
void _parseInput(String input) {
  final def = _sourceDef;
  if (def != null) {
    try {
      final result = def.parser.parse(input);
      _applyParsed(result.hosts, warnings: result.warnings);
    } on FormatException catch (e) {
      setState(() {
        _csvWarnings = [];
        _parsed = [];
        _parseError = e.message;
        _included.clear();
        _overwrite.clear();
      });
    }
    return;
  }

  // No source selected — legacy auto-detect (paste from non-source flow)
  final trimmed = input.trimLeft();
  final firstLine = trimmed.split('\n').first;
  final looksLikeCsv = firstLine.contains(',') &&
      !trimmed.toLowerCase().startsWith('host ') &&
      !trimmed.startsWith('[') &&
      !trimmed.startsWith('{');

  if (looksLikeCsv) {
    try {
      final result = parseCsvHosts(input);
      _applyParsed(result.hosts, warnings: result.warnings);
    } on FormatException catch (e) {
      setState(() {
        _csvWarnings = [];
        _parsed = [];
        _parseError = e.message;
        _included.clear();
        _overwrite.clear();
      });
    }
  } else {
    _applyParsed(detectAndParse(input));
  }
}
```

- [ ] **Step 5: Add `_SourceCard` widget at the bottom of `import_panel.dart`**

Add after `_DuplicateBadge`:

```dart
class _SourceCard extends StatelessWidget {
  final ImportSourceDef def;
  final VoidCallback onTap;

  const _SourceCard({required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: def.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(def.icon, size: 18, color: def.iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              def.label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run analyze and both test suites**

```bash
cd app && flutter analyze lib/widgets/import_panel.dart && flutter test test/widgets/import_parser_test.dart -v
```

Expected: No errors, all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/widgets/import_panel.dart
git commit -m "feat(import): source-picker grid UI with 9 sources"
```

---

### Task 10: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run all import tests together**

```bash
cd app && flutter test test/widgets/import_parser_test.dart test/services/import_parsers_test.dart -v
```

Expected: All tests PASS.

- [ ] **Step 2: Run full flutter analyze**

```bash
cd app && flutter analyze
```

Expected: No issues.

- [ ] **Step 3: Fix any analyze issues, then final commit**

If `flutter analyze` flagged warnings or errors, fix them and commit:
```bash
git add app/lib/util/import_parsers.dart app/lib/widgets/import_panel.dart
git commit -m "fix(import): address flutter analyze findings"
```

If no issues, skip this step.
