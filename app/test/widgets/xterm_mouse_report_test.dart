// Tests for the xterm fork's mouse report encoding — wheel scrolling inside
// mouse-aware TUIs (claude, htop, vim mouse=a, tmux mouse on) depends on the
// exact button codes: wheel up/down must be reported as 64/65 (flag 64 + low
// two bits of X11 buttons 4/5), in SGR form `ESC [ < 64 ; x ; y M`.
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  Terminal mouseTerminal({String reportMode = '\x1b[?1006h'}) {
    final terminal = Terminal();
    // Application enables all-motion tracking (1003) + the report mode.
    terminal.write('\x1b[?1003h$reportMode');
    return terminal;
  }

  String? lastOutput(Terminal terminal, void Function() act) {
    String? out;
    terminal.onOutput = (data) => out = data;
    act();
    return out;
  }

  test('SGR wheel up reports button 64', () {
    final terminal = mouseTerminal();
    final out = lastOutput(terminal, () {
      final handled = terminal.mouseInput(
        TerminalMouseButton.wheelUp,
        TerminalMouseButtonState.down,
        const CellOffset(4, 9),
      );
      expect(handled, isTrue);
    });
    expect(out, '\x1b[<64;5;10M');
  });

  test('SGR wheel down reports button 65', () {
    final terminal = mouseTerminal();
    final out = lastOutput(terminal, () {
      terminal.mouseInput(
        TerminalMouseButton.wheelDown,
        TerminalMouseButtonState.down,
        const CellOffset(0, 0),
      );
    });
    expect(out, '\x1b[<65;1;1M');
  });

  test('normal-mode wheel up encodes 32+64 with 1-based coords', () {
    final terminal = mouseTerminal(reportMode: ''); // default normal mode
    final out = lastOutput(terminal, () {
      terminal.mouseInput(
        TerminalMouseButton.wheelUp,
        TerminalMouseButtonState.down,
        const CellOffset(2, 3),
      );
    });
    // ESC [ M, button byte 32+64=96 ('`'), col 32+3=35 ('#'), row 32+4=36 ('$')
    expect(out, '\x1b[M\x60#\$');
  });

  test('left click in SGR mode reports button 0 press and release', () {
    final terminal = mouseTerminal();
    final down = lastOutput(terminal, () {
      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        const CellOffset(0, 0),
      );
    });
    expect(down, '\x1b[<0;1;1M');
    final up = lastOutput(terminal, () {
      terminal.mouseInput(
        TerminalMouseButton.left,
        TerminalMouseButtonState.up,
        const CellOffset(0, 0),
      );
    });
    expect(up, '\x1b[<0;1;1m');
  });

  test('wheel is not reported when the app never enabled mouse mode', () {
    final terminal = Terminal();
    final out = lastOutput(terminal, () {
      final handled = terminal.mouseInput(
        TerminalMouseButton.wheelUp,
        TerminalMouseButtonState.down,
        const CellOffset(0, 0),
      );
      expect(handled, isFalse,
          reason: 'unhandled wheel falls back to viewport scrolling');
    });
    expect(out, isNull);
  });
}
