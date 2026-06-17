import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/vnc_session.dart';
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
  test('status transitions connecting -> connected -> disconnected', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    expect(s.status, VncSessionStatus.connecting);

    events.add(const frb.VncEvent.started(sessionId: 1));
    events.add(const frb.VncEvent.connected(width: 800, height: 600));
    await Future<void>.delayed(Duration.zero);
    expect(s.status, VncSessionStatus.connected);
    expect(s.width, 800);
    expect(s.height, 600);

    events.add(const frb.VncEvent.disconnected(reason: 'bye'));
    await Future<void>.delayed(Duration.zero);
    expect(s.status, VncSessionStatus.disconnected);
    expect(s.lastMessage, 'bye');
    await events.close();
  });

  test('error event sets error status and message', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.error(message: 'connection refused'));
    await Future<void>.delayed(Duration.zero);
    expect(s.status, VncSessionStatus.error);
    expect(s.lastMessage, 'connection refused');
    await events.close();
  });

  test('framebuffer reallocates to server size on connected', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.connected(width: 4, height: 2));
    await Future<void>.delayed(Duration.zero);
    expect(s.framebuffer.length, 4 * 2 * 4);
    await events.close();
  });

  test('resize reallocates the framebuffer', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.connected(width: 4, height: 2));
    await Future<void>.delayed(Duration.zero);
    events.add(const frb.VncEvent.resize(width: 8, height: 8));
    await Future<void>.delayed(Duration.zero);
    expect(s.width, 8);
    expect(s.height, 8);
    expect(s.framebuffer.length, 8 * 8 * 4);
    await events.close();
  });

  test('out-of-bounds frame update is dropped without crashing', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.connected(width: 4, height: 4));
    await Future<void>.delayed(Duration.zero);
    events.add(frb.VncEvent.frameUpdate(
        x: 3, y: 3, width: 4, height: 4, rgba: Uint8List(4 * 4 * 4)));
    await Future<void>.delayed(Duration.zero);
    expect(s.framebuffer.length, 4 * 4 * 4);
    await events.close();
  });

  test('frame update patches the framebuffer row-by-row', () async {
    final events = StreamController<frb.VncEvent>();
    final s = VncSession(host: _host(), client: _client());
    s.attach(events.stream);
    events.add(const frb.VncEvent.connected(width: 2, height: 1));
    await Future<void>.delayed(Duration.zero);
    final px = Uint8List.fromList([10, 20, 30, 255, 40, 50, 60, 255]);
    events.add(
        frb.VncEvent.frameUpdate(x: 0, y: 0, width: 2, height: 1, rgba: px));
    await Future<void>.delayed(Duration.zero);
    expect(s.framebuffer.sublist(0, 8), [10, 20, 30, 255, 40, 50, 60, 255]);
    await events.close();
  });

  test('tab label falls back to host label, honours custom override', () {
    final s = VncSession(host: _host(), client: _client());
    expect(s.tabLabel, 'desktop');
    s.customLabel = 'My VM';
    expect(s.tabLabel, 'My VM');
  });
}
