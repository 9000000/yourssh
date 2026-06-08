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
  /// [onProgress] fires after each IP is probed with (scanned, total).
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
      if (_cancelled || controller.isClosed) return;
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
        ),
        _runMdnsScan(emit),
      ]);
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
          await for (final PtrResourceRecord ptr in client
              .lookup<PtrResourceRecord>(
                  ResourceRecordQuery.serverPointer('$serviceType.local'))
              .timeout(const Duration(seconds: 5))) {
            if (_cancelled) break;
            await for (final SrvResourceRecord srv in client
                .lookup<SrvResourceRecord>(
                    ResourceRecordQuery.service(ptr.domainName))) {
              if (_cancelled) break;
              String? ip;
              final hostname = srv.target.replaceAll(RegExp(r'\.local\.?$'), '');
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
              if (ip != null && !_cancelled) {
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
          // timeout or socket error on this service type — continue with next
        }
      }
    } catch (_) {
      // mDNS socket bind failed — TCP scan continues unaffected
    } finally {
      client?.stop();
    }
  }

  static String _displayName(String name) {
    final n = name.toLowerCase();
    if (n == 'en0') return 'Wi-Fi';
    if (n.startsWith('wlan') || n.startsWith('wlp')) return 'Wi-Fi';
    if (n.startsWith('en')) return 'Ethernet';
    if (n.startsWith('eth')) return 'Ethernet';
    if (n.startsWith('utun') || n.startsWith('tun') || n.startsWith('tap')) {
      return 'VPN';
    }
    return name;
  }
}
