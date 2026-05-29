# SFTP Enhancements Design

**Date:** 2026-05-29  
**Status:** Approved

## Summary

Add five missing capabilities to the SFTP dual-panel screen:
1. File operations (rename, delete, create folder) via context menu + toolbar
2. Checkbox multi-select
3. Recursive folder upload/download (skip existing)
4. Per-file + overall progress tracking with dialog
5. Second remote panel (3-column layout) for remote-to-remote copy

## Architecture

### New files

| File | Purpose |
|------|---------|
| `app/lib/models/sftp_transfer_item.dart` | State of one file in the transfer queue |
| `app/lib/providers/sftp_transfer_provider.dart` | Transfer queue + progress state |
| `app/lib/services/sftp_file_ops_service.dart` | Rename, delete, mkdir on remote |
| `app/lib/widgets/sftp_entry_context_menu.dart` | Right-click context menu widget |
| `app/lib/widgets/sftp_transfer_dialog.dart` | Progress dialog (per-file + overall) |

### Modified files

| File | Changes |
|------|---------|
| `app/lib/services/sftp_transfer_service.dart` | Add `uploadDirectory`, `downloadDirectory` with progress callbacks |
| `app/lib/providers/sftp_panel_provider.dart` | Add checkbox selection (replaces right-click-only selection) |
| `app/lib/widgets/sftp_panel.dart` | Add checkbox column, toolbar actions, context menu |
| `app/lib/widgets/dual_panel_sftp_screen.dart` | 3-column layout (Local | RemoteA | RemoteB) |

## Models

### `SftpTransferItem`

```dart
enum TransferDirection { upload, download }
enum TransferStatus { pending, inProgress, done, skipped, error }

class SftpTransferItem {
  final String id;           // uuid
  final String fileName;
  final TransferDirection direction;
  TransferStatus status;
  int bytesTransferred;
  int totalBytes;
  String? errorMessage;

  double get progress => totalBytes > 0 ? bytesTransferred / totalBytes : 0;
}
```

## Services

### `SftpFileOpsService`

```dart
class SftpFileOpsService {
  SftpFileOpsService(SshService sshService);

  Future<void> rename(Host host, String oldPath, String newPath);
  Future<void> delete(Host host, String path, {required bool isDirectory});
  // delete(folder): list → delete each child recursively → rmdir
  Future<void> mkdir(Host host, String path);
}
```

### `SftpTransferService` additions

```dart
Future<void> uploadDirectory({
  required String localDir,
  required Host remoteHost,
  required String remoteDir,
  required void Function(String filePath) onFileStart,
  required void Function(String filePath, int bytes, int total) onProgress,
  required void Function(String filePath) onFileSkipped,
});

Future<void> downloadDirectory({
  required Host remoteHost,
  required SftpEntry remoteDir,
  required String localDir,
  required void Function(String filePath) onFileStart,
  required void Function(String filePath, int bytes, int total) onProgress,
  required void Function(String filePath) onFileSkipped,
});
```

Both methods skip files that already exist at the destination (compare by name only, no checksum).

## Providers

### `SftpTransferProvider`

```dart
class SftpTransferProvider extends ChangeNotifier {
  List<SftpTransferItem> get items;
  bool get isTransferring;
  double get overallProgress;   // total bytes transferred / total bytes
  int get completedCount;
  int get totalCount;
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  void startBatch(List<SftpTransferItem> items);
  void updateItem(String id, {int? bytesTransferred, TransferStatus? status, String? errorMessage});
  void cancel();   // sets _cancelled = true; caller checks this flag
  void clear();
}
```

Injected at `DualPanelSftpScreen` level, shared across all three panels.

### `SftpPanelProvider` changes

- `toggleSelection(entry)` remains for programmatic use
- Add `selectAll()`, `deselectAll()`
- Selection is now driven by checkbox tap, not right-click

## Widgets

### `SftpEntryContextMenu`

Wraps each list row in a `GestureDetector` that captures `onSecondaryTapUp` and calls `showMenu()` at the tap position.

Menu items:
- **Open** (file) → push `CodeEditorScreen`
- **Enter** (folder) → navigate into folder
- **Rename** → inline rename dialog (single text field)
- **Delete** → confirm dialog before deleting
- **Copy path** → copies full remote path to clipboard
- Separator between navigation and destructive actions

### `SftpTransferDialog`

Shown automatically when `SftpTransferProvider.isTransferring == true` via a `ValueListenableBuilder` in `DualPanelSftpScreen`. Non-dismissible.

```
┌──────────────────────────────────────────┐
│  Transferring 3 / 12 files               │
│  ████████░░░░░░░░  38%          [Cancel] │
├──────────────────────────────────────────┤
│  ✓  config.json           12 KB          │
│  ↑  deploy.sh   ████░░    45%            │
│  ○  README.md   pending                  │
│  ○  assets/     pending                  │
└──────────────────────────────────────────┘
```

- Auto-closes 1.5s after all items reach `done`/`skipped`/`error`
- Cancel button calls `SftpTransferProvider.cancel()`; loops in services check `isCancelled`

### `SftpPanel` toolbar (updated path bar)

```
[↑]  [user@host ▾]  /current/path   [+Folder] [Rename] [Delete] [↺]
```

- `+Folder` always enabled when connected
- `Rename` enabled when exactly 1 item selected
- `Delete` enabled when ≥ 1 item selected; shows confirm dialog listing selected names

### Checkbox column

Each entry row gains a leading `Checkbox` widget. Header row has a "select all" checkbox. Clicking the checkbox toggles selection. Clicking the filename/icon retains original navigation behavior.

## Layout — 3-column

```
┌──────────────┬──────┬──────────────┬──────┬──────────────┐
│  LOCAL       │      │  REMOTE A    │      │  REMOTE B    │
│              │  ←→  │              │  ←→  │              │
│  LocalPanel  │ 36px │  SftpPanel   │ 36px │  SftpPanel   │
└──────────────┴──────┴──────────────┴──────┴──────────────┘
```

Transfer bar 1 (Local ↔ RemoteA): Upload →, Download ←  
Transfer bar 2 (RemoteA ↔ RemoteB): A→B, B→A  

RemoteB→RemoteA/Local transfers route through local temp dir (download → upload pattern).

## Error handling

- All file ops show a `SnackBar` on failure with the error message
- Delete of a non-empty folder: recursive delete starting from deepest children
- Transfer cancel: files partially written are left in place (no cleanup)
- SFTP session errors during transfer: mark item as `error`, continue remaining items

## Out of scope

- Checksum-based skip (skip by filename only)
- Move operation (copy + delete source) — can be added later
- Resumable transfers
