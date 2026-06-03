// app/test/widgets/sftp_entry_context_menu_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/sftp_entry.dart';
import 'package:yourssh/widgets/sftp_entry_context_menu.dart';

final _file = SftpEntry(
  name: 'notes.txt',
  path: '/home/u/notes.txt',
  isDirectory: false,
  size: 10,
  modifiedAt: DateTime(2026),
);

void main() {
  testWidgets('context menu shows "Open with external app" for files',
      (tester) async {
    var externalOpened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SftpEntryContextMenu(
          entry: _file,
          onOpen: () {},
          onRename: () {},
          onDelete: () {},
          onOpenExternal: () => externalOpened = true,
          child: const Text('notes.txt'),
        ),
      ),
    ));

    await tester.tap(find.text('notes.txt'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Open with external app'), findsOneWidget);
    await tester.tap(find.text('Open with external app'));
    await tester.pumpAndSettle();
    expect(externalOpened, isTrue);
  });
}
