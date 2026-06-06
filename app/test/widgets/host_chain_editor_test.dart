import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/widgets/host_chain_editor.dart';

Host makeHost(String id, String label,
        {String user = 'root', String addr = '10.0.0.1', String? os}) =>
    Host(id: id, label: label, host: addr, username: user, detectedOs: os);

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    );

void main() {
  testWidgets('empty state shows helper text and Add a Host', (tester) async {
    await tester.pumpWidget(wrap(HostChainEditor(
      currentHostLabel: 'prod-db',
      candidates: [makeHost('h1', 'bastion')],
      onSelect: (_) {},
    )));

    expect(find.text('Add a Host'), findsOneWidget);
    expect(
      find.textContaining('prod-db', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Clear'), findsNothing);
  });
}
