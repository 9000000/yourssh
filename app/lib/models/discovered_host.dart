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
    if (openPorts.isEmpty) return '?';
    if (openPorts.contains(3389)) return 'RDP';
    if (openPorts.contains(22)) return 'SSH';
    if (openPorts.contains(2222)) return 'SSH:2222';
    return openPorts.first.toString();
  }

  bool get isRdp => openPorts.contains(3389) && !openPorts.contains(22);

  // fix #9: single source of truth for port selection
  int get preferredPort {
    if (isRdp) return 3389;
    if (openPorts.contains(22)) return 22;
    if (openPorts.contains(2222)) return 2222;
    return openPorts.isEmpty ? 22 : openPorts.first;
  }
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

  // fix #10: single source of truth for interface display names (shared with P2PSyncService)
  static String interfaceDisplayName(String name) {
    final n = name.toLowerCase();
    if (n == 'en0') return 'Wi-Fi';
    if (n.startsWith('wlan') || n.startsWith('wlp')) return 'Wi-Fi';
    if (n.startsWith('en')) return 'Ethernet';
    if (n.startsWith('eth')) return 'Ethernet';
    if (n.startsWith('utun') || n.startsWith('tun') || n.startsWith('tap')) {
      return 'VPN / Tailscale';
    }
    if (n.startsWith('bridge')) return 'Bridge';
    return name;
  }

  // fix #7: guard against non-IPv4 / malformed addresses
  static String subnetFromAddress(String address) {
    final parts = address.split('.');
    if (parts.length < 4) return '192.168.1.0/24';
    return '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
  }

  // fix #2: respect prefix length instead of always generating 254 hosts
  static List<String> hostsInSubnet(String subnet) {
    final slash = subnet.indexOf('/');
    if (slash < 0) return [];
    final base = subnet.substring(0, slash);
    final prefix = int.tryParse(subnet.substring(slash + 1));
    if (prefix == null || prefix < 0 || prefix > 32) return [];
    final parts = base.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((o) => o == null)) return [];
    final network = (parts[0]! << 24) | (parts[1]! << 16) | (parts[2]! << 8) | parts[3]!;
    final hostBits = 32 - prefix;
    final count = (1 << hostBits) - 2;
    if (count <= 0) return [];
    return List.generate(count, (i) {
      final addr = network + i + 1;
      return '${(addr >> 24) & 0xff}.${(addr >> 16) & 0xff}.${(addr >> 8) & 0xff}.${addr & 0xff}';
    });
  }

  /// Returns null when [subnet] is a valid x.x.x.x/y string (prefix /16–/32).
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
    if (prefix == null || prefix < 16 || prefix > 32) {
      return 'Prefix must be /16–/32';
    }
    return null;
  }

  @override
  String toString() => '$displayName ($address) — $subnet';
}
