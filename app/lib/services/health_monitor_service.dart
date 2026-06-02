import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session_health.dart';

/// Periodically pings every connected host and exposes a [SessionHealth] per
/// host id. The single pinger for live connections (built-in keepalive is
/// disabled in SshService), so each probe doubles as a keepalive.
class HealthMonitorService extends ChangeNotifier {
  final Future<int?> Function(String hostId) measure;
  final Iterable<String> Function() connectedHostIds;
  final int Function() pollSeconds;

  final Map<String, SessionHealth> _health = {};
  final Set<String> _inFlight = {};
  Timer? _timer;
  bool _disposed = false;

  HealthMonitorService({
    required this.measure,
    required this.connectedHostIds,
    required this.pollSeconds,
  });

  /// Current health for [hostId], or [SessionHealth.offline] if unmonitored.
  SessionHealth healthFor(String hostId) =>
      _health[hostId] ?? SessionHealth.offline;

  /// Begin periodic probing. Interval comes from [pollSeconds]; a disabled
  /// (<= 0) setting falls back to 15s so the badge still works.
  void start() {
    if (_timer != null) return;
    final secs = pollSeconds();
    final interval = Duration(seconds: secs <= 0 ? 15 : secs);
    _timer = Timer.periodic(interval, (_) => tick());
  }

  /// One probe round: drop stale hosts, then ping each connected host that is
  /// not already in flight. Exposed for tests (call directly instead of waiting
  /// for the timer).
  Future<void> tick() async {
    final ids = connectedHostIds().toSet();
    _health.removeWhere((id, _) => !ids.contains(id));

    final toProbe = ids.where((id) => !_inFlight.contains(id)).toList();
    await Future.wait(toProbe.map((id) async {
      _inFlight.add(id);
      try {
        final ms = await measure(id);
        // The host may have disconnected during the probe.
        if (connectedHostIds().contains(id)) {
          _health[id] = SessionHealth.fromLatency(ms, at: DateTime.now());
        }
      } finally {
        _inFlight.remove(id);
      }
    }));

    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
