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
      expect(s.usedMemBytes, (16384000 - 9216000) * 1024);
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
      expect(s.ports.length, 1);
      expect(s.ports.first.localPort, 22);
    });

    test('DiskMount.usedPercent is clamped 0..1', () {
      final d = DiskMount(source: '/dev/sda1', mountPoint: '/', totalKb: 100, usedKb: 55);
      expect(d.usedPercent, closeTo(0.55, 0.01));
      final empty = DiskMount(source: '/dev/sda1', mountPoint: '/', totalKb: 0, usedKb: 0);
      expect(empty.usedPercent, 0.0);
    });

    test('formatUptime renders days/hours/minutes', () {
      expect(SystemSnapshot.formatUptime(const Duration(days: 14, hours: 3, minutes: 22)), '14d 3h 22m');
      expect(SystemSnapshot.formatUptime(const Duration(minutes: 5)), '5m');
      expect(SystemSnapshot.formatUptime(const Duration(hours: 2)), '2h 0m');
    });

    test('formatBytes scales correctly', () {
      expect(SystemSnapshot.formatBytes(500), '500 B');
      expect(SystemSnapshot.formatBytes(2048), '2.0 KB');
      expect(SystemSnapshot.formatBytes(3 * 1024 * 1024), '3.0 MB');
      expect(SystemSnapshot.formatBytes(2 * 1024 * 1024 * 1024), '2.0 GB');
    });
  });
}
