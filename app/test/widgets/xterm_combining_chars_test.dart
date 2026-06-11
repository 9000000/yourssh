// Tests for combining-diacritic handling in the xterm fork's buffer.
// Vietnamese text arrives in two Unicode forms:
//  - NFC (precomposed): one codepoint per letter, one cell. Always worked.
//  - NFD (decomposed): base char followed by combining marks. macOS
//    filenames (ls output!) and many tools emit this form.
// A terminal must merge combining marks into the preceding cell; writing them
// to their own cells breaks rendering and cursor position.
//
// Every non-ASCII char is spelled with explicit \u escapes -- source-file
// literals would silently be NFC and test nothing.
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  Terminal newTerminal() {
    final t = Terminal();
    t.resize(80, 25);
    return t;
  }

  String rowText(Terminal t, [int row = 0]) =>
      t.buffer.lines[row].getText().trimRight();

  // "Tieng Viet" with full diacritics, both Unicode forms.
  const nfc = 'Ti\u{1EBF}ng Vi\u{1EC7}t';
  const nfd = 'Tie\u{302}\u{301}ng Vie\u{323}\u{302}t';

  test('NFC (precomposed) Vietnamese renders one cell per letter', () {
    final t = newTerminal();
    t.write(nfc);
    expect(rowText(t), nfc);
    expect(t.buffer.cursorX, 10);
  });

  test('NFD (decomposed) Vietnamese composes into the preceding cell', () {
    final t = newTerminal();
    t.write(nfd);
    expect(rowText(t), nfc,
        reason: 'combining marks must merge with the base character');
    expect(t.buffer.cursorX, 10,
        reason: 'marks must not advance the cursor');
  });

  test('NFD across many Vietnamese letters', () {
    final t = newTerminal();
    // "duong pho ha noi" fully decomposed (canonical mark order).
    t.write('\u{111}u\u{31B}o\u{31B}\u{300}ng pho\u{302}\u{301} ha\u{300} no\u{323}\u{302}i');
    expect(rowText(t), '\u{111}\u{1B0}\u{1EDD}ng ph\u{1ED1} h\u{E0} n\u{1ED9}i');
  });

  test('mark applies to the cell styled by the base char, not cursor style',
      () {
    final t = newTerminal();
    // Base char written in red, mark arrives after a style reset.
    t.write('\x1b[31me\x1b[0m\u{302}');
    expect(rowText(t), '\u{EA}'); // e-circumflex
    final line = t.buffer.lines[0];
    expect(line.getForeground(0), isNot(0),
        reason: 'composition must preserve the base cell style');
  });

  test('combining mark at column 0 does not crash', () {
    final t = newTerminal();
    t.write('\u{301}abc');
    expect(rowText(t).endsWith('abc'), isTrue);
  });

  test('combining mark after a wide (CJK) character no-ops gracefully', () {
    final t = newTerminal();
    t.write('\u{6F22}\u{301}x');
    // The CJK char has no precomposed form with the mark -- the mark keeps
    // its own zero-width cell (legacy behavior) and must not corrupt
    // neighbors.
    expect(rowText(t).contains('x'), isTrue);
    expect(t.buffer.cursorX, 4);
  });

  test('zero-width joiner does not destroy preceding text', () {
    final t = newTerminal();
    t.write('ab\u{200D}c');
    expect(rowText(t).startsWith('ab'), isTrue);
    expect(rowText(t).endsWith('c'), isTrue);
  });

  test('NFD text wraps without losing diacritics at the line boundary', () {
    final t = Terminal();
    t.resize(5, 5);
    // 6 decomposed letters on a 5-col line -> wraps after 5.
    t.write('e\u{302}\u{301}' * 6);
    expect(t.buffer.lines[0].getText().trimRight(), '\u{1EBF}' * 5);
    expect(t.buffer.lines[1].getText().trimRight(), '\u{1EBF}');
  });
}
