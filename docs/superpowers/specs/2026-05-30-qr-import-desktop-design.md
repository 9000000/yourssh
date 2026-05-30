# QR Import — Desktop Text/File Input

**Date:** 2026-05-30
**Branch:** feat/ssh-certificate-auth
**Status:** Approved

## Problem

`QrImportScreen` uses `mobile_scanner` which requires a camera API only available on iOS/Android. The app targets macOS and Windows (desktop only), so the "Scan QR Code" import flow is broken on all supported platforms.

## Goal

Replace camera-based QR scanning with paste-text and file-based input. Keep the same P2P HTTP transfer infrastructure underneath (URL + AES key encoded in JSON). Also add a "Copy transfer code" button to the export dialog so desktop-to-desktop flow works end-to-end.

## Use Cases

- **Desktop → Desktop:** Exporter copies transfer code to clipboard, importer pastes it.
- **Mobile → Desktop:** Mobile shows QR + copyable text; user transfers text to desktop (cross-device clipboard, manual copy, etc.) and pastes into import dialog.

## Architecture

No new services or providers. Changes are UI-only and confined to three files.

```
QrExportDialog  ──►  adds "Copy transfer code" button (copies _qrData JSON)
QrImportDialog  ──►  replaces QrImportScreen; AlertDialog with paste + file input
SyncSettingsScreen  ──►  wires "Import via Code" button to showDialog(QrImportDialog)
pubspec.yaml  ──►  removes mobile_scanner dependency
```

The underlying P2P flow is unchanged: JSON `{"u": url, "k": base64key}` → HTTP fetch → AES decrypt → `hostProvider.replaceAll()`.

## Components

### QrExportDialog (modified)

- Add **"Copy transfer code"** `TextButton` to `AlertDialog.actions`.
- Button is disabled when `_qrData == null` (server not yet ready).
- On press: `Clipboard.setData(ClipboardData(text: _qrData!))` then show a brief "Copied!" SnackBar or change button label momentarily.
- All other content (QR image, countdown, interface dropdown) unchanged.

### QrImportDialog (new, replaces QrImportScreen)

Widget: `StatefulWidget`, shown via `showDialog`.

Layout (AlertDialog):
- **Title:** "Import via Transfer Code"
- **Content:**
  - `TextField` (multiline=false, autofocus, monospace hint) — for pasting JSON
  - Row with `TextButton("Load from file")` — opens `file_picker`, reads file content into controller
  - If `_error != null`: red error text below field
  - If `_processing`: `LinearProgressIndicator` below field
- **Actions:** `TextButton("Cancel")` · `FilledButton("Import")` (disabled while processing or field empty)

Error handling mirrors existing `QrImportScreen`:
- `FormatException` → "Invalid transfer code."
- Network errors → "Cannot reach device. Make sure both are on the same network."
- Other → stripped exception message

On success: SnackBar "Imported N host(s). All previous hosts replaced." then `Navigator.of(context).pop()`.

### SyncSettingsScreen (modified)

- Change "Scan QR Code" button label → **"Import via Code"**
- Change icon → `Icons.content_paste`
- Change handler: `Navigator.push(QrImportScreen)` → `showDialog(QrImportDialog)`

### pubspec.yaml (modified)

- Remove `mobile_scanner` from dependencies.

## Data Flow

```
User pastes JSON  ──►  TextField controller
                        │
                        ▼
"Import" pressed  ──►  jsonDecode(text)  ──►  url, key
                        │
                        ▼
                  P2PSyncService.fetchPayload(url)
                        │
                        ▼
                  P2PSyncEncryption.decrypt(encrypted, key)
                        │
                        ▼
                  SyncService.parsePayload(decrypted)
                        │
                        ▼
                  HostProvider.replaceAll(hosts, passwords)
```

## Error Handling

| Scenario | Message |
|---|---|
| Invalid JSON / missing fields | "Invalid transfer code." |
| HTTP error or connection refused | "Cannot reach device. Make sure both are on the same network." |
| Timeout | Same as above |
| Empty host list in payload | "No hosts found in transfer" |

## Files Changed

| File | Change |
|---|---|
| `app/lib/widgets/qr_export_dialog.dart` | Add "Copy transfer code" button |
| `app/lib/widgets/qr_import_screen.dart` | Delete |
| `app/lib/widgets/qr_import_dialog.dart` | New — AlertDialog implementation |
| `app/lib/widgets/sync_settings_screen.dart` | Update import + button wiring |
| `app/pubspec.yaml` | Remove `mobile_scanner` |

## Out of Scope

- Camera-based scanning (removed entirely for desktop targets)
- Preview of hosts before import (possible future enhancement)
- Cross-device clipboard automation
