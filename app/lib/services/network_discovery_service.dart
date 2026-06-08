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

// fix #4: per-scan cancellation token so restarting a scan doesn't corrupt
// the in-flight goroutines of the previous scan.
class _ScanToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class NetworkDiscoveryService {
  final SocketConnector _connector;
  final MdnsClientFactory _mdnsFactory;

  _ScanToken? _activeToken;

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
              // fix #10: use shared display name from SubnetInfo
              displayName: SubnetInfo.interfaceDisplayName(i.name),
              address: a.address,
              subnet: SubnetInfo.subnetFromAddress(a.address),
            )))
        .where((s) => !s.address.startsWith('127.'))
        .toList();
  }

  /// Streams discovered hosts in real-time. Deduplicates by IP.
  /// [onProgress] fires after each IP is probed with (scanned, total).
  Stream<DiscoveredHost> scan(
    SubnetInfo subnet, {
    List<int> ports = _kDefaultPorts,
    Duration timeout = const Duration(milliseconds: 500),
    void Function(int scanned, int total)? onProgress,
  }) {
    // fix #4: cancel the previous scan's token and create a fresh one
    _activeToken?.cancel();
    final token = _ScanToken();
    _activeToken = token;

    final controller = StreamController<DiscoveredHost>();
    final seen = <String, DiscoveredHost>{};

    void emit(DiscoveredHost h) {
      if (token.isCancelled || controller.isClosed) return;
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
      await Future.wait([
        _runTcpScan(
          SubnetInfo.hostsInSubnet(subnet.subnet),
          ports,
          timeout,
          emit,
          onProgress,
          token,
        ),
        _runMdnsScan(emit, token),
      ]);
      if (!controller.isClosed) controller.close();
    }

    run().catchError((_) {
      if (!controller.isClosed) controller.close();
    });

    return controller.stream;
  }

  void cancel() {
    _activeToken?.cancel();
  }

  Future<void> _runTcpScan(
    List<String> ips,
    List<int> ports,
    Duration timeout,
    void Function(DiscoveredHost) emit,
    void Function(int, int)? onProgress,
    _ScanToken token,
  ) async {
    final sem = _Semaphore(_kConcurrency);
    final total = ips.length;
    var scanned = 0;

    Future<void> probe(String ip) async {
      await sem.acquire();
      try {
        if (token.isCancelled) return;
        final openPorts = <int>[];
        for (final port in ports) {
          if (token.isCancelled) break;
          if (await _connector(ip, port, timeout)) openPorts.add(port);
        }
        if (openPorts.isNotEmpty && !token.isCancelled) {
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

  Future<void> _runMdnsScan(
      void Function(DiscoveredHost) emit, _ScanToken token) async {
    MDnsClient? client;
    try {
      client = _mdnsFactory();
      await client.start();
      // fix #3: scan all three service types in parallel instead of sequentially
      // (sequential with 5s timeout each = up to 15s; parallel = max 5s)
      await Future.wait(_kMdnsServiceTypes
          .map((t) => _scanMdnsServiceType(client!, t, emit, token)));
    } catch (_) {
      // mDNS socket bind failed — TCP scan continues unaffected
    } finally {
      client?.stop();
    }
  }

  Future<void> _scanMdnsServiceType(
    MDnsClient client,
    String serviceType,
    void Function(DiscoveredHost) emit,
    _ScanToken token,
  ) async {
    try {
      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer('$serviceType.local'))
          .timeout(const Duration(seconds: 5))) {
        if (token.isCancelled) break;
        await for (final SrvResourceRecord srv in client
            .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName))) {
          if (token.isCancelled) break;
          String? ip;
          final hostname =
              srv.target.replaceAll(RegExp(r'\.local\.?$'), '');
          try {
            await for (final IPAddressResourceRecord addr in client
                .lookup<IPAddressResourceRecord>(
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
          if (ip != null && !token.isCancelled) {
            emit(DiscoveredHost(
              ip: ip,
              hostname: hostname.isEmpty ? null : hostname,
              openPorts: [srv.port],
              source: DiscoverySource.mdns,
              mdnsServiceType: serviceType,
            ));
          }
        }
      }
    } catch (_) {
      // timeout or socket error on this service type — other types continue
    }
  }
}
