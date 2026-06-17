import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/widgets/protocol_badge.dart';

void main() {
  testWidgets('renders RDP / VNC labels, nothing for SSH', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ProtocolBadge(HostProtocol.rdp),
          ProtocolBadge(HostProtocol.vnc),
          ProtocolBadge(HostProtocol.ssh),
        ]),
      ),
    ));
    expect(find.text('RDP'), findsOneWidget);
    expect(find.text('VNC'), findsOneWidget);
    expect(find.text('SSH'), findsNothing);
  });
}
