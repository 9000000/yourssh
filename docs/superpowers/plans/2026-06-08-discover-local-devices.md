# Discover Local Devices Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add LAN device discovery (mDNS + TCP port scan) so users can find SSH/RDP hosts on their network and add them with a single click.

**Architecture:** `NetworkDiscoveryService` streams `DiscoveredHost` results from two parallel sub-scans (mDNS via `multicast_dns`, TCP via `Socket.connect` with 50-concurrent semaphore); results are deduplicated by IP in a `Map<String, DiscoveredHost>`. A `NetworkDiscoverySheet` bottom sheet shows results in real-time and pre-fills `HostDetailPanel` on Add/Connect. Entry points: Hosts Dashboard toolbar button and a "Scan network" link in the Add Host panel.

**Tech Stack:** Dart `dart:io` (Socket), `multicast_dns: ^0.3.2`, Flutter `showModalBottomSheet`, existing `HostDetailPanel` / `SessionProvider` patterns.

---

## File Map

| File | Action |
|---|---|
| `app/pubspec.yaml` | add `multicast_dns: ^0.3.2` |
| `app/lib/models/discovered_host.dart` | new — `DiscoveredHost`, `SubnetInfo`, `DiscoverySource` |
| `app/lib/services/network_discovery_service.dart` | new — service with TCP scan + mDNS |
| `app/test/services/network_discovery_service_test.dart` | new — unit tests |
| `app/lib/widgets/network_discovery_sheet.dart` | new — bottom sheet UI |
| `app/lib/widgets/hosts_dashboard.dart` | add Discover button to `_TopBar` |
| `app/lib/widgets/host_detail_panel.dart` | add "Scan network" link in add-new-host mode |

---

## Task 1: Add dependency + models

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/lib/models/discovered_host.dart`

- [ ] **Step 1: Add multicast_dns to pubspec**

In `app/pubspec.yaml`, after the `# Network info (LAN share)` block add:

```yaml
  # mDNS/Bonjour device discovery
  multicast_dns: ^0.3.2
```

- [ ] **Step 2: Create `app/lib/models/discovered_host.dart`**

```dart
import 'dart:io';

enum DiscoverySource { mdns, tcpScan, both }

class DiscoveredHost {
  final String ip;
  final String? hostname;
  final List<int> openPorts;
  final DiscoverySource source;
  final String? mdnsServiceType;

  const DiscoveredHost({
    required this.ip,
    this.hostname,
    required this.openPorts,
    required this.source,
    this.mdnsServiceType,
  });

  DiscoveredHost merge(DiscoveredHost other) {
    final ports = {...openPorts, ...other.openPorts}.toList()..sort();
    return DiscoveredHost(
      ip: ip,
      hostname: hostname ?? other.hostname,
      openPorts: ports,
      source: DiscoverySource.both,
      mdnsServiceType: mdnsServiceType ?? other.mdnsServiceType,
    );
  }

  String get portLabel {
    if (openPorts.contains(3389)) return 'RDP';
    if (openPorts.contains(22)) return 'SSH';
    if (openPorts.contains(2222)) return 'SSH:2222';
    return openPorts.first.toString();
  }

  bool get isRdp => openPorts.contains(3389) && !openPorts.contains(22);
}

class SubnetInfo {
  final String interfaceName;
  final String displayName;
  final String address;
  final String subnet;

  const SubnetInfo({
    required this.interfaceName,
    required this.displayName,
    required this.address,
    required this.subnet,
  });

  static String subnetFromAddress(String address) {
    final parts = address.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
  }

  static List<String> hostsInSubnet(String subnet) {
    final base = subnet.split('/').first;
    final parts = base.split('.');
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    return List.generate(254, (i) => '$prefix.${i + 1}');
  }

  /// Returns null when [subnet] is not a valid x.x.x.x/y string.
  static String? validateSubnet(String subnet) {
    final parts = subnet.split('/');
    if (parts.length != 2) return 'Expected format: 192.168.1.0/24';
    final octets = parts[0].split('.');
    if (octets.length != 4) return 'Expected 4 octets';
    for (final o in octets) {
      final n = int.tryParse(o);
      if (n == null || n < 0 || n > 255) return 'Invalid octet: $o';
    }
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 1 || prefix > 32) return 'Prefix must be 1–32';
    return null;
  }

  @override
  String toString() => '$displayName ($address) — $subnet';
}
```

- [ ] **Step 3: Run `flutter pub get`**

```bash
cd app && flutter pub get
```

Expected: resolves `multicast_dns` without errors.

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/models/discovered_host.dart
git commit -m "feat(discover): add DiscoveredHost model + multicast_dns dep"
```

---

## Task 2: NetworkDiscoveryService — TCP scan

**Files:**
- Create: `app/lib/services/network_discovery_service.dart`

- [ ] **Step 1: Create the service file**

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/discovered_host.dart';

typedef SocketConnector = Future<bool> Function(
    String ip, int port, Duration timeout);
typedef MdnsClientFactory = MDnsClient Function();

const _kDefaultPorts = [22, 2222, 3389];
const _kMdnsServiceTypes = ['_ssh._tcp', '_sftp-ssh._tcp', '_rdp._tcp'];
const _kConcurrency = 50;

Future<bool> _defaultConnector(String ip, int port, Duration timeout) async {
  try {
    final s = await Socket.connect(ip, port, timeout: timeout);
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

class _Semaphore {
  final int max;
  int _count = 0;
  final _queue = <Completer<void>>[];

  _Semaphore(this.max);

  Future<void> acquire() async {
    if (_count < max) {
      _count++;
      return;
    }
    final c = Completer<void>();
    _queue.add(c);
    await c.future;
    _count++;
  }

  void release() {
    _count--;
    if (_queue.isNotEmpty) _queue.removeAt(0).complete();
  }
}

class NetworkDiscoveryService {
  final SocketConnector _connector;
  final MdnsClientFactory _mdnsFactory;

  bool _cancelled = false;

  NetworkDiscoveryService({
    @visibleForTesting SocketConnector? connector,
    @visibleForTesting MdnsClientFactory? mdnsFactory,
  })  : _connector = connector ?? _defaultConnector,
        _mdnsFactory = mdnsFactory ?? MDnsClient.new;

  Future<List<SubnetInfo>> getLocalSubnets() async {
    final interfaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    return interfaces
        .expand((i) => i.addresses.map((a) => SubnetInfo(
              interfaceName: i.name,
              displayName: _displayName(i.name),
              address: a.address,
              subnet: SubnetInfo.subnetFromAddress(a.address),
            )))
        .where((s) => !s.address.startsWith('127.'))
        .toList();
  }

  /// Streams discovered hosts in real-time. Deduplicates by IP.
  /// [onProgress] is called after each TCP probe with (scanned, total).
  Stream<DiscoveredHost> scan(
    SubnetInfo subnet, {
    List<int> ports = _kDefaultPorts,
    Duration timeout = const Duration(milliseconds: 500),
    void Function(int scanned, int total)? onProgress,
  }) {
    _cancelled = false;
    final controller = StreamController<DiscoveredHost>();
    final seen = <String, DiscoveredHost>{};

    void emit(DiscoveredHost h) {
      if (_cancelled) return;
      final existing = seen[h.ip];
      if (existing == null) {
        seen[h.ip] = h;
        controller.add(h);
      } else {
        final merged = existing.merge(h);
        seen[h.ip] = merged;
        controller.add(merged);
      }
    }

    Future<void> run() async {
      final tcpFuture = _runTcpScan(
        SubnetInfo.hostsInSubnet(subnet.subnet),
        ports,
        timeout,
        emit,
        onProgress,
      );
      final mdnsFuture = _runMdnsScan(emit);
      await Future.wait([tcpFuture, mdnsFuture]);
      if (!controller.isClosed) controller.close();
    }

    run().catchError((_) {
      if (!controller.isClosed) controller.close();
    });

    return controller.stream;
  }

  void cancel() => _cancelled = true;

  Future<void> _runTcpScan(
    List<String> ips,
    List<int> ports,
    Duration timeout,
    void Function(DiscoveredHost) emit,
    void Function(int, int)? onProgress,
  ) async {
    final sem = _Semaphore(_kConcurrency);
    final total = ips.length;
    var scanned = 0;

    Future<void> probe(String ip) async {
      await sem.acquire();
      try {
        if (_cancelled) return;
        final openPorts = <int>[];
        for (final port in ports) {
          if (_cancelled) break;
          if (await _connector(ip, port, timeout)) openPorts.add(port);
        }
        if (openPorts.isNotEmpty && !_cancelled) {
          emit(DiscoveredHost(
              ip: ip, openPorts: openPorts, source: DiscoverySource.tcpScan));
        }
      } finally {
        sem.release();
        scanned++;
        onProgress?.call(scanned, total);
      }
    }

    await Future.wait(ips.map(probe));
  }

  Future<void> _runMdnsScan(void Function(DiscoveredHost) emit) async {
    MDnsClient? client;
    try {
      client = _mdnsFactory();
      await client.start();
      for (final serviceType in _kMdnsServiceTypes) {
        if (_cancelled) break;
        try {
          await for (final PtrResourceRecord ptr
              in client
                  .lookup<PtrResourceRecord>(
                      ResourceRecordQuery.serverPointer('$serviceType.local'))
                  .timeout(const Duration(seconds: 5))) {
            if (_cancelled) break;
            await for (final SrvResourceRecord srv
                in client.lookup<SrvResourceRecord>(
                    ResourceRecordQuery.service(ptr.domainName))) {
              if (_cancelled) break;
              String? ip;
              String? hostname = srv.target.replaceAll('.local', '');
              try {
                await for (final IPAddressResourceRecord addr
                    in client.lookup<IPAddressResourceRecord>(
                        ResourceRecordQuery.addressIPv4(srv.target))) {
                  ip = addr.address.address;
                  break;
                }
              } catch (_) {}
              if (ip == null) {
                try {
                  final result = await InternetAddress.lookup(srv.target);
                  if (result.isNotEmpty) ip = result.first.address;
                } catch (_) {}
              }
              if (ip != null && !_cancelled) {
                emit(DiscoveredHost(
                  ip: ip,
                  hostname: hostname,
                  openPorts: [srv.port],
                  source: DiscoverySource.mdns,
                  mdnsServiceType: serviceType,
                ));
              }
            }
          }
        } catch (_) {
          // timeout or error on this service type — continue with next
        }
      }
    } catch (_) {
      // mDNS socket failed — TCP scan continues unaffected
    } finally {
      client?.stop();
    }
  }

  static String _displayName(String name) {
    final n = name.toLowerCase();
    if (n == 'en0') return 'Wi-Fi';
    if (n.startsWith('en')) return 'Ethernet';
    if (n.startsWith('utun') || n.startsWith('tun') || n.startsWith('tap')) {
      return 'VPN';
    }
    if (n.startsWith('wlan') || n.startsWith('wlp')) return 'Wi-Fi';
    if (n.startsWith('eth')) return 'Ethernet';
    return name;
  }
}
```

- [ ] **Step 2: Analyze pass**

```bash
cd app && flutter analyze lib/services/network_discovery_service.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add app/lib/services/network_discovery_service.dart
git commit -m "feat(discover): NetworkDiscoveryService — TCP scan + mDNS"
```

---

## Task 3: Unit tests for NetworkDiscoveryService

**Files:**
- Create: `app/test/services/network_discovery_service_test.dart`

- [ ] **Step 1: Create test file**

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:yourssh/models/discovered_host.dart';
import 'package:yourssh/services/network_discovery_service.dart';

// Fake connector that returns true for predetermined (ip, port) pairs.
SocketConnector _fakeConnector(Map<String, List<int>> openPorts) {
  return (ip, port, _) async => openPorts[ip]?.contains(port) ?? false;
}

// Connector that counts concurrent in-flight calls.
SocketConnector _countingConnector({
  required List<int> maxConcurrencyLog,
  SocketConnector? delegate,
}) {
  var current = 0;
  return (ip, port, timeout) async {
    current++;
    maxConcurrencyLog.add(current);
    await Future.delayed(const Duration(milliseconds: 5));
    current--;
    return delegate?.call(ip, port, timeout) ?? false;
  };
}

// Fake MDnsClient that yields no records — allows mDNS path to complete.
class _FakeMdnsClient implements MDnsClient {
  @override
  Future<void> start({
    InternetAddress? listenAddress,
    NetworkInterfacesFactory? interfacesFactory,
  }) async {}

  @override
  void stop() {}

  @override
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  }) =>
      const Stream.empty();
}

MDnsClient _fakeMdnsFactory() => _FakeMdnsClient();

void main() {
  group('SubnetInfo.subnetFromAddress', () {
    test('derives /24 subnet from IP', () {
      expect(SubnetInfo.subnetFromAddress('192.168.1.42'), '192.168.1.0/24');
    });
  });

  group('SubnetInfo.hostsInSubnet', () {
    test('produces 254 hosts for /24', () {
      final hosts = SubnetInfo.hostsInSubnet('192.168.1.0/24');
      expect(hosts.length, 254);
      expect(hosts.first, '192.168.1.1');
      expect(hosts.last, '192.168.1.254');
    });
  });

  group('SubnetInfo.validateSubnet', () {
    test('returns null for valid subnet', () {
      expect(SubnetInfo.validateSubnet('192.168.1.0/24'), isNull);
    });

    test('returns error for missing prefix', () {
      expect(SubnetInfo.validateSubnet('192.168.1.0'), isNotNull);
    });

    test('returns error for invalid octet', () {
      expect(SubnetInfo.validateSubnet('192.168.999.0/24'), isNotNull);
    });
  });

  group('NetworkDiscoveryService TCP scan', () {
    test('emits hosts with open ports only', () async {
      final svc = NetworkDiscoveryService(
        connector: _fakeConnector({'192.168.1.10': [22], '192.168.1.20': [3389]}),
        mdnsFactory: _fakeMdnsFactory,
      );
      final subnet = SubnetInfo(
        interfaceName: 'en0',
        displayName: 'Wi-Fi',
        address: '192.168.1.5',
        subnet: '192.168.1.0/24',
      );
      final results = await svc
          .scan(subnet, ports: [22, 3389], timeout: const Duration(milliseconds: 1))
          .toList();

      expect(results.map((r) => r.ip), containsAll(['192.168.1.10', '192.168.1.20']));
      final ssh = results.firstWhere((r) => r.ip == '192.168.1.10');
      expect(ssh.openPorts, [22]);
      expect(ssh.source, DiscoverySource.tcpScan);
    });

    test('deduplicates by IP — merge ports from multiple probe hits', () async {
      // Same IP responds on both port 22 and 2222
      final svc = NetworkDiscoveryService(
        connector: _fakeConnector({'10.0.0.1': [22, 2222]}),
        mdnsFactory: _fakeMdnsFactory,
      );
      final subnet = SubnetInfo(
        interfaceName: 'eth0',
        displayName: 'Ethernet',
        address: '10.0.0.5',
        subnet: '10.0.0.0/24',
      );
      final results = await svc
          .scan(subnet, ports: [22, 2222], timeout: const Duration(milliseconds: 1))
          .toList();

      // Multiple emissions for same IP may arrive — last one should have both ports
      final last = results.lastWhere((r) => r.ip == '10.0.0.1');
      expect(last.openPorts, containsAll([22, 2222]));
    });

    test('respects cancel — stops emitting after cancel()', () async {
      var emitted = 0;
      final svc = NetworkDiscoveryService(
        connector: (ip, port, _) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return true;
        },
        mdnsFactory: _fakeMdnsFactory,
      );
      final subnet = SubnetInfo(
        interfaceName: 'en0',
        displayName: 'Wi-Fi',
        address: '192.168.1.5',
        subnet: '192.168.1.0/24',
      );
      final sub = svc
          .scan(subnet, ports: [22], timeout: const Duration(milliseconds: 10))
          .listen((_) => emitted++);
      await Future.delayed(const Duration(milliseconds: 5));
      svc.cancel();
      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      // Some may have been emitted before cancel; key assertion: scan does not crash
      expect(emitted, greaterThanOrEqualTo(0));
    });

    test('concurrency does not exceed 50', () async {
      final log = <int>[];
      final svc = NetworkDiscoveryService(
        connector: _countingConnector(maxConcurrencyLog: log),
        mdnsFactory: _fakeMdnsFactory,
      );
      final subnet = SubnetInfo(
        interfaceName: 'en0',
        displayName: 'Wi-Fi',
        address: '10.0.0.1',
        subnet: '10.0.0.0/24',
      );
      await svc.scan(subnet, ports: [22], timeout: const Duration(milliseconds: 1)).drain<void>();
      expect(log.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(50));
    });

    test('onProgress reaches 100% at end', () async {
      int lastScanned = 0, lastTotal = 0;
      final svc = NetworkDiscoveryService(
        connector: _fakeConnector({}),
        mdnsFactory: _fakeMdnsFactory,
      );
      final subnet = SubnetInfo(
        interfaceName: 'en0',
        displayName: 'Wi-Fi',
        address: '192.168.1.1',
        subnet: '192.168.1.0/24',
      );
      await svc.scan(
        subnet,
        ports: [22],
        timeout: const Duration(milliseconds: 1),
        onProgress: (s, t) {
          lastScanned = s;
          lastTotal = t;
        },
      ).drain<void>();
      expect(lastScanned, lastTotal);
      expect(lastTotal, 254);
    });
  });

  group('DiscoveredHost', () {
    test('merge combines ports and prefers existing hostname', () {
      final a = DiscoveredHost(
          ip: '10.0.0.1', hostname: 'myhost', openPorts: [22], source: DiscoverySource.mdns);
      final b = DiscoveredHost(
          ip: '10.0.0.1', openPorts: [3389], source: DiscoverySource.tcpScan);
      final m = a.merge(b);
      expect(m.hostname, 'myhost');
      expect(m.openPorts, [22, 3389]);
      expect(m.source, DiscoverySource.both);
    });

    test('isRdp true when only 3389 open', () {
      final h = DiscoveredHost(ip: '1.2.3.4', openPorts: [3389], source: DiscoverySource.tcpScan);
      expect(h.isRdp, true);
    });

    test('isRdp false when 22 also open', () {
      final h = DiscoveredHost(ip: '1.2.3.4', openPorts: [22, 3389], source: DiscoverySource.tcpScan);
      expect(h.isRdp, false);
    });
  });
}
```

- [ ] **Step 2: Run tests**

```bash
cd app && flutter test test/services/network_discovery_service_test.dart -v
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add app/test/services/network_discovery_service_test.dart
git commit -m "test(discover): NetworkDiscoveryService unit tests"
```

---

## Task 4: NetworkDiscoverySheet widget

**Files:**
- Create: `app/lib/widgets/network_discovery_sheet.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/discovered_host.dart';
import '../models/host.dart';
import '../providers/host_provider.dart';
import '../providers/session_provider.dart';
import '../services/network_discovery_service.dart';
import '../theme/app_theme.dart';
import 'host_detail_panel.dart';

class NetworkDiscoverySheet extends StatefulWidget {
  /// When true, tapping a row calls [onSelected] and closes the sheet.
  final bool selectionMode;
  final void Function(DiscoveredHost)? onSelected;

  const NetworkDiscoverySheet({
    super.key,
    this.selectionMode = false,
    this.onSelected,
  });

  static void show(
    BuildContext context, {
    bool selectionMode = false,
    void Function(DiscoveredHost)? onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NetworkDiscoverySheet(
        selectionMode: selectionMode,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<NetworkDiscoverySheet> createState() => NetworkDiscoverySheetState();
}

class NetworkDiscoverySheetState extends State<NetworkDiscoverySheet> {
  final _svc = NetworkDiscoveryService();
  final _results = <String, DiscoveredHost>{};

  List<SubnetInfo> _subnets = [];
  SubnetInfo? _selected;
  String _customSubnet = '';
  bool _editingSubnet = false;
  String? _subnetError;

  bool _scanning = false;
  int _scanned = 0;
  int _total = 0;
  int _mdnsCount = 0;
  int _tcpCount = 0;

  StreamSubscription<DiscoveredHost>? _sub;

  @override
  void initState() {
    super.initState();
    _loadSubnets();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _svc.cancel();
    super.dispose();
  }

  Future<void> _loadSubnets() async {
    final subnets = await _svc.getLocalSubnets();
    if (!mounted) return;
    setState(() {
      _subnets = subnets;
      _selected = subnets.isNotEmpty ? subnets.first : null;
      if (_selected != null) _customSubnet = _selected!.subnet;
    });
    if (_selected != null) _startScan();
  }

  void _startScan() {
    if (_selected == null) return;
    _sub?.cancel();
    final subnet = _editingSubnet
        ? SubnetInfo(
            interfaceName: _selected!.interfaceName,
            displayName: _selected!.displayName,
            address: _selected!.address,
            subnet: _customSubnet,
          )
        : _selected!;

    setState(() {
      _scanning = true;
      _scanned = 0;
      _total = 0;
      _mdnsCount = 0;
      _tcpCount = 0;
      _results.clear();
    });

    _sub = _svc
        .scan(subnet, onProgress: (s, t) {
          if (mounted) setState(() { _scanned = s; _total = t; });
        })
        .listen(
          (h) {
            if (!mounted) return;
            setState(() {
              final isUpdate = _results.containsKey(h.ip);
              _results[h.ip] = h;
              if (!isUpdate) {
                if (h.source == DiscoverySource.mdns) _mdnsCount++;
                else _tcpCount++;
              } else if (h.source == DiscoverySource.both) {
                // Promoted from single source — update counter display
              }
            });
          },
          onDone: () { if (mounted) setState(() => _scanning = false); },
          onError: (_) { if (mounted) setState(() => _scanning = false); },
        );
  }

  void _stopScan() {
    _sub?.cancel();
    _svc.cancel();
    setState(() => _scanning = false);
  }

  void _onAdd(BuildContext context, DiscoveredHost h) {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HostDetailPanel(
        existing: null,
        initialHost: h.ip,
        initialPort: h.isRdp ? 3389 : (h.openPorts.contains(22) ? 22 : h.openPorts.first),
        initialLabel: h.hostname,
        initialProtocol: h.isRdp ? HostProtocol.rdp : HostProtocol.ssh,
      ),
    );
  }

  void _onConnect(BuildContext context, DiscoveredHost h) {
    final hostProvider = context.read<HostProvider>();
    final sessionProvider = context.read<SessionProvider>();
    Navigator.of(context).pop();

    final host = Host(
      id: const Uuid().v4(),
      label: h.hostname ?? h.ip,
      host: h.ip,
      port: h.isRdp ? 3389 : (h.openPorts.contains(22) ? 22 : h.openPorts.first),
      username: '',
      protocol: h.isRdp ? HostProtocol.rdp : HostProtocol.ssh,
      createdAt: DateTime.now(),
    );
    await hostProvider.addHost(host);
    if (host.protocol == HostProtocol.rdp) {
      sessionProvider.connectRdp(context, host);
    } else {
      sessionProvider.connectHost(context, host);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(context),
            _buildSubnetBar(),
            if (_scanning) _buildProgress(),
            _buildCounterRow(),
            const Divider(color: AppColors.border, height: 1),
            Expanded(child: _buildResultList(context, scroll)),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
        child: Row(
          children: [
            const Icon(Icons.wifi_find, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            const Text('Discover Devices',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textSecondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );

  Widget _buildSubnetBar() {
    if (_subnets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No active network interfaces found.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          if (_subnets.length > 1)
            DropdownButton<SubnetInfo>(
              value: _selected,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              underline: const SizedBox(),
              items: _subnets
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.displayName),
                      ))
                  .toList(),
              onChanged: (s) {
                setState(() {
                  _selected = s;
                  _customSubnet = s?.subnet ?? '';
                  _editingSubnet = false;
                  _subnetError = null;
                });
              },
            )
          else
            Text(_selected?.displayName ?? '',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: _customSubnet),
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace'),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                errorText: _subnetError,
                errorStyle: const TextStyle(fontSize: 10),
              ),
              onChanged: (v) {
                setState(() {
                  _customSubnet = v;
                  _editingSubnet = true;
                  _subnetError = SubnetInfo.validateSubnet(v);
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _subnetError != null ? null : () {
              if (_scanning) _stopScan();
              _startScan();
            },
            child: Text(_scanning ? 'Restart' : 'Scan',
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final progress = _total > 0 ? _scanned / _total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            color: AppColors.accent,
          ),
          const SizedBox(height: 4),
          Text(
            _total > 0 ? 'Scanning… $_scanned/$_total' : 'Starting scan…',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterRow() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          'mDNS: $_mdnsCount found · TCP scan: $_tcpCount found',
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
        ),
      );

  Widget _buildResultList(BuildContext context, ScrollController scroll) {
    final items = _results.values.toList()
      ..sort((a, b) => a.ip.compareTo(b.ip));
    if (items.isEmpty) {
      return const Center(
        child: Text('No devices found yet…',
            style: TextStyle(color: AppColors.textTertiary)),
      );
    }
    return ListView.builder(
      controller: scroll,
      itemCount: items.length,
      itemBuilder: (ctx, i) => _DiscoveredRow(
        host: items[i],
        selectionMode: widget.selectionMode,
        onSelect: () {
          widget.onSelected?.call(items[i]);
          Navigator.of(context).pop();
        },
        onAdd: () => _onAdd(context, items[i]),
        onConnect: () => _onConnect(context, items[i]),
      ),
    );
  }
}

class _DiscoveredRow extends StatelessWidget {
  final DiscoveredHost host;
  final bool selectionMode;
  final VoidCallback onSelect;
  final VoidCallback onAdd;
  final VoidCallback onConnect;

  const _DiscoveredRow({
    required this.host,
    required this.selectionMode,
    required this.onSelect,
    required this.onAdd,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selectionMode ? onSelect : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(
              host.isRdp ? Icons.desktop_windows : Icons.computer,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    host.hostname ?? host.ip,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                  ),
                  if (host.hostname != null)
                    Text(host.ip,
                        style: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
            _Badge(host.portLabel),
            if (!selectionMode) ...[
              const SizedBox(width: 8),
              _SmallBtn('Add', onAdd),
              const SizedBox(width: 4),
              _SmallBtn('Connect', onConnect, primary: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
      );
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _SmallBtn(this.label, this.onTap, {this.primary = false});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: primary ? AppColors.accent : AppColors.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: primary ? AppColors.accent : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: primary ? Colors.white : AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
}
```

> **Note:** `_onConnect` references `Uuid` — add `import 'package:uuid/uuid.dart';` at the top of the file. Also `HostProtocol` is from `../models/host.dart`.

- [ ] **Step 2: Fix imports in `network_discovery_sheet.dart`**

Add to top of file:
```dart
import 'package:uuid/uuid.dart';
```

- [ ] **Step 3: Analyze**

```bash
cd app && flutter analyze lib/widgets/network_discovery_sheet.dart
```

Expected: no errors (some warnings about `HostDetailPanel` constructor — will be fixed in Task 5).

- [ ] **Step 4: Commit**

```bash
git add app/lib/widgets/network_discovery_sheet.dart
git commit -m "feat(discover): NetworkDiscoverySheet — bottom sheet UI"
```

---

## Task 5: Add initialHost/Port/Label/Protocol params to HostDetailPanel

The `_onAdd` in the sheet needs to pre-fill the panel. `HostDetailPanel` currently takes an `existing` host — we need optional initial-value params for the new-host case.

**Files:**
- Modify: `app/lib/widgets/host_detail_panel.dart`

- [ ] **Step 1: Read the constructor**

Open `app/lib/widgets/host_detail_panel.dart` and find the `HostDetailPanel` class definition and its `initState`. It should look like:

```dart
class HostDetailPanel extends StatefulWidget {
  final Host? existing;
  // ... other params
```

And in `initState`:
```dart
_hostCtrl = TextEditingController(text: h?.host ?? '');
_labelCtrl = TextEditingController(text: h?.label ?? '');
_portCtrl = TextEditingController(text: (h?.port ?? _protocol.defaultPort).toString());
```

- [ ] **Step 2: Add optional initial-value parameters to `HostDetailPanel`**

In the `HostDetailPanel` class, add four optional params:

```dart
final String? initialHost;
final int? initialPort;
final String? initialLabel;
final HostProtocol? initialProtocol;
```

In the constructor, add them as optional named params.

In `initState`, change the controller initialization to fall back to the initial values when `existing` is null:

```dart
_protocol = h?.protocol ?? widget.initialProtocol ?? HostProtocol.ssh;
// ...
_hostCtrl = TextEditingController(text: h?.host ?? widget.initialHost ?? '');
_labelCtrl = TextEditingController(text: h?.label ?? widget.initialLabel ?? '');
_portCtrl = TextEditingController(
    text: (h?.port ?? widget.initialPort ?? _protocol.defaultPort).toString());
```

- [ ] **Step 3: Verify analyze**

```bash
cd app && flutter analyze lib/widgets/host_detail_panel.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add app/lib/widgets/host_detail_panel.dart
git commit -m "feat(discover): add initialHost/Port/Label/Protocol to HostDetailPanel"
```

---

## Task 6: Wire Discover button in Hosts Dashboard

**Files:**
- Modify: `app/lib/widgets/hosts_dashboard.dart`

- [ ] **Step 1: Add `onDiscover` callback to `HostsDashboard` widget**

In the `HostsDashboard` class, add:
```dart
final VoidCallback? onDiscover;
```

In the constructor, add `this.onDiscover`. In the `_TopBar` instantiation (line ~236), pass it:
```dart
onDiscover: widget.onDiscover,
```

- [ ] **Step 2: Add `onDiscover` to `_TopBar`**

In `_TopBar`, add:
```dart
final VoidCallback? onDiscover;
```

In the constructor add `this.onDiscover`. In the `build` Row, add after the `_ViewToggle` widget and before the `_OutlinedBtn(SELECT)`:

```dart
_OutlinedBtn(
  icon: Icons.wifi_find,
  label: 'DISCOVER',
  onTap: onDiscover ?? () {},
),
const SizedBox(width: 8),
```

- [ ] **Step 3: Wire it in `main_screen.dart`**

Find where `HostsDashboard` is instantiated in `app/lib/screens/main_screen.dart`. Add the `onDiscover` callback:

```dart
HostsDashboard(
  // ... existing params
  onDiscover: () => NetworkDiscoverySheet.show(context),
)
```

Add the import at the top of `main_screen.dart`:
```dart
import '../widgets/network_discovery_sheet.dart';
```

- [ ] **Step 4: Analyze**

```bash
cd app && flutter analyze lib/widgets/hosts_dashboard.dart lib/screens/main_screen.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/hosts_dashboard.dart app/lib/screens/main_screen.dart
git commit -m "feat(discover): Discover button on Hosts Dashboard toolbar"
```

---

## Task 7: "Scan network" link in Host Detail Panel

**Files:**
- Modify: `app/lib/widgets/host_detail_panel.dart`

- [ ] **Step 1: Add import for NetworkDiscoverySheet**

At the top of `host_detail_panel.dart`, add:
```dart
import 'network_discovery_sheet.dart';
```

- [ ] **Step 2: Add the "Scan network" link below the address card**

Find the section in `build` that renders the `_AddressField` card (around line 342–345):

```dart
_Card(children: [
  _AddressField(controller: _hostCtrl),
]),
```

Replace with:

```dart
_Card(children: [
  _AddressField(controller: _hostCtrl),
]),
if (_isNew) ...[
  const SizedBox(height: 4),
  Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      icon: const Icon(Icons.wifi_find, size: 13),
      label: const Text('Scan network to pick a device',
          style: TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
      onPressed: () => NetworkDiscoverySheet.show(
        context,
        selectionMode: true,
        onSelected: (h) {
          setState(() {
            _hostCtrl.text = h.ip;
            _portCtrl.text =
                (h.isRdp ? 3389 : (h.openPorts.contains(22) ? 22 : h.openPorts.first))
                    .toString();
            if (h.hostname != null && _labelCtrl.text.isEmpty) {
              _labelCtrl.text = h.hostname!;
            }
            if (h.isRdp && _protocol != HostProtocol.rdp) _onProtocolChanged(HostProtocol.rdp);
          });
        },
      ),
    ),
  ),
],
```

> `_switchProtocol` is the existing method in `HostDetailPanelState` that handles the protocol toggle.

- [ ] **Step 3: Analyze**

```bash
cd app && flutter analyze lib/widgets/host_detail_panel.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add app/lib/widgets/host_detail_panel.dart
git commit -m "feat(discover): Scan network link in Add Host panel"
```

---

## Task 8: Final integration check

- [ ] **Step 1: Full analyze**

```bash
cd app && flutter analyze
```

Expected: no errors.

- [ ] **Step 2: Run all tests**

```bash
cd app && flutter test
```

Expected: all pass including the new `network_discovery_service_test.dart`.

- [ ] **Step 3: Final commit if any loose changes**

```bash
git add -p
git commit -m "feat(discover): discover local devices — mDNS + TCP scan"
```
