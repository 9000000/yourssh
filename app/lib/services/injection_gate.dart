/// Result of feeding one output chunk through [InjectionGate].
class GateResult {
  /// Text to write to the terminal now; null while output is withheld.
  final String? emit;

  /// True exactly once: when the ready sentinel is first seen.
  final bool sendPayload;

  const GateResult({this.emit, this.sendPayload = false});
}

/// Withholds shell output between the shell-integration bootstrap write and
/// the done sentinel, then discards it: the held head is just the echoed
/// bootstrap line plus sentinels. Discarding (rather than writing it and
/// erasing afterwards) keeps the app-side cursor in sync with where the
/// remote shell believes it is — erase-by-cursor-math desyncs the two and
/// fancy prompts then paint over the wrong rows.
/// Pure (no IO/timers) — the caller owns the timeout.
class InjectionGate {
  InjectionGate({
    required this.readySentinel,
    required this.doneSentinel,
    this.maxHold = 2048,
  });

  final String readySentinel;
  final String doneSentinel;

  /// Largest head that can plausibly be bootstrap echo. A bigger head means
  /// real server output (late MOTD) landed inside the hold window — it is
  /// emitted instead of discarded, rendered exactly as if never held.
  final int maxHold;

  final StringBuffer _held = StringBuffer();
  bool _passthrough = false;
  bool _payloadSent = false;

  bool get isHolding => !_passthrough;

  /// Size of the withheld buffer.
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
    final idx = buf.indexOf(doneSentinel);
    if (idx >= 0) {
      _passthrough = true;
      _held.clear();
      final head = buf.substring(0, idx);
      final tail = buf.substring(idx + doneSentinel.length);
      final emit = head.length > maxHold ? _strip(head) + tail : tail;
      return GateResult(emit: emit, sendPayload: sendPayload);
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
