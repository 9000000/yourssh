# SFTP Editor Fallback + External Edit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix issue #34 (opening an SFTP file on Linux/Windows blanks the window because `webview_flutter` has no platform implementation there) by adding a plain-Flutter fallback editor, and add WinSCP-style "open with external app" with automatic upload-on-save for files the app cannot edit.

**Architecture:** `CodeEditorScreen` checks `WebViewPlatform.instance` and renders a `TextField` editor when no webview exists. A pure `sftp_file_inspector.dart` decides which files are uneditable (binary extension, > 5 MB, null byte in content). A new `ExternalEditService` downloads a file to a per-session temp dir, opens it with the OS default app (`url_launcher`), polls mtime every 2 s, and uploads changes back over SFTP.

**Tech Stack:** Flutter (desktop), provider, dartssh2 (local fork), url_launcher (already a dependency), flutter_test.

**Spec:** `docs/superpowers/specs/2026-06-03-sftp-editor-fallback-external-edit-design.md`

---

### Task 1: File inspector (pure detection helpers)

**Files:**
- Create: `app/lib/services/sftp_file_inspector.dart`
- Test: `app/test/services/sftp_file_inspector_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/services/sftp_file_inspector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/sftp_entry.dart';
import 'package:yourssh/services/sftp_file_inspector.dart';

SftpEntry _entry(String name, {int size = 10}) => SftpEntry(
      name: name,
      path: '/tmp/$name',
      isDirectory: false,
      size: size,
      modifiedAt: DateTime(2026),
    );

void main() {
  group('editBlockReason', () {
    test('plain text file is editable', () {
      expect(editBlockReason(_entry('notes.txt')), EditBlockReason.none);
    });

    test('binary extension is blocked', () {
      expect(editBlockReason(_entry('photo.png')),
          EditBlockReason.binaryExtension);
      expect(editBlockReason(_entry('archive.tar.gz')),
          EditBlockReason.binaryExtension);
      expect(editBlockReason(_entry('app.exe')),
          EditBlockReason.binaryExtension);
    });

    test('file over 5 MB is blocked', () {
      expect(editBlockReason(_entry('big.log', size: 5 * 1024 * 1024 + 1)),
          EditBlockReason.tooLarge);
    });

    test('file at exactly 5 MB is editable', () {
      expect(editBlockReason(_entry('ok.log', size: 5 * 1024 * 1024)),
          EditBlockReason.none);
    });

    test('file without extension is editable', () {
      expect(editBlockReason(_entry('Makefile')), EditBlockReason.none);
    });
  });

  group('looksBinary', () {
    test('plain ascii is not binary', () {
      expect(looksBinary('hello world\n'.codeUnits), isFalse);
    });

    test('null byte marks binary', () {
      expect(looksBinary(const [0x68, 0x00, 0x69]), isTrue);
    });

    test('null byte beyond the first 8 KB is ignored', () {
      final bytes = List<int>.filled(8193, 0x61)..[8192] = 0;
      expect(looksBinary(bytes), isFalse);
    });

    test('empty content is not binary', () {
      expect(looksBinary(const []), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd app && flutter test test/services/sftp_file_inspector_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'yourssh/services/sftp_file_inspector.dart'` (file does not exist yet).

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/services/sftp_file_inspector.dart
//
// Pure helpers that decide whether an SFTP entry can be edited in-app.
// No Flutter or dart:io imports so the logic stays trivially unit-testable.
import '../models/sftp_entry.dart';

/// Files larger than this are not loaded into the in-app editor.
const int kMaxEditableFileSize = 5 * 1024 * 1024; // 5 MB

/// Extensions always treated as binary (pointless to edit as text).
const Set<String> kBinaryExtensions = {
  // images
  'png', 'jpg', 'jpeg', 'gif', 'bmp', 'ico', 'webp', 'tiff', 'heic',
  // audio / video
  'mp3', 'wav', 'ogg', 'flac', 'aac', 'mp4', 'mkv', 'avi', 'mov', 'webm',
  // archives
  'zip', 'tar', 'gz', 'bz2', 'xz', 'zst', '7z', 'rar', 'jar', 'war',
  // executables / libraries / object code
  'exe', 'dll', 'so', 'dylib', 'bin', 'o', 'a', 'class', 'wasm',
  // documents
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt',
  // misc binary formats
  'sqlite', 'db', 'iso', 'img', 'dmg', 'ttf', 'otf', 'woff', 'woff2',
};

enum EditBlockReason { none, binaryExtension, tooLarge }

/// Pre-download check: can [entry] be opened in the in-app editor?
/// Uses only metadata from the directory listing (name + size).
EditBlockReason editBlockReason(SftpEntry entry) {
  if (kBinaryExtensions.contains(entry.extension)) {
    return EditBlockReason.binaryExtension;
  }
  if (entry.size > kMaxEditableFileSize) return EditBlockReason.tooLarge;
  return EditBlockReason.none;
}

/// Post-download check: a null byte within the first 8 KB marks the content
/// as binary even when the extension looked editable.
bool looksBinary(List<int> bytes) {
  final limit = bytes.length < 8192 ? bytes.length : 8192;
  for (var i = 0; i < limit; i++) {
    if (bytes[i] == 0) return true;
  }
  return false;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/services/sftp_file_inspector_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/sftp_file_inspector.dart app/test/services/sftp_file_inspector_test.dart
git commit -m "feat(sftp): pure detection helpers for uneditable files"
```

---

### Task 2: CodeEditorScreen fallback editor (fixes #34)

**Files:**
- Modify: `app/lib/widgets/code_editor_screen.dart`
- Test: `app/test/widgets/code_editor_screen_fallback_test.dart`

The crash: `initState` always constructs `WebViewController()`, which throws when `WebViewPlatform.instance == null` (Linux, Windows — only Android and wkwebview implementations are in `pubspec.lock`). The widget-test environment also has `WebViewPlatform.instance == null`, so a plain `pumpWidget` reproduces #34 exactly.

Also refactor `_saveFile` to reuse the path returned by `downloadToTemp` (stored in `_tmpPath`) instead of calling `getTemporaryDirectory()` again — removes the duplicated path derivation and the path_provider dependency from the save path (which would throw `MissingPluginException` in tests).

- [ ] **Step 1: Write the failing tests**

```dart
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

void main() {
  testWidgets('renders fallback editor when no webview platform (issue #34)',
      (tester) async {
    final service = FakeTransferService(utf8.encode('hello from server'));
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text,
        'hello from server');
  });

  testWidgets('save button uploads edited content', (tester) async {
    final service = FakeTransferService(utf8.encode('v1'));
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'v2 edited');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect(service.uploadedContent, 'v2 edited');
    expect(service.uploadedRemotePath, '/etc/config.txt');
  });

  testWidgets('Ctrl+S saves from the fallback editor', (tester) async {
    final service = FakeTransferService(utf8.encode('v1'));
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'keyboard save');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(service.uploadedContent, 'keyboard save');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail for the right reason**

Run: `cd app && flutter test test/widgets/code_editor_screen_fallback_test.dart`
Expected: FAIL — the first pump throws from `WebViewController()` (assertion: no platform implementation set). This is the #34 crash reproduced.

- [ ] **Step 3: Implement the fallback in `code_editor_screen.dart`**

Apply these changes:

1. Replace the `_controller` field block (lines 26–31) with:

```dart
class _CodeEditorScreenState extends State<CodeEditorScreen> {
  // Monaco runs in a webview where an implementation exists (macOS, mobile).
  // On Linux/Windows webview_flutter has no platform implementation —
  // constructing WebViewController there throws and used to blank the whole
  // window (issue #34) — so we fall back to a plain TextField editor.
  WebViewController? _controller;
  final TextEditingController _textController = TextEditingController();
  bool _ready = false;
  bool _saving = false;
  bool _isDirty = false;
  String? _content;
  String? _tmpPath;

  bool get _useWebView => _controller != null;
```

2. Replace `initState` with:

```dart
  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'FlutterChannel',
          onMessageReceived: _onJsMessage,
        )
        ..loadFlutterAsset('assets/monaco_editor.html');
    }
    _loadFile();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
```

3. In `_loadFile`, after the `utf8.decode` setState, store the temp path and feed the fallback editor. Replace:

```dart
      final tmpPath = await service.downloadToTemp(widget.host, widget.entry);
      if (tmpPath == null || !mounted) return;
      final bytes = await File(tmpPath).readAsBytes();
      if (!mounted) return;
      setState(() => _content = utf8.decode(bytes, allowMalformed: true));
      if (_ready) _pushContentToEditor();
```

with:

```dart
      final tmpPath = await service.downloadToTemp(widget.host, widget.entry);
      if (tmpPath == null || !mounted) return;
      _tmpPath = tmpPath;
      final bytes = await File(tmpPath).readAsBytes();
      if (!mounted) return;
      setState(() => _content = utf8.decode(bytes, allowMalformed: true));
      if (_useWebView) {
        if (_ready) _pushContentToEditor();
      } else {
        _textController.text = _content!;
        setState(() => _ready = true);
      }
```

4. In `_pushContentToEditor`, use the now-nullable controller: `_controller!.runJavaScript(...)`.

5. In `_saveFile`, replace the `getTemporaryDirectory()` block:

```dart
      final tmpDir = await getTemporaryDirectory();
      final tmpPath = '${tmpDir.path}/${widget.entry.name}';
      await File(tmpPath).writeAsString(content);
```

with (reuses the download location; path_provider only as a fallback when the initial download never completed):

```dart
      final tmpPath = _tmpPath ??
          '${(await getTemporaryDirectory()).path}/${widget.entry.name}';
      await File(tmpPath).writeAsString(content);
```

6. Replace the AppBar save button's `onPressed` closure:

```dart
            onPressed: _saving ? null : _saveCurrent,
```

and add the helper next to `_saveFile`:

```dart
  Future<void> _saveCurrent() async {
    if (_saving) return;
    if (_useWebView) {
      final content =
          await _controller!.runJavaScriptReturningResult('getContent()');
      await _saveFile(content.toString());
    } else {
      await _saveFile(_textController.text);
    }
  }
```

7. Replace the `body:` expression:

```dart
      body: !_ready
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
          : _useWebView
              ? WebViewWidget(controller: _controller!)
              : _buildFallbackEditor(),
```

and add the fallback widget builder:

```dart
  /// Plain-Flutter editor for platforms without a webview implementation.
  Widget _buildFallbackEditor() {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveCurrent,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _saveCurrent,
      },
      child: TextField(
        controller: _textController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        autofocus: true,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFFD4D4D4),
          height: 1.5,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
        onChanged: (_) {
          if (!_isDirty) setState(() => _isDirty = true);
        },
      ),
    );
  }
```

8. Add the missing import at the top: `import 'package:flutter/services.dart';`

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/widgets/code_editor_screen_fallback_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/code_editor_screen.dart app/test/widgets/code_editor_screen_fallback_test.dart
git commit -m "fix(sftp): fallback text editor when webview is unavailable (#34)"
```

---

### Task 3: ExternalEditService (open externally, watch, auto-upload)

**Files:**
- Create: `app/lib/services/external_edit_service.dart`
- Test: `app/test/services/external_edit_service_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/services/external_edit_service_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/models/sftp_entry.dart';
import 'package:yourssh/services/external_edit_service.dart';
import 'package:yourssh/services/sftp_transfer_service.dart';
import 'package:yourssh/services/ssh_service.dart';
import 'package:yourssh/services/storage_service.dart';

class FakeTransferService extends SftpTransferService {
  FakeTransferService() : super(SshService(StorageService()));

  final uploads = <(String, String)>[]; // (localPath, remotePath)
  Object? uploadError;

  @override
  Future<String?> downloadToTemp(Host host, SftpEntry entry) async {
    final dir = await Directory.systemTemp.createTemp('yourssh_ext_test');
    final file = File('${dir.path}/${entry.name}');
    await file.writeAsString('remote content');
    return file.path;
  }

  @override
  Future<void> uploadFile(
      Host host, String localPath, String remotePath) async {
    final err = uploadError;
    if (err != null) throw err;
    uploads.add((localPath, remotePath));
  }
}

final _host = Host(label: 'h', host: 'example.com', username: 'u');
final _entry = SftpEntry(
  name: 'data.bin',
  path: '/srv/data.bin',
  isDirectory: false,
  size: 14,
  modifiedAt: DateTime(2026),
);

/// Polls [condition] until true or fails after 5 s (real timers — the
/// service does real file IO, so fakeAsync is not an option).
Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met within 5s');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late FakeTransferService transfer;
  late ExternalEditService service;
  late List<Uri> launched;

  setUp(() {
    transfer = FakeTransferService();
    launched = [];
    service = ExternalEditService(
      transfer,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
      pollInterval: const Duration(milliseconds: 30),
    );
  });

  tearDown(() => service.dispose());

  test('openExternal downloads the file and launches the local copy',
      () async {
    await service.openExternal(_host, _entry);

    expect(launched, hasLength(1));
    expect(launched.first.isScheme('file'), isTrue);
    expect(File.fromUri(launched.first).readAsStringSync(), 'remote content');
    expect(service.activeWatchCount, 1);
  });

  test('modifying the local copy uploads it back to the server', () async {
    await service.openExternal(_host, _entry);
    final local = File.fromUri(launched.first);
    final uploadedNames = <String>[];
    service.onUploaded = uploadedNames.add;

    await local.writeAsString('edited');
    local.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 2)));

    await _waitFor(() => transfer.uploads.isNotEmpty);
    expect(transfer.uploads.single.$2, '/srv/data.bin');
    expect(uploadedNames, ['data.bin']);
  });

  test('upload failure reports the error and keeps watching', () async {
    await service.openExternal(_host, _entry);
    final local = File.fromUri(launched.first);
    final errors = <String>[];
    service.onUploadError = (name, _) => errors.add(name);

    transfer.uploadError = Exception('network down');
    local.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 2)));
    await _waitFor(() => errors.isNotEmpty);
    expect(transfer.uploads, isEmpty);

    // Next save after the error must still upload.
    transfer.uploadError = null;
    local.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 4)));
    await _waitFor(() => transfer.uploads.isNotEmpty);
  });

  test('launch failure throws and does not start a watcher', () async {
    final failing = ExternalEditService(
      transfer,
      launcher: (_) async => false,
      pollInterval: const Duration(milliseconds: 30),
    );
    await expectLater(failing.openExternal(_host, _entry),
        throwsA(isA<ExternalEditException>()));
    expect(failing.activeWatchCount, 0);
  });

  test('dispose cancels all watchers', () async {
    await service.openExternal(_host, _entry);
    service.dispose();
    expect(service.activeWatchCount, 0);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd app && flutter test test/services/external_edit_service_test.dart`
Expected: FAIL — package import unresolved (file does not exist yet).

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/services/external_edit_service.dart
import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart' show launchUrl;

import '../models/host.dart';
import '../models/sftp_entry.dart';
import 'sftp_transfer_service.dart';

typedef ExternalLauncher = Future<bool> Function(Uri uri);

class ExternalEditException implements Exception {
  ExternalEditException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Opens remote files with the OS default application and uploads them back
/// when the external app saves changes (WinSCP-style external editing).
///
/// Watching polls mtime instead of using filesystem events: many editors
/// save atomically via rename-over, which silently breaks inotify/FSEvents
/// watches on the original path. Watchers run until [dispose].
class ExternalEditService {
  ExternalEditService(
    this._transferService, {
    ExternalLauncher? launcher,
    this.pollInterval = const Duration(seconds: 2),
  }) : _launch = launcher ?? launchUrl;

  final SftpTransferService _transferService;
  final ExternalLauncher _launch;
  final Duration pollInterval;

  /// Called after a changed file was uploaded back to the server.
  void Function(String fileName)? onUploaded;

  /// Called when uploading a changed file failed; watching continues so the
  /// next save retries.
  void Function(String fileName, Object error)? onUploadError;

  final List<_WatchSession> _sessions = [];
  int _sessionCounter = 0;

  int get activeWatchCount => _sessions.length;

  /// Downloads [entry], opens it with the OS default app and watches the
  /// local copy, uploading it back to [entry.path] whenever it changes.
  ///
  /// Throws [ExternalEditException] when the download or launch fails.
  Future<void> openExternal(Host host, SftpEntry entry) async {
    final tmpPath = await _transferService.downloadToTemp(host, entry);
    if (tmpPath == null) {
      throw ExternalEditException('Download failed for ${entry.name}');
    }
    // Move into a per-session directory so concurrent edits of equally
    // named files cannot clobber each other in the shared temp dir.
    final sessionDir = Directory(
        '${File(tmpPath).parent.path}/yourssh_edit/${_sessionCounter++}');
    await sessionDir.create(recursive: true);
    final localFile =
        await File(tmpPath).rename('${sessionDir.path}/${entry.name}');

    if (!await _launch(Uri.file(localFile.path))) {
      throw ExternalEditException(
          'No application found to open ${entry.name}');
    }

    final session = _WatchSession(
      host: host,
      entry: entry,
      file: localFile,
      lastModified: localFile.lastModifiedSync(),
    );
    session.timer = Timer.periodic(pollInterval, (_) => _poll(session));
    _sessions.add(session);
  }

  Future<void> _poll(_WatchSession session) async {
    if (session.uploading) return;
    final DateTime mtime;
    try {
      mtime = session.file.lastModifiedSync();
    } on FileSystemException {
      return; // file briefly missing during an atomic save — retry next tick
    }
    if (mtime.isAtSameMomentAs(session.lastModified)) return;
    session.lastModified = mtime;
    session.uploading = true;
    try {
      await _transferService.uploadFile(
          session.host, session.file.path, session.entry.path);
      onUploaded?.call(session.entry.name);
    } catch (e) {
      onUploadError?.call(session.entry.name, e);
    } finally {
      session.uploading = false;
    }
  }

  void dispose() {
    for (final session in _sessions) {
      session.timer?.cancel();
    }
    _sessions.clear();
  }
}

class _WatchSession {
  _WatchSession({
    required this.host,
    required this.entry,
    required this.file,
    required this.lastModified,
  });

  final Host host;
  final SftpEntry entry;
  final File file;
  DateTime lastModified;
  Timer? timer;
  bool uploading = false;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/services/external_edit_service_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/external_edit_service.dart app/test/services/external_edit_service_test.dart
git commit -m "feat(sftp): external edit service with mtime watch and auto-upload"
```

---

### Task 4: Wire entry points (context menu, double-click, editor binary check)

**Files:**
- Modify: `app/lib/widgets/sftp_entry_context_menu.dart`
- Modify: `app/lib/widgets/sftp_panel.dart`
- Modify: `app/lib/widgets/dual_panel_sftp_screen.dart:280-285`
- Modify: `app/lib/widgets/code_editor_screen.dart` (binary-content check)
- Test: `app/test/widgets/sftp_entry_context_menu_test.dart`
- Test: extend `app/test/widgets/code_editor_screen_fallback_test.dart`

- [ ] **Step 1: Write the failing context-menu test**

```dart
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd app && flutter test test/widgets/sftp_entry_context_menu_test.dart`
Expected: FAIL — `No named parameter with the name 'onOpenExternal'`.

- [ ] **Step 3: Add the menu item to `sftp_entry_context_menu.dart`**

1. Add the field + constructor param after `onEdit`:

```dart
  final VoidCallback? onEdit;
  final VoidCallback? onOpenExternal;
```

```dart
    this.onEdit,
    this.onOpenExternal,
```

2. Add the menu item right after the `edit` item (before the first divider):

```dart
        if (!entry.isDirectory && onOpenExternal != null)
          const PopupMenuItem(value: _Action.openExternal, height: 34,
              child: _Item(icon: Icons.launch, label: 'Open with external app')),
```

3. Extend the enum and the switch:

```dart
enum _Action { open, edit, openExternal, rename, delete, copyPath }
```

```dart
        case _Action.openExternal: onOpenExternal?.call();
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd app && flutter test test/widgets/sftp_entry_context_menu_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing editor binary-content test**

Append to `app/test/widgets/code_editor_screen_fallback_test.dart`. Add the imports and fake at top level:

```dart
import 'package:yourssh/services/external_edit_service.dart';
```

```dart
class FakeExternalEditService extends ExternalEditService {
  FakeExternalEditService(SftpTransferService transfer) : super(transfer);

  final opened = <SftpEntry>[];

  @override
  Future<void> openExternal(Host host, SftpEntry entry) async {
    opened.add(entry);
  }
}
```

And the test (pushes the editor from a stub home so `Navigator.pop` has somewhere to go):

```dart
  testWidgets('binary content offers external open and closes the editor',
      (tester) async {
    final service = FakeTransferService(const [0x7f, 0x45, 0x4c, 0x46, 0x00]);
    final external = FakeExternalEditService(service);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => MultiProvider(
                providers: [
                  Provider<SftpTransferService>.value(value: service),
                  Provider<ExternalEditService>.value(value: external),
                ],
                child: CodeEditorScreen(host: _host, entry: _entry),
              ),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Open externally'), findsOneWidget);
    await tester.tap(find.text('Open externally'));
    await tester.pumpAndSettle();

    expect(external.opened, hasLength(1));
    expect(find.byType(CodeEditorScreen), findsNothing);
  });
```

- [ ] **Step 6: Run it to verify it fails**

Run: `cd app && flutter test test/widgets/code_editor_screen_fallback_test.dart`
Expected: the new test FAILS (`Open externally` not found — binary content currently loads into the editor as garbage); the 3 existing tests still pass.

- [ ] **Step 7: Add the binary check to `code_editor_screen.dart`**

1. Add imports:

```dart
import '../services/external_edit_service.dart';
import '../services/sftp_file_inspector.dart';
```

2. In `_loadFile`, right after `final bytes = await File(tmpPath).readAsBytes();` and its `mounted` guard, insert:

```dart
      if (looksBinary(bytes)) {
        await _offerExternalOpen();
        return;
      }
```

3. Add the dialog helper (same visual style as `_showDiscardDialog`):

```dart
  /// Shown when downloaded content turns out to be binary: offer to hand the
  /// file to the OS default app instead, then close the editor either way.
  Future<void> _offerExternalOpen() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Cannot edit in-app',
            style: TextStyle(color: Color(0xFFD4D4D4), fontSize: 14)),
        content: Text(
          '"${widget.entry.name}" appears to be a binary file.\n'
          'Open it with an external application instead? Changes saved '
          'there are uploaded back automatically.',
          style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF888888)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open externally',
                  style: TextStyle(color: Color(0xFF22C55E)))),
        ],
      ),
    );
    if (!mounted) return;
    if (open == true) {
      try {
        await context
            .read<ExternalEditService>()
            .openExternal(widget.host, widget.entry);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Open externally failed: $e'),
              backgroundColor: Colors.red));
        }
      }
    }
    if (mounted) Navigator.of(context).pop();
  }
```

- [ ] **Step 8: Run the editor tests to verify all pass**

Run: `cd app && flutter test test/widgets/code_editor_screen_fallback_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 9: Provide the service and wire the SFTP panel**

No new tests — pure wiring of already-tested pieces, verified by `flutter analyze` and the full test run in Task 5.

1. `app/lib/widgets/dual_panel_sftp_screen.dart` — register the service in the `MultiProvider` (line ~282):

```dart
      providers: [
        Provider(create: (ctx) => SftpTransferService(ctx.read<SshService>())),
        Provider(create: (ctx) => SftpFileOpsService(ctx.read<SshService>())),
        Provider(
          create: (ctx) =>
              ExternalEditService(ctx.read<SftpTransferService>()),
          dispose: (_, ExternalEditService s) => s.dispose(),
        ),
        ChangeNotifierProvider.value(value: _transferProvider),
      ],
```

with import `import '../services/external_edit_service.dart';`.

2. `app/lib/widgets/sftp_panel.dart` — add imports:

```dart
import '../services/external_edit_service.dart';
import '../services/sftp_file_inspector.dart';
```

3. Replace `_onEntryTap` (lines 65–80) with:

```dart
  void _onEntryTap(SftpEntry entry) {
    if (entry.isDirectory) {
      _loadDirectory(entry.path);
      return;
    }
    final reason = editBlockReason(entry);
    if (reason != EditBlockReason.none) {
      _confirmOpenExternal(entry, reason);
    } else {
      _openEditor(entry);
    }
  }

  Future<void> _openEditor(SftpEntry entry) {
    final service = context.read<SftpTransferService>();
    final externalEdit = context.read<ExternalEditService>();
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            Provider<SftpTransferService>.value(value: service),
            Provider<ExternalEditService>.value(value: externalEdit),
          ],
          child: CodeEditorScreen(host: widget.host!, entry: entry),
        ),
      ),
    );
  }

  /// File failed the pre-download check (binary extension / too large):
  /// offer to open it with the OS default application instead.
  Future<void> _confirmOpenExternal(
      SftpEntry entry, EditBlockReason reason) async {
    final why = switch (reason) {
      EditBlockReason.binaryExtension => 'This looks like a binary file.',
      EditBlockReason.tooLarge =>
        'This file is too large for the in-app editor.',
      EditBlockReason.none => '',
    };
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Cannot edit in-app',
            style: TextStyle(color: Color(0xFFD4D4D4), fontSize: 14)),
        content: Text(
          '$why\nOpen "${entry.name}" with an external application instead? '
          'Changes saved there are uploaded back automatically.',
          style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF888888)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open externally',
                  style: TextStyle(color: Color(0xFF22C55E)))),
        ],
      ),
    );
    if (open == true && mounted) await _openExternal(entry);
  }

  Future<void> _openExternal(SftpEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<ExternalEditService>();
    service.onUploaded = (name) => messenger.showSnackBar(SnackBar(
        content: Text('Uploaded $name to server'),
        duration: const Duration(seconds: 2)));
    service.onUploadError = (name, e) => messenger.showSnackBar(SnackBar(
        content: Text('Upload of $name failed: $e'),
        backgroundColor: const Color(0xFF2A1A1A)));
    try {
      await service.openExternal(widget.host!, entry);
      messenger.showSnackBar(SnackBar(
          content: Text('Opened ${entry.name} — watching for changes'),
          duration: const Duration(seconds: 2)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Open externally failed: $e'),
          backgroundColor: const Color(0xFF2A1A1A)));
    }
  }
```

4. In `_buildEntryTile`, pass the new callback to `SftpEntryContextMenu`:

```dart
      onEdit: entry.isDirectory ? null : () => _onEntryTap(entry),
      onOpenExternal:
          entry.isDirectory ? null : () => _openExternal(entry),
```

5. In `_showNewFileDialog`, replace the inline `Navigator.push(...)` block (lines ~430–439) with the shared helper:

```dart
      if (!mounted) return;
      await _openEditor(entry);
```

(The `final service = context.read<SftpTransferService>();` line above it is removed too.)

- [ ] **Step 10: Analyze and commit**

Run: `cd app && flutter analyze`
Expected: No issues found.

```bash
git add app/lib/widgets/sftp_entry_context_menu.dart app/lib/widgets/sftp_panel.dart app/lib/widgets/dual_panel_sftp_screen.dart app/lib/widgets/code_editor_screen.dart app/test/widgets/sftp_entry_context_menu_test.dart app/test/widgets/code_editor_screen_fallback_test.dart
git commit -m "feat(sftp): open uneditable files with external app, auto-upload on save"
```

---

### Task 5: Full verification, changelog, docs

**Files:**
- Modify: `CHANGELOG.md` (Unreleased section)
- Modify: `CLAUDE.md` (services list)

- [ ] **Step 1: Run the full test suite and analyzer**

Run: `cd app && flutter analyze && flutter test`
Expected: analyzer clean, all tests pass (pre-existing skips excepted).

- [ ] **Step 2: Update CHANGELOG.md under `[Unreleased]`**

Add below the existing `### Added` entry:

```markdown
- **Open with external app (SFTP)** — files the in-app editor cannot handle (binary formats, files over 5 MB) now offer to open with your OS default application instead; any file can also be opened externally from the SFTP context menu. While the file is open, yourssh watches the local copy and automatically uploads it back to the server every time the external app saves (WinSCP-style external editing).

### Fixed
- **SFTP file editing on Linux/Windows** — double-clicking a file in the SFTP panel no longer blanks the entire window on platforms where the embedded webview (Monaco) is unavailable. The editor now falls back to a plain-text editor with save support (`Ctrl+S`). ([#34](https://github.com/YoursshLabs/yourssh/issues/34))
```

- [ ] **Step 3: Update CLAUDE.md services list**

Add to the **Services** bullet list (after `SftpTransferService`):

```markdown
- `ExternalEditService` — "open with external app" for SFTP files: downloads to a per-session temp dir, launches the OS default app (`url_launcher`), polls mtime every 2 s and auto-uploads changes back to the server; `sftp_file_inspector.dart` (pure) decides which files the in-app editor refuses (binary extension, > 5 MB, null byte in first 8 KB)
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md CLAUDE.md
git commit -m "docs: changelog + service docs for SFTP external edit (#34)"
```

---

## Self-Review Notes

- **Spec coverage:** fallback editor (Task 2), detection (Task 1 + wiring in Task 4), external edit with watch/auto-upload (Task 3), context-menu + double-click entry points (Task 4), error handling (snackbars in Task 4, exception paths tested in Task 3), testing strategy (Tasks 1–4). Changelog/docs in Task 5.
- **Type consistency:** `EditBlockReason`/`editBlockReason`/`looksBinary` (Task 1) used in Task 4; `ExternalEditService.openExternal/onUploaded/onUploadError/activeWatchCount/dispose` (Task 3) used in Task 4 and its tests; `FakeTransferService(List<int> bytes)` matches both Task 2 and Task 4 usage.
- **Known trade-off:** `_offerExternalOpen` re-downloads via `ExternalEditService` instead of reusing the already-downloaded temp copy — accepted for simplicity (YAGNI).
