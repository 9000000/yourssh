# Server Monitor Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live per-host monitoring panel to the Hosts Dashboard showing CPU, memory, disk, uptime, open ports, and firewall status via a draggable bottom sheet.

**Architecture:** Two polling services (`SystemStatsService` at 5s, `FirewallStatusService` at 30s) follow the `NetworkStatsService` pattern exactly — `Timer.periodic` → `SshService.exec` → pure parser → callback. The `ServerMonitorSheet` owns the services in its `State`, starts them in `didChangeDependencies`, and stops them in `dispose`. A "Monitor" button on connected host cards plus a context menu item in `HostsDashboard` open the sheet.

**Tech Stack:** Flutter/Dart, `SshService.exec` (existing), `Timer.periodic`, `DraggableScrollableSheet`, `LinearProgressIndicator`, provider pattern.

---

## File Map

```
app/lib/models/system_snapshot.dart           (new)
app/lib/models/firewall_status.dart           (new)
app/lib/services/system_stats_service.dart    (new)
app/lib/services/firewall_status_service.dart (new)
app/lib/widgets/server_monitor_sheet.dart     (new)
app/lib/widgets/hosts_dashboard.dart          (edit — monitor button + context menu)
app/test/models/system_snapshot_test.dart     (new)
app/test/models/firewall_status_test.dart     (new)
app/test/services/system_stats_service_test.dart    (new)
app/test/services/firewall_status_service_test.dart (new)
app/test/widgets/server_monitor_sheet_test.dart     (new)
```

---

## Task 1: SystemSnapshot model + parser

**Files:**
- Create: `app/lib/models/system_snapshot.dart`
- Create: `app/test/models/system_snapshot_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/models/system_snapshot_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/system_snapshot.dart';

const _kFullOutput = '''
__CPU1__
cpu  454542 3253 96425 15678532 5432 0 1234 0 0 0
__CPU2__
cpu  454643 3253 96431 15679102 5435 0 1235 0 0 0
__MEM__
MemTotal:       16384000 kB
MemFree:         8192000 kB
MemAvailable:    9216000 kB
Buffers:          512000 kB
Cached:          1024000 kB
__DISK__
Filesystem     1K-blocks      Used Available Use% Mounted on
/dev/sda1      120000000  54000000  66000000  45% /
/dev/sdb1       20000000   4000000  16000000  20% /data
tmpfs            8192000         0   8192000   0% /dev/shm
devtmpfs         4096000         0   4096000   0% /dev
__UPTIME__
1234567.89 432.10
__PORTS__
Netid  State   Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
tcp    LISTEN  0      128    0.0.0.0:22           0.0.0.0:*         users:(("sshd",pid=1234,fd=3))
tcp    LISTEN  0      128    0.0.0.0:80           0.0.0.0:*         users:(("nginx",pid=5678,fd=6))
tcp6   LISTEN  0      128    [::]:22              [::]:*            users:(("sshd",pid=1234,fd=3))
udp    UNCONN  0      0      127.0.0.53%lo:53    0.0.0.0:*         users:(("systemd-resolve",pid=567,fd=12))
''';

void main() {
  group('SystemSnapshot.fromShellOutput', () {
    test('parses cpu percent from two proc/stat reads', () {
      final s = SystemSnapshot.fromShellOutput(_kFullOutput);
      // totalDelta=681, idleDelta=573 → (1 - 573/681)*100 ≈ 15.86%
      expect(s.cpuPercent, closeTo(15.86, 0.5));
    });

    test('parses memory', () {
      final s = SystemSnapshot.fromShellOutput(_kFullOutput);
      expect(s.totalMemBytes, 16384000 * 1024);
      expect(s.usedMemBytes, (16384000 - 9216000) * 1024); // 7168000 * 1024
    });

    test('parses disks and skips tmpfs/devtmpfs', () {
      final s = SystemSnapshot.fromShellOutput(_kFullOutput);
      expect(s.disks.length, 2);
      expect(s.disks.map((d) => d.mountPoint), containsAll(['/', '/data']));
      expect(s.disks.any((d) => d.source.startsWith('tmpfs')), isFalse);
    });

    test('parses uptime', () {
      final s = SystemSnapshot.fromShellOutput(_kFullOutput);
      expect(s.uptime, const Duration(seconds: 1234567));
    });

    test('parses ports and deduplicates tcp/tcp6', () {
      final s = SystemSnapshot.fromShellOutput(_kFullOutput);
      // port 22 appears as tcp + tcp6 → deduplicated to 1
      expect(s.ports.length, 3); // 22 (deduped), 80, 53
      expect(s.ports.map((p) => p.localPort), containsAll([22, 80, 53]));
      final ssh = s.ports.firstWhere((p) => p.localPort == 22);
      expect(ssh.protocol, 'tcp');
      expect(ssh.process, 'sshd');
    });

    test('returns zeroes on empty output', () {
      final s = SystemSnapshot.fromShellOutput('');
      expect(s.cpuPercent, 0.0);
      expect(s.totalMemBytes, 0);
      expect(s.disks, isEmpty);
      expect(s.ports, isEmpty);
    });

    test('parses netstat -tulpn port format', () {
      const output = '''
__CPU1__
cpu  100 0 0 900 0 0 0 0 0 0
__CPU2__
cpu  101 0 0 901 0 0 0 0 0 0
__MEM__
MemTotal: 1024 kB
MemAvailable: 512 kB
__DISK__
Filesystem 1K-blocks Used Available Use% Mounted on
/dev/sda1  100000    50000 50000    50% /
__UPTIME__
100.0 50.0
__PORTS__
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1234/sshd
tcp6       0      0 :::22                   :::*                    LISTEN      1234/sshd
''';
      final s = SystemSnapshot.fromShellOutput(output);
      expect(s.ports.length, 1); // deduplicated
      expect(s.ports.first.localPort, 22);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/models/system_snapshot_test.dart
```

Expected: `Error: 'system_snapshot.dart' not found` or similar compile error.

- [ ] **Step 3: Implement `system_snapshot.dart`**

```dart
// app/lib/models/system_snapshot.dart
class SystemSnapshot {
  final double cpuPercent;
  final int totalMemBytes;
  final int usedMemBytes;
  final List<DiskMount> disks;
  final Duration uptime;
  final List<PortEntry> ports;
  final DateTime timestamp;

  const SystemSnapshot({
    required this.cpuPercent,
    required this.totalMemBytes,
    required this.usedMemBytes,
    required this.disks,
    required this.uptime,
    required this.ports,
    required this.timestamp,
  });

  factory SystemSnapshot.fromShellOutput(String output) {
    final sections = _splitSections(output);
    return SystemSnapshot(
      cpuPercent: _parseCpuPercent(
        sections['__CPU1__'] ?? '',
        sections['__CPU2__'] ?? '',
      ),
      totalMemBytes: _parseMem(sections['__MEM__'] ?? '').$1,
      usedMemBytes: _parseMem(sections['__MEM__'] ?? '').$2,
      disks: _parseDisks(sections['__DISK__'] ?? ''),
      uptime: _parseUptime(sections['__UPTIME__'] ?? ''),
      ports: _parsePorts(sections['__PORTS__'] ?? ''),
      timestamp: DateTime.now(),
    );
  }

  static Map<String, String> _splitSections(String output) {
    const sentinels = {
      '__CPU1__', '__CPU2__', '__MEM__', '__DISK__', '__UPTIME__', '__PORTS__',
    };
    final sections = <String, String>{};
    String? currentKey;
    final buf = StringBuffer();
    for (final line in output.split('\n')) {
      final t = line.trim();
      if (sentinels.contains(t)) {
        if (currentKey != null) sections[currentKey] = buf.toString();
        currentKey = t;
        buf.clear();
      } else if (currentKey != null) {
        buf.writeln(line);
      }
    }
    if (currentKey != null) sections[currentKey] = buf.toString();
    return sections;
  }

  static double _parseCpuPercent(String cpu1, String cpu2) {
    final s1 = _cpuStats(cpu1.trim());
    final s2 = _cpuStats(cpu2.trim());
    if (s1 == null || s2 == null || s1.length < 5 || s2.length < 5) return 0.0;
    final total1 = s1.reduce((a, b) => a + b);
    final idle1 = s1[3] + s1[4]; // idle + iowait
    final total2 = s2.reduce((a, b) => a + b);
    final idle2 = s2[3] + s2[4];
    final dTotal = total2 - total1;
    final dIdle = idle2 - idle1;
    if (dTotal <= 0) return 0.0;
    return ((1.0 - dIdle / dTotal) * 100.0).clamp(0.0, 100.0);
  }

  static List<int>? _cpuStats(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.isEmpty || !parts[0].startsWith('cpu')) return null;
    return parts.skip(1).map((s) => int.tryParse(s) ?? 0).toList();
  }

  static (int, int) _parseMem(String section) {
    int totalKb = 0, availableKb = 0;
    for (final line in section.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final val = int.tryParse(parts[1]) ?? 0;
      if (parts[0] == 'MemTotal:') totalKb = val;
      if (parts[0] == 'MemAvailable:') availableKb = val;
    }
    final total = totalKb * 1024;
    final used = ((totalKb - availableKb) * 1024).clamp(0, total);
    return (total, used);
  }

  static const _kSkipFs = {
    'tmpfs', 'devtmpfs', 'overlay', 'squashfs', 'udev', 'run', 'none',
  };

  static List<DiskMount> _parseDisks(String section) {
    final result = <DiskMount>[];
    final lines = section.split('\n').skip(1); // skip header
    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 6) continue;
      final source = parts[0];
      if (_kSkipFs.any((f) => source.startsWith(f))) continue;
      final totalKb = int.tryParse(parts[1]) ?? 0;
      final usedKb = int.tryParse(parts[2]) ?? 0;
      final mount = parts[5];
      result.add(DiskMount(source: source, mountPoint: mount, totalKb: totalKb, usedKb: usedKb));
    }
    return result;
  }

  static Duration _parseUptime(String section) {
    final line = section.trim().split('\n').first.trim();
    final secs = double.tryParse(line.split(' ').first) ?? 0.0;
    return Duration(seconds: secs.floor());
  }

  static List<PortEntry> _parsePorts(String section) {
    final entries = <PortEntry>[];
    for (final line in section.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) continue;
      final proto = parts[0].toLowerCase();
      if (!proto.startsWith('tcp') && !proto.startsWith('udp')) continue;

      String? localAddr;
      String? processStr;

      // ss format: State is parts[1] (LISTEN/UNCONN), local addr is parts[4]
      if (parts[1] == 'LISTEN' || parts[1] == 'UNCONN') {
        localAddr = parts[4];
        processStr = parts.length > 6 ? parts.skip(6).join(' ') : null;
      }
      // netstat format: State is parts[5], local addr is parts[3]
      else if (parts.length >= 6 && parts[5] == 'LISTEN') {
        localAddr = parts[3];
        processStr = parts.length > 6 ? parts[6] : null;
      }

      if (localAddr == null) continue;
      final lastColon = localAddr.lastIndexOf(':');
      if (lastColon < 0) continue;
      final port = int.tryParse(localAddr.substring(lastColon + 1));
      if (port == null) continue;
      final address = localAddr.substring(0, lastColon);

      entries.add(PortEntry(
        protocol: proto.replaceAll('6', '').replaceAll('4', ''),
        localAddress: address,
        localPort: port,
        process: _extractProcess(processStr),
      ));
    }

    // Deduplicate by port number, sort ascending
    final seen = <int>{};
    final deduped = entries.where((e) => seen.add(e.localPort)).toList()
      ..sort((a, b) => a.localPort.compareTo(b.localPort));
    return deduped;
  }

  static String? _extractProcess(String? raw) {
    if (raw == null) return null;
    // ss: users:(("sshd",pid=1234,fd=3))  or  netstat: 1234/sshd
    final ssMatch = RegExp(r'"([^"]+)"').firstMatch(raw);
    if (ssMatch != null) return ssMatch.group(1);
    final parts = raw.split('/');
    return parts.length > 1 ? parts.last.trim() : null;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String formatUptime(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    parts.add('${minutes}m');
    return parts.join(' ');
  }
}

class DiskMount {
  final String source;
  final String mountPoint;
  final int totalKb;
  final int usedKb;
  const DiskMount({
    required this.source,
    required this.mountPoint,
    required this.totalKb,
    required this.usedKb,
  });
  double get usedPercent => totalKb == 0 ? 0 : usedKb / totalKb;
}

class PortEntry {
  final String protocol;
  final String localAddress;
  final int localPort;
  final String? process;
  const PortEntry({
    required this.protocol,
    required this.localAddress,
    required this.localPort,
    this.process,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd app && flutter test test/models/system_snapshot_test.dart
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/lib/models/system_snapshot.dart app/test/models/system_snapshot_test.dart
git commit -m "feat(monitor): SystemSnapshot model with proc/stat+meminfo+df+ss parser"
```

---

## Task 2: FirewallStatus model + parser

**Files:**
- Create: `app/lib/models/firewall_status.dart`
- Create: `app/test/models/firewall_status_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/models/firewall_status_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/firewall_status.dart';

void main() {
  group('FirewallStatus.fromShellOutput', () {
    test('parses active ufw with deny default and rules', () {
      const output = '''
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 80/tcp                     ALLOW IN    Anywhere
[ 3] 22/tcp (v6)                ALLOW IN    Anywhere (v6)
''';
      final s = FirewallStatus.fromShellOutput(output);
      expect(s.type, FirewallType.ufw);
      expect(s.enabled, isTrue);
      expect(s.defaultInboundPolicy, 'DENY');
      expect(s.rules.length, 3);
      expect(s.rules.first.action, 'ALLOW');
    });

    test('parses inactive ufw', () {
      final s = FirewallStatus.fromShellOutput('Status: inactive');
      expect(s.type, FirewallType.ufw);
      expect(s.enabled, isFalse);
      expect(s.rules, isEmpty);
    });

    test('parses iptables-save with DROP default', () {
      const output = '''
# Generated by iptables-save
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p tcp --dport 80 -j ACCEPT
COMMIT
''';
      final s = FirewallStatus.fromShellOutput(output);
      expect(s.type, FirewallType.iptables);
      expect(s.enabled, isTrue);
      expect(s.defaultInboundPolicy, 'DROP');
      final inputRules = s.rules.where((r) => r.chain == 'INPUT').toList();
      expect(inputRules.length, 3);
      expect(inputRules.last.action, 'ACCEPT');
    });

    test('parses nft ruleset', () {
      const output = '''
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        iif "lo" accept
        tcp dport 22 accept
    }
}
''';
      final s = FirewallStatus.fromShellOutput(output);
      expect(s.type, FirewallType.nftables);
      expect(s.enabled, isTrue);
      expect(s.defaultInboundPolicy, 'DROP');
      expect(s.rules.isNotEmpty, isTrue);
    });

    test('returns none for __NO_FIREWALL__ sentinel', () {
      final s = FirewallStatus.fromShellOutput('__NO_FIREWALL__\n');
      expect(s.type, FirewallType.none);
      expect(s.enabled, isFalse);
      expect(s.rules, isEmpty);
    });

    test('returns none for unrecognized output', () {
      final s = FirewallStatus.fromShellOutput('some random text');
      expect(s.type, FirewallType.none);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```bash
cd app && flutter test test/models/firewall_status_test.dart
```

Expected: compile error — file doesn't exist yet.

- [ ] **Step 3: Implement `firewall_status.dart`**

```dart
// app/lib/models/firewall_status.dart
enum FirewallType { ufw, iptables, nftables, none }

class FirewallStatus {
  final FirewallType type;
  final bool enabled;
  final String? defaultInboundPolicy;
  final List<FirewallRule> rules;

  const FirewallStatus({
    required this.type,
    required this.enabled,
    this.defaultInboundPolicy,
    required this.rules,
  });

  static const _kNone = FirewallStatus(type: FirewallType.none, enabled: false, rules: []);

  factory FirewallStatus.fromShellOutput(String output) {
    if (output.contains('__NO_FIREWALL__')) return _kNone;
    if (output.contains('Status: active') || output.contains('Status: inactive')) {
      return _parseUfw(output);
    }
    if (output.contains('*filter') ||
        RegExp(r'-A (INPUT|OUTPUT|FORWARD)').hasMatch(output)) {
      return _parseIptables(output);
    }
    if (output.contains('hook input') && output.contains('chain')) {
      return _parseNft(output);
    }
    return _kNone;
  }

  static FirewallStatus _parseUfw(String output) {
    final enabled = output.contains('Status: active');
    String? defaultPolicy;
    final rules = <FirewallRule>[];
    for (final line in output.split('\n')) {
      final t = line.trim();
      if (t.startsWith('Default:')) {
        final m = RegExp(r'Default: (\w+) \(incoming\)').firstMatch(t);
        defaultPolicy = m?.group(1)?.toUpperCase();
      }
      final m = RegExp(r'^\[\s*\d+\]\s+(.+?)\s{2,}(ALLOW|DENY|LIMIT|REJECT)\s').firstMatch(t);
      if (m != null) {
        rules.add(FirewallRule(description: t, action: m.group(2), chain: null));
      }
    }
    return FirewallStatus(
      type: FirewallType.ufw, enabled: enabled,
      defaultInboundPolicy: defaultPolicy, rules: rules,
    );
  }

  static FirewallStatus _parseIptables(String output) {
    String? defaultPolicy;
    final rules = <FirewallRule>[];
    bool inFilter = false;
    for (final line in output.split('\n')) {
      final t = line.trim();
      if (t == '*filter') { inFilter = true; continue; }
      if (t == 'COMMIT') { inFilter = false; continue; }
      if (!inFilter) continue;
      final chain = RegExp(r'^:INPUT (\w+)').firstMatch(t);
      if (chain != null) defaultPolicy = chain.group(1);
      final rule = RegExp(r'^-A (\w+) .+ -j (\w+)').firstMatch(t);
      if (rule != null) {
        rules.add(FirewallRule(
          description: t, action: rule.group(2), chain: rule.group(1),
        ));
      }
    }
    return FirewallStatus(
      type: FirewallType.iptables, enabled: true,
      defaultInboundPolicy: defaultPolicy, rules: rules,
    );
  }

  static FirewallStatus _parseNft(String output) {
    final policyMatch = RegExp(r'hook input[^;]*;\s*policy (\w+);').firstMatch(output);
    final defaultPolicy = policyMatch?.group(1)?.toUpperCase();
    final rules = <FirewallRule>[];
    for (final line in output.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('table') || t.startsWith('chain') ||
          t.startsWith('type') || t == '{' || t == '}') continue;
      if (t.contains('accept') || t.contains('drop') || t.contains('reject')) {
        final action = t.contains('accept') ? 'ACCEPT'
            : t.contains('drop') ? 'DROP' : 'REJECT';
        rules.add(FirewallRule(description: t, action: action, chain: 'input'));
      }
    }
    return FirewallStatus(
      type: FirewallType.nftables, enabled: true,
      defaultInboundPolicy: defaultPolicy, rules: rules,
    );
  }
}

class FirewallRule {
  final String description;
  final String? action;
  final String? chain;
  const FirewallRule({required this.description, this.action, this.chain});
}
```

- [ ] **Step 4: Run tests**

```bash
cd app && flutter test test/models/firewall_status_test.dart
```

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add app/lib/models/firewall_status.dart app/test/models/firewall_status_test.dart
git commit -m "feat(monitor): FirewallStatus model with ufw/iptables/nftables parser"
```

---

## Task 3: SystemStatsService + test

**Files:**
- Create: `app/lib/services/system_stats_service.dart`
- Create: `app/test/services/system_stats_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/services/system_stats_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/system_snapshot.dart';
import 'package:yourssh/services/system_stats_service.dart';
import 'package:yourssh/services/ssh_service.dart';

class _FakeSsh extends Fake implements SshService {
  final String stdout;
  int callCount = 0;
  _FakeSsh(this.stdout);

  @override
  Future<({String stdout, String stderr, int exitCode})> exec(
    Host host,
    String command, {
    String? auditSource = 'app',
  }) async {
    callCount++;
    return (stdout: stdout, stderr: '', exitCode: 0);
  }
}

class _ThrowingSsh extends Fake implements SshService {
  @override
  Future<({String stdout, String stderr, int exitCode})> exec(
    Host host,
    String command, {
    String? auditSource = 'app',
  }) async {
    throw Exception('disconnected');
  }
}

Host _host() => Host(
  id: 'h1', label: 'test', host: 'example.com', port: 22, username: 'root',
);

const _kOutput = '''
__CPU1__
cpu  100 0 0 900 0 0 0 0 0 0
__CPU2__
cpu  110 0 0 910 0 0 0 0 0 0
__MEM__
MemTotal:       2048000 kB
MemAvailable:   1024000 kB
__DISK__
Filesystem 1K-blocks Used Available Use% Mounted on
/dev/sda1  100000    50000 50000    50% /
__UPTIME__
3600.0 1800.0
__PORTS__
''';

void main() {
  group('SystemStatsService', () {
    test('poll delivers parsed snapshot via onUpdate', () async {
      SystemSnapshot? got;
      final svc = SystemStatsService(
        host: _host(),
        sshService: _FakeSsh(_kOutput),
        onUpdate: (s) => got = s,
      );
      await svc.poll();
      expect(got, isNotNull);
      expect(got!.disks.length, 1);
      expect(got!.uptime, const Duration(hours: 1));
      expect(got!.totalMemBytes, 2048000 * 1024);
    });

    test('poll silently ignores exec exceptions', () async {
      final svc = SystemStatsService(
        host: _host(),
        sshService: _ThrowingSsh(),
        onUpdate: (_) => fail('should not call onUpdate'),
      );
      await expectLater(svc.poll(), completes); // no throw
    });

    test('poll is not called before start()', () async {
      final ssh = _FakeSsh(_kOutput);
      SystemStatsService(
        host: _host(), sshService: ssh, onUpdate: (_) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ssh.callCount, 0);
    });

    test('stop() cancels the timer', () async {
      final ssh = _FakeSsh(_kOutput);
      final svc = SystemStatsService(
        host: _host(),
        sshService: ssh,
        onUpdate: (_) {},
      );
      svc.start(interval: const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 35));
      svc.stop();
      final countAfterStop = ssh.callCount;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(ssh.callCount, countAfterStop);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```bash
cd app && flutter test test/services/system_stats_service_test.dart
```

Expected: compile error.

- [ ] **Step 3: Implement `system_stats_service.dart`**

```dart
// app/lib/services/system_stats_service.dart
import 'dart:async';
import '../models/host.dart';
import '../models/system_snapshot.dart';
import 'ssh_service.dart';

class SystemStatsService {
  Timer? _timer;
  final Host host;
  final SshService sshService;
  final void Function(SystemSnapshot) onUpdate;

  SystemStatsService({
    required this.host,
    required this.sshService,
    required this.onUpdate,
  });

  void start({Duration interval = const Duration(seconds: 5)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Exposed for tests — fires one poll cycle immediately.
  Future<void> poll() async {
    try {
      final result = await sshService.exec(host, _kCommand, auditSource: null);
      if (result.stdout.isEmpty) return;
      onUpdate(SystemSnapshot.fromShellOutput(result.stdout));
    } catch (_) {}
  }
}

// Dart raw-string concatenation — compiled to a single string constant.
const _kCommand =
    r'c1=$(grep -m1 "^cpu " /proc/stat 2>/dev/null); sleep 0.2; '
    r'c2=$(grep -m1 "^cpu " /proc/stat 2>/dev/null); '
    r'printf "__CPU1__\n%s\n__CPU2__\n%s\n" "$c1" "$c2"; '
    r'printf "__MEM__\n"; cat /proc/meminfo 2>/dev/null; '
    r'printf "__DISK__\n"; df -k 2>/dev/null; '
    r'printf "__UPTIME__\n"; cat /proc/uptime 2>/dev/null; '
    r'printf "__PORTS__\n"; ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null';
```

- [ ] **Step 4: Run tests**

```bash
cd app && flutter test test/services/system_stats_service_test.dart
```

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/system_stats_service.dart app/test/services/system_stats_service_test.dart
git commit -m "feat(monitor): SystemStatsService — 5s polling via SSH exec"
```

---

## Task 4: FirewallStatusService + test

**Files:**
- Create: `app/lib/services/firewall_status_service.dart`
- Create: `app/test/services/firewall_status_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/services/firewall_status_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/firewall_status.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/services/firewall_status_service.dart';
import 'package:yourssh/services/ssh_service.dart';

class _FakeSsh extends Fake implements SshService {
  final String stdout;
  _FakeSsh(this.stdout);
  @override
  Future<({String stdout, String stderr, int exitCode})> exec(
    Host host, String command, {String? auditSource = 'app'}) async =>
      (stdout: stdout, stderr: '', exitCode: 0);
}

class _ThrowingSsh extends Fake implements SshService {
  @override
  Future<({String stdout, String stderr, int exitCode})> exec(
    Host host, String command, {String? auditSource = 'app'}) async =>
      throw Exception('err');
}

Host _host() => Host(
  id: 'h1', label: 'test', host: 'example.com', port: 22, username: 'root',
);

void main() {
  group('FirewallStatusService', () {
    test('poll delivers parsed FirewallStatus via onUpdate', () async {
      FirewallStatus? got;
      final svc = FirewallStatusService(
        host: _host(),
        sshService: _FakeSsh('Status: active\nDefault: deny (incoming), allow (outgoing)\n'),
        onUpdate: (f) => got = f,
      );
      await svc.poll();
      expect(got, isNotNull);
      expect(got!.type, FirewallType.ufw);
      expect(got!.enabled, isTrue);
    });

    test('poll silently ignores exec exceptions', () async {
      final svc = FirewallStatusService(
        host: _host(),
        sshService: _ThrowingSsh(),
        onUpdate: (_) => fail('should not call'),
      );
      await expectLater(svc.poll(), completes);
    });

    test('poll delivers none type for __NO_FIREWALL__', () async {
      FirewallStatus? got;
      final svc = FirewallStatusService(
        host: _host(),
        sshService: _FakeSsh('__NO_FIREWALL__'),
        onUpdate: (f) => got = f,
      );
      await svc.poll();
      expect(got!.type, FirewallType.none);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```bash
cd app && flutter test test/services/firewall_status_service_test.dart
```

- [ ] **Step 3: Implement `firewall_status_service.dart`**

```dart
// app/lib/services/firewall_status_service.dart
import 'dart:async';
import '../models/firewall_status.dart';
import '../models/host.dart';
import 'ssh_service.dart';

class FirewallStatusService {
  Timer? _timer;
  final Host host;
  final SshService sshService;
  final void Function(FirewallStatus) onUpdate;

  FirewallStatusService({
    required this.host,
    required this.sshService,
    required this.onUpdate,
  });

  void start({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Exposed for tests.
  Future<void> poll() async {
    try {
      final result = await sshService.exec(host, _kCommand, auditSource: null);
      onUpdate(FirewallStatus.fromShellOutput(result.stdout));
    } catch (_) {}
  }
}

const _kCommand =
    'ufw status numbered 2>/dev/null || '
    'iptables-save 2>/dev/null || '
    'nft list ruleset 2>/dev/null || '
    'echo __NO_FIREWALL__';
```

- [ ] **Step 4: Run tests**

```bash
cd app && flutter test test/services/firewall_status_service_test.dart
```

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/firewall_status_service.dart app/test/services/firewall_status_service_test.dart
git commit -m "feat(monitor): FirewallStatusService — 30s polling for ufw/iptables/nftables"
```

---

## Task 5: ServerMonitorSheet widget

**Files:**
- Create: `app/lib/widgets/server_monitor_sheet.dart`
- Create: `app/test/widgets/server_monitor_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/server_monitor_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yourssh/models/firewall_status.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/system_snapshot.dart';
import 'package:yourssh/providers/session_provider.dart';
import 'package:yourssh/services/ssh_service.dart';
import 'package:yourssh/widgets/server_monitor_sheet.dart';

// sshSessions is List<SshSession> — use testIsConnected to bypass the
// provider check without needing a real SshSession in tests.
class _FakeSsh extends Fake implements SshService {}

Widget _wrap(Widget child) => MultiProvider(
      providers: [
        Provider<SshService>(create: (_) => _FakeSsh()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

Host _host() => Host(
      id: 'h1', label: 'ubuntu-prod', host: 'example.com',
      port: 22, username: 'root',
    );

void main() {
  group('ServerMonitorSheet', () {
    testWidgets('shows not-connected message when testIsConnected is false',
        (tester) async {
      await tester.pumpWidget(
        _wrap(ServerMonitorSheet(host: _host(), testIsConnected: false)),
      );
      expect(find.textContaining('No active session'), findsOneWidget);
    });

    testWidgets('shows loading indicators while awaiting first snapshot',
        (tester) async {
      await tester.pumpWidget(
        _wrap(ServerMonitorSheet(host: _host(), testIsConnected: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('renders cpu/memory section after debugSetSnapshot',
        (tester) async {
      await tester.pumpWidget(
        _wrap(ServerMonitorSheet(host: _host(), testIsConnected: true)),
      );
      final state = tester.state<ServerMonitorSheetState>(
        find.byType(ServerMonitorSheet),
      );
      state.debugSetSnapshot(SystemSnapshot(
        cpuPercent: 42.5,
        totalMemBytes: 8 * 1024 * 1024 * 1024,
        usedMemBytes: 3 * 1024 * 1024 * 1024,
        disks: [DiskMount(source: '/dev/sda1', mountPoint: '/', totalKb: 100000, usedKb: 45000)],
        uptime: const Duration(hours: 14, minutes: 3),
        ports: [PortEntry(protocol: 'tcp', localAddress: '0.0.0.0', localPort: 22, process: 'sshd')],
        timestamp: DateTime.now(),
      ));
      await tester.pump();
      expect(find.textContaining('42'), findsOneWidget); // cpu %
      expect(find.textContaining('sshd'), findsOneWidget);
    });

    testWidgets('renders firewall section after debugSetFirewall',
        (tester) async {
      await tester.pumpWidget(
        _wrap(ServerMonitorSheet(host: _host(), testIsConnected: true)),
      );
      final state = tester.state<ServerMonitorSheetState>(
        find.byType(ServerMonitorSheet),
      );
      state.debugSetFirewall(const FirewallStatus(
        type: FirewallType.ufw, enabled: true,
        defaultInboundPolicy: 'DENY',
        rules: [FirewallRule(description: '22/tcp  ALLOW  anywhere', action: 'ALLOW')],
      ));
      await tester.pump();
      expect(find.textContaining('ufw'), findsOneWidget);
      expect(find.textContaining('DENY'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```bash
cd app && flutter test test/widgets/server_monitor_sheet_test.dart
```

- [ ] **Step 3: Implement `server_monitor_sheet.dart`**

```dart
// app/lib/widgets/server_monitor_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/firewall_status.dart';
import '../models/host.dart';
import '../models/system_snapshot.dart';
import '../providers/session_provider.dart';
import '../services/firewall_status_service.dart';
import '../services/ssh_service.dart';
import '../services/system_stats_service.dart';
import '../theme/app_theme.dart';

class ServerMonitorSheet extends StatefulWidget {
  final Host host;
  // Bypasses the SessionProvider check in tests — null means use the real check.
  @visibleForTesting
  final bool? testIsConnected;

  const ServerMonitorSheet({super.key, required this.host, this.testIsConnected});

  static void show(BuildContext context, Host host) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServerMonitorSheet(host: host),
    );
  }

  @override
  State<ServerMonitorSheet> createState() => ServerMonitorSheetState();
}

// Public so tests can cast to it.
class ServerMonitorSheetState extends State<ServerMonitorSheet> {
  SystemStatsService? _statsService;
  FirewallStatusService? _firewallService;
  SystemSnapshot? _snapshot;
  FirewallStatus? _firewall;
  bool _started = false;

  @visibleForTesting
  void debugSetSnapshot(SystemSnapshot s) => setState(() => _snapshot = s);

  @visibleForTesting
  void debugSetFirewall(FirewallStatus f) => setState(() => _firewall = f);

  bool _isConnected(BuildContext context) =>
      widget.testIsConnected ??
      context
          .read<SessionProvider>()
          .sshSessions
          .any((s) => s.host.id == widget.host.id);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_isConnected(context)) return;
    final ssh = context.read<SshService>();
    _statsService = SystemStatsService(
      host: widget.host, sshService: ssh,
      onUpdate: (s) { if (mounted) setState(() => _snapshot = s); },
    );
    _firewallService = FirewallStatusService(
      host: widget.host, sshService: ssh,
      onUpdate: (f) { if (mounted) setState(() => _firewall = f); },
    );
    _statsService!.start();
    _firewallService!.start();
    // Deliver first reading immediately instead of waiting for the first tick.
    _statsService!.poll();
    _firewallService!.poll();
  }

  @override
  void dispose() {
    _statsService?.stop();
    _firewallService?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _isConnected(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Column(children: [
          _handle(),
          _header(),
          Expanded(
            child: isConnected
                ? _body(ctrl)
                : _notConnected(),
          ),
        ]),
      ),
    );
  }

  Widget _handle() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          Text(widget.host.label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_snapshot != null)
            Row(children: [
              Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('Live',
                  style: TextStyle(color: AppColors.accent, fontSize: 11)),
            ]),
        ]),
      );

  Widget _notConnected() => const Center(
        child: Text('No active session — open a terminal first',
            style: TextStyle(color: AppColors.textSecondary)),
      );

  Widget _body(ScrollController ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _sectionTitle('SYSTEM'),
          _snapshot == null
              ? const Center(child: CircularProgressIndicator())
              : _systemSection(_snapshot!),
          const SizedBox(height: 16),
          _sectionTitle('PORTS'),
          _snapshot == null
              ? const Center(child: CircularProgressIndicator())
              : _portsSection(_snapshot!.ports),
          const SizedBox(height: 16),
          _sectionTitle('FIREWALL'),
          _firewall == null
              ? const Center(child: CircularProgressIndicator())
              : _firewallSection(_firewall!),
        ],
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11, letterSpacing: 0.8)),
      );

  Widget _systemSection(SystemSnapshot s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statRow('Uptime', SystemSnapshot.formatUptime(s.uptime)),
          const SizedBox(height: 6),
          _barRow('CPU', s.cpuPercent / 100,
              '${s.cpuPercent.toStringAsFixed(1)}%'),
          const SizedBox(height: 6),
          _barRow(
            'Memory',
            s.totalMemBytes == 0 ? 0 : s.usedMemBytes / s.totalMemBytes,
            '${SystemSnapshot.formatBytes(s.usedMemBytes)} / ${SystemSnapshot.formatBytes(s.totalMemBytes)}',
          ),
          ...s.disks.map((d) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _barRow(
                  d.mountPoint,
                  d.usedPercent,
                  '${d.usedPercent * 100 ~/ 1}% of ${SystemSnapshot.formatBytes(d.totalKb * 1024)}',
                ),
              )),
        ],
      );

  Widget _statRow(String label, String value) => Row(children: [
        SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        Text(value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
      ]);

  Widget _barRow(String label, double fraction, String right) => Row(children: [
        SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFF2A2A2A),
              color: fraction > 0.85 ? AppColors.red : AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(right,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ]);

  Widget _portsSection(List<PortEntry> ports) {
    if (ports.isEmpty) {
      return const Text('No listening ports detected',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12));
    }
    return Column(
      children: ports
          .map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(
                      width: 32,
                      child: Text(p.protocol,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11,
                              fontFamily: 'monospace'))),
                  SizedBox(
                      width: 80,
                      child: Text(':${p.localPort}',
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 12,
                              fontFamily: 'monospace'))),
                  Expanded(
                      child: Text(p.process ?? '—',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis)),
                ]),
              ))
          .toList(),
    );
  }

  Widget _firewallSection(FirewallStatus fw) {
    if (fw.type == FirewallType.none) {
      return const Text('No firewall detected',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _chip(fw.type.name,
              fw.enabled ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 8),
          _chip(fw.enabled ? 'active' : 'inactive',
              fw.enabled ? AppColors.accent : AppColors.red),
          if (fw.defaultInboundPolicy != null) ...[
            const SizedBox(width: 8),
            Text('default inbound: ${fw.defaultInboundPolicy}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ]),
        if (fw.rules.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...fw.rules.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(r.description,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 11,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              )),
        ],
      ],
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 11)),
      );
}
```

- [ ] **Step 4: Run tests**

```bash
cd app && flutter test test/widgets/server_monitor_sheet_test.dart
```

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/server_monitor_sheet.dart app/test/widgets/server_monitor_sheet_test.dart
git commit -m "feat(monitor): ServerMonitorSheet — draggable bottom sheet with CPU/mem/disk/ports/firewall"
```

---

## Task 6: Wire into HostsDashboard

**Files:**
- Modify: `app/lib/widgets/hosts_dashboard.dart`

- [ ] **Step 1: Add the monitor button to `_trailing()` (inside `_HostCardState`)**

In `hosts_dashboard.dart`, find the `_trailing()` method (~line 1047). After the SFTP button and before the "More" button, insert the monitor button — visible only when the host has an active SSH session and it's an SSH host:

```dart
// In _trailing(), inside the `if (!widget.selectionMode && _hovered && !_testing && _testResult == null)` block,
// add after the SFTP _iconBtn and before the 'More' _iconBtn:
if (isSsh && context.read<SessionProvider>().sshSessions.containsKey(widget.host.id)) ...[
  _iconBtn(Icons.monitor_heart_outlined, 'Monitor',
      onTap: () => ServerMonitorSheet.show(context, widget.host)),
  const SizedBox(width: 2),
],
```

The full updated block in `_trailing()`:
```dart
if (!widget.selectionMode && _hovered && !_testing && _testResult == null) ...[
  if (isSsh) ...[
    _iconBtn(Icons.network_check, 'Test Connection', onTap: _test),
    const SizedBox(width: 2),
    _iconBtn(Icons.folder_outlined, 'SFTP', onTap: () => _openSftp(context)),
    const SizedBox(width: 2),
    if (context.read<SessionProvider>().sshSessions.any((s) => s.host.id == widget.host.id)) ...[
      _iconBtn(Icons.monitor_heart_outlined, 'Monitor',
          onTap: () => ServerMonitorSheet.show(context, widget.host)),
      const SizedBox(width: 2),
    ],
  ],
  _iconBtn(Icons.more_horiz, 'More',
      onTapDown: (d) => _showMenu(context, d.globalPosition)),
],
```

- [ ] **Step 2: Add "Monitor" item to the context menu (`_showMenu()`)**

In `_showMenu()`, after the `if (isSsh) _menuItem('sftp', ...)` line, add:

```dart
_menuItem('monitor', Icons.monitor_heart_outlined, 'Monitor',
    () => ServerMonitorSheet.show(context, widget.host)),
```

Full updated items list in `_showMenu()`:
```dart
items: <PopupMenuEntry<String>>[
  _menuItem('terminal', Icons.terminal, 'Connect',
      () => sessionProvider.connectAny(widget.host)),
  if (isSsh)
    _menuItem('sftp', Icons.folder_outlined, 'SFTP',
        () => _openSftp(context)),
  if (isSsh)
    _menuItem('monitor', Icons.monitor_heart_outlined, 'Monitor',
        () => ServerMonitorSheet.show(context, widget.host)),
  _menuItem('edit', Icons.edit_outlined, 'Edit',
      () => widget.onEditHost?.call(widget.host)),
  const PopupMenuDivider(),
  _menuItem('duplicate', Icons.copy_outlined, 'Duplicate',
      () => _duplicate(context, hostProvider)),
  _menuItem('copy_url', Icons.link_outlined,
      isSsh ? 'Copy SSH URL' : 'Copy RDP URL',
      () => _copyHostUrl(context)),
  _menuItem('move_group', Icons.drive_file_move_outlined, 'Move to Group',
      () => _moveToGroup(context, hostProvider)),
  _menuItem('export', Icons.upload_outlined, 'Export',
      () => _export(context)),
  const PopupMenuDivider(),
  _menuItem('delete', Icons.delete_outlined, 'Delete',
      () => hostProvider.deleteHost(widget.host.id), color: AppColors.red),
],
```

- [ ] **Step 3: Add the import at the top of `hosts_dashboard.dart`**

```dart
import 'server_monitor_sheet.dart';
```

- [ ] **Step 4: Analyze and run all tests**

```bash
cd app && flutter analyze && flutter test
```

Expected: No analysis errors, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/hosts_dashboard.dart
git commit -m "feat(monitor): wire ServerMonitorSheet into host card hover button + context menu"
```

---

## Task 7: Run all tests + final check

- [ ] **Step 1: Run full test suite**

```bash
cd app && flutter test
```

Expected: All tests pass, no regressions.

- [ ] **Step 2: Run analyzer**

```bash
cd app && flutter analyze
```

Expected: No issues.

- [ ] **Step 3: Verify the feature compiles for macOS**

```bash
cd app && flutter build macos --debug 2>&1 | tail -5
```

Expected: `Build complete.` (or similar, no errors).

- [ ] **Step 4: Final commit (if any lint fixes were needed)**

```bash
git add -p
git commit -m "chore(monitor): lint fixes from analyzer"
```

Only needed if Step 2 found issues.
