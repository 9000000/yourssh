import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/services/injection_gate.dart';

void main() {
  InjectionGate gate() =>
      InjectionGate(readySentinel: '__YS_RDY__', doneSentinel: '__YS_DONE__');

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

  test('DONE releases everything with sentinels stripped', () {
    final g = gate();
    g.feed('A__YS_RDY__B');
    final r = g.feed('C__YS_DONE__D');
    expect(r.emit, 'ABCD');
    expect(g.isHolding, isFalse);
  });

  test('DONE without RDY (non-bash/zsh) flushes without payload', () {
    final g = gate();
    final r = g.feed('echo__YS_DONE__');
    expect(r.emit, 'echo');
    expect(r.sendPayload, isFalse);
  });

  test('RDY and DONE in the same chunk sends payload and flushes', () {
    final g = gate();
    final r = g.feed('__YS_RDY____YS_DONE__tail');
    expect(r.sendPayload, isTrue);
    expect(r.emit, 'tail');
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
