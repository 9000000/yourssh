import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/services/injection_gate.dart';

void main() {
  InjectionGate gate({int maxHold = 2048}) => InjectionGate(
      readySentinel: '__YS_RDY__',
      doneSentinel: '__YS_DONE__',
      maxHold: maxHold);

  test('withholds output until DONE', () {
    final g = gate();
    expect(g.feed('motd echo').emit, isNull);
    expect(g.isHolding, isTrue);
  });

  test('RDY triggers sendPayload exactly once', () {
    final g = gate();
    expect(g.feed('x__YS_RDY__').sendPayload, isTrue);
    expect(g.feed('more __YS_RDY__ again').sendPayload, isFalse);
  });

  test('RDY split across chunks still triggers', () {
    final g = gate();
    expect(g.feed('echo __YS_R').sendPayload, isFalse);
    expect(g.feed('DY__').sendPayload, isTrue);
  });

  test('DONE discards the echo head and emits only the tail', () {
    // The held head is just the bootstrap echo + RDY — junk. Never write it;
    // erasing it after the fact desyncs the app cursor from the remote's.
    final g = gate();
    g.feed('echo__YS_RDY__noise');
    final r = g.feed('more__YS_DONE__\ntail');
    expect(r.emit, '\ntail');
    expect(g.isHolding, isFalse);
  });

  test('oversized head means real output got held — emit it, stripped', () {
    // Late MOTD landed inside the hold window. Showing it (rendered exactly
    // as if it was never held) beats silently swallowing server output.
    final g = gate(maxHold: 10);
    g.feed('A' * 11);
    final r = g.feed('__YS_RDY____YS_DONE__tail');
    expect(r.emit, '${'A' * 11}tail');
    expect(r.sendPayload, isTrue);
  });

  test('DONE without RDY (non-bash/zsh) discards echo without payload', () {
    final g = gate();
    final r = g.feed('echo__YS_DONE__');
    expect(r.emit, '');
    expect(r.sendPayload, isFalse);
    expect(g.isHolding, isFalse);
  });

  test('RDY and DONE in the same chunk sends payload and emits tail', () {
    final g = gate();
    final r = g.feed('__YS_RDY____YS_DONE__tail');
    expect(r.sendPayload, isTrue);
    expect(r.emit, 'tail');
  });

  test('DONE split across chunks still completes', () {
    final g = gate();
    g.feed('__YS_RDY__x__YS_DO');
    final r = g.feed('NE__after');
    expect(r.emit, 'after');
    expect(g.isHolding, isFalse);
  });

  test('passthrough after DONE', () {
    final g = gate();
    g.feed('__YS_DONE__');
    expect(g.feed('hello').emit, 'hello');
  });

  test('flush releases held text and stops gating', () {
    final g = gate();
    g.feed('partial __YS_R');
    expect(g.flush(), 'partial __YS_R');
    expect(g.isHolding, isFalse);
    expect(g.feed('after').emit, 'after');
  });

  test('heldLength tracks the withheld buffer', () {
    final g = gate();
    g.feed('12345');
    expect(g.heldLength, 5);
  });
}
