# Host Action Menu — Extended Actions

**Date:** 2026-05-29  
**Status:** Approved

## Overview

Extend the per-host right-click/long-press action menu in `hosts_dashboard.dart` with four new actions: Duplicate, Copy SSH URL, Move to Group, and Export. The current menu has 5 items (Connect, SFTP, Edit, divider, Delete); the new menu will have 9 items across three logical groups.

## New Menu Layout

```
Connect
SFTP
Edit
──────────
Duplicate
Copy SSH URL
Move to Group
Export
──────────
Delete
```

## Feature Specifications

### 1. Duplicate

**Trigger:** User taps "Duplicate" in the menu.

**Behavior:**
1. Create a copy of the host: new UUID (via `Uuid().v4()`), all fields identical except `label` which gets `" (copy)"` appended and `createdAt` which is set to now.
2. Call `hostProvider.addHost(copy)` to persist it.
3. Call `widget.onEditHost?.call(copy)` to open the Edit Host panel so the user can rename/adjust before saving.

**No new provider method required** — logic handled inline in the menu tap callback.

**Icon:** `Icons.copy_outlined`

---

### 2. Copy SSH URL

**Trigger:** User taps "Copy SSH URL" in the menu.

**Behavior:**
1. Format the URL: `ssh://${host.username}@${host.host}:${host.port}`
2. Write to clipboard: `Clipboard.setData(ClipboardData(text: url))`
3. Show a brief SnackBar via `ScaffoldMessenger`: *"SSH URL copied"* (no action button, auto-dismiss).

**Icon:** `Icons.link_outlined`

---

### 3. Move to Group

**Trigger:** User taps "Move to Group" in the menu.

**Behavior:**
1. Opens a compact `showDialog` listing all distinct non-empty groups derived from `hostProvider.allHosts` at call-time, plus a "No group" option at the top to clear the group.
2. The current group is visually highlighted (checkmark icon).
3. On selection: call `hostProvider.updateHost(host.copyWith(group: selectedGroup))`. Selecting "No group" calls `updateHost` with `group: ''`.
4. If there are no other groups in the system (only the current host's group or all hosts have no group), still show the dialog with just "No group" — no special empty state needed.

**No new provider method required** — uses existing `updateHost`.

**Icon:** `Icons.drive_file_move_outlined`

---

### 4. Export

**Trigger:** User taps "Export" in the menu.

**Behavior:**
1. Opens a `showDialog` with two format tabs/buttons at the top: **`.ssh/config`** and **JSON**.
2. The dialog displays the generated text in a scrollable, monospace `SelectableText` widget.
3. A "Copy" button copies the currently displayed text to clipboard.
4. Switching format tabs regenerates the text inline (no network call, pure string formatting).

**`.ssh/config` format:**
```
Host <label>
    HostName <host>
    User <username>
    Port <port>
```
Password and private key paths are never exported (stored in secure storage, not accessible without `KeyProvider` which is out of scope for this menu). The `authType` field in JSON indicates the auth method.

**JSON format:**
```json
{
  "label": "...",
  "host": "...",
  "port": 22,
  "username": "...",
  "authType": "password",
  "group": "...",
  "tags": []
}
```
`id`, `createdAt`, and `keyId` are excluded from the export JSON (they are instance-specific).

**Icon:** `Icons.upload_outlined`

---

## Architecture

All changes are confined to `app/lib/widgets/hosts_dashboard.dart` and a new private dialog widget for Export (can be a private `_ExportDialog` class at the bottom of the same file). No new files, no provider changes, no model changes.

**Imports to add:**
- `package:flutter/services.dart` (for `Clipboard`)

**Helper needed:** `_moveToGroupDialog(BuildContext, Host, HostProvider)` — private function in the same file.  
**Helper needed:** `_ExportDialog` — private `StatefulWidget` in the same file (stateful to track selected format tab).

## Error Handling

- `Clipboard.setData` is fire-and-forget; no error handling needed.
- `hostProvider.addHost` and `updateHost` already handle persistence errors internally.
- Export text generation is pure string formatting; no errors possible.

## Out of Scope

- Creating a new group from the "Move to Group" dialog (user must create a group by editing a host's group field directly).
- File system export (Save As dialog) — clipboard copy is sufficient.
- "Collaborate" and "Copy to" features shown in the reference screenshot.
