import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/util/vnc_input_mapping.dart';

void main() {
  group('vncKeysymFor', () {
    test('letters map to lowercase Latin-1 keysyms', () {
      expect(vncKeysymFor(PhysicalKeyboardKey.keyA), 0x61);
      expect(vncKeysymFor(PhysicalKeyboardKey.keyZ), 0x7a);
    });
    test('digits map to ASCII keysyms', () {
      expect(vncKeysymFor(PhysicalKeyboardKey.digit1), 0x31);
      expect(vncKeysymFor(PhysicalKeyboardKey.digit0), 0x30);
    });
    test('common control keys', () {
      expect(vncKeysymFor(PhysicalKeyboardKey.enter), 0xff0d);
      expect(vncKeysymFor(PhysicalKeyboardKey.backspace), 0xff08);
      expect(vncKeysymFor(PhysicalKeyboardKey.tab), 0xff09);
      expect(vncKeysymFor(PhysicalKeyboardKey.escape), 0xff1b);
      expect(vncKeysymFor(PhysicalKeyboardKey.space), 0x20);
    });
    test('arrows and navigation', () {
      expect(vncKeysymFor(PhysicalKeyboardKey.arrowUp), 0xff52);
      expect(vncKeysymFor(PhysicalKeyboardKey.arrowLeft), 0xff51);
      expect(vncKeysymFor(PhysicalKeyboardKey.home), 0xff50);
      expect(vncKeysymFor(PhysicalKeyboardKey.delete), 0xffff);
    });
    test('modifiers map to side-specific keysyms', () {
      expect(vncKeysymFor(PhysicalKeyboardKey.shiftLeft), 0xffe1);
      expect(vncKeysymFor(PhysicalKeyboardKey.controlLeft), 0xffe3);
      expect(vncKeysymFor(PhysicalKeyboardKey.altLeft), 0xffe9);
    });
    test('function keys', () {
      expect(vncKeysymFor(PhysicalKeyboardKey.f1), 0xffbe);
      expect(vncKeysymFor(PhysicalKeyboardKey.f12), 0xffc9);
    });
    test('unmapped key returns null', () {
      expect(vncKeysymFor(PhysicalKeyboardKey.f24), isNull);
    });
  });

  group('vncSessionPoint', () {
    test('maps a centered letterboxed point to framebuffer coords', () {
      final (x, y) = vncSessionPoint(
          localX: 40 + 100 * 2,
          localY: 10 + 50 * 2,
          offX: 40,
          offY: 10,
          scale: 2,
          width: 800,
          height: 600);
      expect(x, 100);
      expect(y, 50);
    });
    test('clamps out-of-frame points into bounds', () {
      final (x, y) = vncSessionPoint(
          localX: -50,
          localY: 99999,
          offX: 0,
          offY: 0,
          scale: 1,
          width: 800,
          height: 600);
      expect(x, 0);
      expect(y, 599);
    });
  });
}
