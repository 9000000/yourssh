// Regression test for xterm.dart upstream issue #207: TerminalView must
// attach its text-input connection with the hosting view's id. Without it
// the Windows engine rejects TextInput.setClient ("view ID is null") and
// printable keys never reach the terminal — Enter/Tab/paste still work via
// the hardware-key path, which is exactly the "shell opens but nothing can
// be typed" bug on the Windows local terminal.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('TerminalView attaches TextInput with the host viewId',
      (tester) async {
    final setClientConfigs = <Map<String, dynamic>>[];

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        if (call.method == 'TextInput.setClient') {
          final args = call.arguments as List<dynamic>;
          setClientConfigs.add((args[1] as Map).cast<String, dynamic>());
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.textInput, null);
    });

    final terminal = Terminal();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalView(terminal, autofocus: true)),
      ),
    );
    await tester.pump();

    expect(setClientConfigs, isNotEmpty,
        reason: 'TerminalView should open a TextInput connection on focus');
    expect(setClientConfigs.last['viewId'], tester.view.viewId,
        reason: 'TextInputConfiguration must carry the hosting viewId; '
            'a null viewId breaks typing on Windows (xterm issue #207)');
  });
}
