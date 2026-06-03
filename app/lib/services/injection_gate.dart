/// Result of feeding one output chunk through [InjectionGate].
class GateResult {
  /// Text to write to the terminal now; null while output is withheld.
  final String? emit;

  /// True exactly once: when the ready sentinel is first seen.
  final bool sendPayload;

  const GateResult({this.emit, this.sendPayload = false});
}

/// Withholds shell output between the shell-integration bootstrap write and
/// the done sentinel, so the echoed bootstrap line can be erased before it is
/// ever painted. Pure (no IO/timers) — the caller owns the timeout.
class InjectionGate {
  InjectionGate({required this.readySentinel, required this.doneSentinel});

  final String readySentinel;
  final String doneSentinel;

  final StringBuffer _held = StringBuffer();
  bool _passthrough = false;
  bool _payloadSent = false;

  bool get isHolding => !_passthrough;

  /// Size of the withheld buffer — used by the caller's over-hold guard.
  int get heldLength => _held.length;

  GateResult feed(String text) {
    if (_passthrough) return GateResult(emit: text);
    _held.write(text);
    final buf = _held.toString();
    var sendPayload = false;
    if (!_payloadSent && buf.contains(readySentinel)) {
      _payloadSent = true;
      sendPayload = true;
    }
    if (buf.contains(doneSentinel)) {
      _passthrough = true;
      _held.clear();
      return GateResult(emit: _strip(buf), sendPayload: sendPayload);
    }
    return GateResult(sendPayload: sendPayload);
  }

  /// Timeout / shell-closed path: release held text as-is and stop gating.
  String flush() {
    _passthrough = true;
    final out = _strip(_held.toString());
    _held.clear();
    return out;
  }

  String _strip(String s) =>
      s.replaceAll(readySentinel, '').replaceAll(doneSentinel, '');
}
