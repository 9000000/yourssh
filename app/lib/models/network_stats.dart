class NetworkStats {
  final String interface;
  final int rxBytes;
  final int txBytes;
  final DateTime timestamp;

  const NetworkStats({
    required this.interface,
    required this.rxBytes,
    required this.txBytes,
    required this.timestamp,
  });

  factory NetworkStats.fromProcNetDev(String output, {required String interface}) {
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('$interface:')) continue;
      final parts = trimmed.replaceFirst('$interface:', '').trim().split(RegExp(r'\s+'));
      if (parts.length < 9) continue;
      return NetworkStats(
        interface: interface,
        rxBytes: int.tryParse(parts[0]) ?? 0,
        txBytes: int.tryParse(parts[8]) ?? 0,
        timestamp: DateTime.now(),
      );
    }
    return NetworkStats(interface: interface, rxBytes: 0, txBytes: 0, timestamp: DateTime.now());
  }

  NetworkStatsDelta delta(NetworkStats previous) {
    final seconds = timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
    if (seconds <= 0) return NetworkStatsDelta(rxBytesPerSec: 0, txBytesPerSec: 0);
    return NetworkStatsDelta(
      rxBytesPerSec: ((rxBytes - previous.rxBytes) / seconds).round().clamp(0, double.maxFinite.toInt()),
      txBytesPerSec: ((txBytes - previous.txBytes) / seconds).round().clamp(0, double.maxFinite.toInt()),
    );
  }

  static String formatBytes(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}

class NetworkStatsDelta {
  final int rxBytesPerSec;
  final int txBytesPerSec;
  const NetworkStatsDelta({required this.rxBytesPerSec, required this.txBytesPerSec});
}
