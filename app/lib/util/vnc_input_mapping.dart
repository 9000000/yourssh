import 'package:flutter/services.dart';

/// Maps a physical key to an X11 keysym for RFB `KeyEvent`, or null when the
/// key is outside the pragmatic US-layout subset (printable + modifiers +
/// navigation + function keys). Letters map to their *lowercase* keysym;
/// Shift is sent as its own keysym event and combined server-side.
///
/// Keyed by `PhysicalKeyboardKey.usbHidUsage` (mirrors rdp_input_mapping.dart).
int? vncKeysymFor(PhysicalKeyboardKey key) => _keysyms[key.usbHidUsage];

/// Transforms a widget-local pointer position into framebuffer pixel coords,
/// removing the centered letterbox offset and the render scale, clamped to
/// `[0, width-1] x [0, height-1]` so the result fits an unsigned 16-bit coord.
(int, int) vncSessionPoint({
  required double localX,
  required double localY,
  required double offX,
  required double offY,
  required double scale,
  required int width,
  required int height,
}) {
  final x = ((localX - offX) / scale).round().clamp(0, width - 1);
  final y = ((localY - offY) / scale).round().clamp(0, height - 1);
  return (x, y);
}

const Map<int, int> _keysyms = {
  // Letters (USB HID 0x04-0x1D) -> lowercase Latin-1 keysyms 0x61-0x7a
  0x00070004: 0x61, // a
  0x00070005: 0x62, // b
  0x00070006: 0x63, // c
  0x00070007: 0x64, // d
  0x00070008: 0x65, // e
  0x00070009: 0x66, // f
  0x0007000A: 0x67, // g
  0x0007000B: 0x68, // h
  0x0007000C: 0x69, // i
  0x0007000D: 0x6a, // j
  0x0007000E: 0x6b, // k
  0x0007000F: 0x6c, // l
  0x00070010: 0x6d, // m
  0x00070011: 0x6e, // n
  0x00070012: 0x6f, // o
  0x00070013: 0x70, // p
  0x00070014: 0x71, // q
  0x00070015: 0x72, // r
  0x00070016: 0x73, // s
  0x00070017: 0x74, // t
  0x00070018: 0x75, // u
  0x00070019: 0x76, // v
  0x0007001A: 0x77, // w
  0x0007001B: 0x78, // x
  0x0007001C: 0x79, // y
  0x0007001D: 0x7a, // z
  // Digits (0x1E-0x27) -> ASCII '1'..'9','0'
  0x0007001E: 0x31, // 1
  0x0007001F: 0x32, // 2
  0x00070020: 0x33, // 3
  0x00070021: 0x34, // 4
  0x00070022: 0x35, // 5
  0x00070023: 0x36, // 6
  0x00070024: 0x37, // 7
  0x00070025: 0x38, // 8
  0x00070026: 0x39, // 9
  0x00070027: 0x30, // 0
  // Control / whitespace
  0x00070028: 0xff0d, // Enter -> Return
  0x00070029: 0xff1b, // Escape
  0x0007002A: 0xff08, // Backspace
  0x0007002B: 0xff09, // Tab
  0x0007002C: 0x20, // Space
  0x00070039: 0xffe5, // CapsLock
  // Punctuation -> ASCII keysyms (base/unshifted)
  0x0007002D: 0x2d, // - minus
  0x0007002E: 0x3d, // = equal
  0x0007002F: 0x5b, // [ bracketleft
  0x00070030: 0x5d, // ] bracketright
  0x00070031: 0x5c, // \ backslash
  0x00070033: 0x3b, // ; semicolon
  0x00070034: 0x27, // ' apostrophe
  0x00070035: 0x60, // ` grave
  0x00070036: 0x2c, // , comma
  0x00070037: 0x2e, // . period
  0x00070038: 0x2f, // / slash
  // Function keys (0x3A-0x45) -> 0xffbe-0xffc9
  0x0007003A: 0xffbe, // F1
  0x0007003B: 0xffbf, // F2
  0x0007003C: 0xffc0, // F3
  0x0007003D: 0xffc1, // F4
  0x0007003E: 0xffc2, // F5
  0x0007003F: 0xffc3, // F6
  0x00070040: 0xffc4, // F7
  0x00070041: 0xffc5, // F8
  0x00070042: 0xffc6, // F9
  0x00070043: 0xffc7, // F10
  0x00070044: 0xffc8, // F11
  0x00070045: 0xffc9, // F12
  // Navigation
  0x00070049: 0xff63, // Insert
  0x0007004A: 0xff50, // Home
  0x0007004B: 0xff55, // PageUp
  0x0007004C: 0xffff, // Delete
  0x0007004D: 0xff57, // End
  0x0007004E: 0xff56, // PageDown
  0x0007004F: 0xff53, // ArrowRight
  0x00070050: 0xff51, // ArrowLeft
  0x00070051: 0xff54, // ArrowDown
  0x00070052: 0xff52, // ArrowUp
  // Modifiers (sent as their own keysym events)
  0x000700E0: 0xffe3, // LeftControl -> Control_L
  0x000700E1: 0xffe1, // LeftShift -> Shift_L
  0x000700E2: 0xffe9, // LeftAlt -> Alt_L
  0x000700E3: 0xffeb, // LeftMeta -> Super_L
  0x000700E4: 0xffe4, // RightControl -> Control_R
  0x000700E5: 0xffe2, // RightShift -> Shift_R
  0x000700E6: 0xffea, // RightAlt -> Alt_R
  0x000700E7: 0xffec, // RightMeta -> Super_R
};
