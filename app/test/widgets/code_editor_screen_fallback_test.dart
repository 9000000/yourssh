// app/test/widgets/code_editor_screen_fallback_test.dart
//
// Reproduces issue #34: on platforms without a webview_flutter
// implementation (Linux, Windows — and the test environment),
// CodeEditorScreen must render a plain-text fallback editor instead of
// crashing in initState.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/sftp_entry.dart';
import 'package:yourssh/services/sftp_transfer_service.dart';
import 'package:yourssh/services/ssh_service.dart';
import 'package:yourssh/services/storage_service.dart';
import 'package:yourssh/widgets/code_editor_screen.dart';

class FakeTransferService extends SftpTransferService {
  FakeTransferService(this.bytes) : super(SshService(StorageService()));

  final List<int> bytes;
  String? uploadedRemotePath;
  String? uploadedContent;

  @override
  Future<String?> downloadToTemp(Host host, SftpEntry entry) async {
    final dir = await Directory.systemTemp.createTemp('yourssh_editor_test');
    final file = File('${dir.path}/${entry.name}');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Future<void> uploadFile(
      Host host, String localPath, String remotePath) async {
    uploadedRemotePath = remotePath;
    uploadedContent = await File(localPath).readAsString();
  }
}

final _host = Host(label: 'test', host: 'example.com', username: 'u');
final _entry = SftpEntry(
  name: 'config.txt',
  path: '/etc/config.txt',
  isDirectory: false,
  size: 10,
  modifiedAt: DateTime(2026),
);

Widget _wrap(FakeTransferService service) {
  return MaterialApp(
    home: Provider<SftpTransferService>.value(
      value: service,
      child: CodeEditorScreen(host: _host, entry: _entry),
    ),
  );
}

/// Pumps until [finder] matches. Two reasons `pumpAndSettle` can't be used:
/// the fake service does real file IO, which only completes inside
/// `runAsync`, and the focused TextField blinks its cursor forever so the
/// tree never settles.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('$finder not found after pumping');
}

void main() {
  testWidgets('renders fallback editor when no webview platform (issue #34)',
      (tester) async {
    final service = FakeTransferService(utf8.encode('hello from server'));
    await tester.pumpWidget(_wrap(service));
    await _pumpUntilFound(tester, find.byType(TextField));

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text,
        'hello from server');
  });

  testWidgets('save button uploads edited content', (tester) async {
    final service = FakeTransferService(utf8.encode('v1'));
    await tester.pumpWidget(_wrap(service));
    await _pumpUntilFound(tester, find.byType(TextField));

    await tester.enterText(find.byType(TextField), 'v2 edited');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await _pumpUntilFound(tester, find.text('Saved'));

    expect(service.uploadedContent, 'v2 edited');
    expect(service.uploadedRemotePath, '/etc/config.txt');
  });

  testWidgets('Ctrl+S saves from the fallback editor', (tester) async {
    final service = FakeTransferService(utf8.encode('v1'));
    await tester.pumpWidget(_wrap(service));
    await _pumpUntilFound(tester, find.byType(TextField));

    await tester.enterText(find.byType(TextField), 'keyboard save');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _pumpUntilFound(tester, find.text('Saved'));

    expect(service.uploadedContent, 'keyboard save');
  });
}
