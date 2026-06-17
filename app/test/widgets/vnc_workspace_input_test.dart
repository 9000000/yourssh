import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/vnc_session.dart';
import 'package:yourssh/widgets/vnc_workspace.dart';
import 'package:yourssh_vnc/yourssh_vnc.dart' show VncClient, VncConfig;
// ignore: implementation_imports
import 'package:yourssh_vnc/src/generated/api.dart' as frb;

Host _host() => Host(
    id: 'v1',
    label: 'desktop',
    host: '10.0.0.5',
    port: 5900,
    username: 'u',
    protocol: HostProtocol.vnc);

VncClient _client() => VncClient(VncConfig(
    targetHost: '10.0.0.5', targetPort: 5900, username: 'u', password: ''));

void main() {
  testWidgets('connected workspace exposes an input surface and handles keys',
      (tester) async {
    final events = StreamController<frb.VncEvent>();
    final session = VncSession(host: _host(), client: _client());
    session.attach(events.stream);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: VncWorkspace(session: session)),
    ));

    events.add(const frb.VncEvent.connected(width: 800, height: 600));
    await tester.pump();

    expect(find.byType(Listener), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();

    await events.close();
  });
}
