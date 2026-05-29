# Test Connection Feature — Design Spec

**Date:** 2026-05-29

## Overview

Add a "TEST CONNECTION" feature that lets users verify SSH reachability and authentication before opening a full session. Available in two places: the Host Detail Panel (editing/adding) and host cards in the Dashboard.

## Backend — `SshService.testConnection()`

New method signature:
```dart
Future<({bool success, int latencyMs, String? error})> testConnection(
  Host host, {
  String? password,
  SshKeyEntry? keyEntry,
}) async
```

Behavior:
- Opens TCP socket via `SSHSocket.connect` wrapped in a 10-second timeout
- Creates `SSHClient` and awaits `client.authenticated`
- Closes the client immediately after (not stored in `_clients`)
- Records wall-clock latency from socket open to auth complete
- On any exception, maps it to a human-readable error string:
  - `SocketException` / `TimeoutException` → "Host unreachable"
  - `SSHAuthFailException` (or auth error substring) → "Authentication failed"
  - Other → exception message truncated to 80 chars
- Returns `({success: true, latencyMs: N, error: null})` or `({success: false, latencyMs: 0, error: "…"})`

## HostDetailPanel — "TEST CONNECTION" button

**Placement:** Between the AUTH METHOD card and the CONNECT button.

**States:**
- Idle: outlined button "TEST CONNECTION" (full width, secondary style)
- Testing: button disabled, spinner + "TESTING…"
- Success: green badge row — `✓ Connected · 42ms`
- Failed: red badge row — `✗ Authentication failed`

**Reset triggers:** Result clears when the user edits host, port, username, password, or auth method fields.

**Data flow:** Reads credentials directly from form controllers (not from storage), so works for both new and existing hosts with unsaved changes.

**Button text rules:** All button labels uppercase — "TEST CONNECTION", "CONNECT", "SAVE ONLY".

## HostsDashboard — host card test action

**Placement:** Small "TEST" icon button appears on hover over a host card (alongside the existing edit/connect actions).

**States:** Same as panel — idle → testing (spinner) → success (green badge) / failed (red badge) shown inline on the card.

**Data flow:** Uses credentials from storage (same path as a real connect).

**Reset:** Result clears after 8 seconds automatically, or when the card is re-hovered after navigation.

## Error message mapping

| Exception type | Displayed message |
|---|---|
| SocketException / TimeoutException | "Host unreachable" |
| SSH auth failure | "Authentication failed" |
| Anything else | Raw message (max 80 chars) |

## Out of scope

- Saving test results across sessions
- Testing from the Known Hosts or Port Forwarding screens
- Batch-testing multiple hosts at once
