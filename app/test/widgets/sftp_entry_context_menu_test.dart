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
  testWidgets('context menu shows View and Edit for files', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SftpEntryContextMenu(
          entry: _file,
          onOpen: () {},
          onView: () {},
          onEdit: () {},
          onOpenWith: (_) {},
          onRename: () {},
          onDelete: () {},
          child: const Text('notes.txt'),
        ),
      ),
    ));

    await tester.tap(find.text('notes.txt'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('View'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('context menu shows "Open with" for files', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SftpEntryContextMenu(
          entry: _file,
          onOpen: () {},
          onView: () {},
          onEdit: () {},
          onOpenWith: (_) {},
          onRename: () {},
          onDelete: () {},
          child: const Text('notes.txt'),
        ),
      ),
    ));

    await tester.tap(find.text('notes.txt'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Open with'), findsOneWidget);
  });

  testWidgets('tapping View calls onView', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SftpEntryContextMenu(
          entry: _file,
          onOpen: () {},
          onView: () => called = true,
          onEdit: () {},
          onOpenWith: (_) {},
          onRename: () {},
          onDelete: () {},
          child: const Text('notes.txt'),
        ),
      ),
    ));

    await tester.tap(find.text('notes.txt'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });

  testWidgets('tapping "Open with" calls onOpenWith with an Offset',
      (tester) async {
    Offset? receivedOffset;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SftpEntryContextMenu(
          entry: _file,
          onOpen: () {},
          onView: () {},
          onEdit: () {},
          onOpenWith: (offset) => receivedOffset = offset,
          onRename: () {},
          onDelete: () {},
          child: const Text('notes.txt'),
        ),
      ),
    ));

    await tester.tap(find.text('notes.txt'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open with'));
    await tester.pumpAndSettle();

    expect(receivedOffset, isNotNull);
  });
}
