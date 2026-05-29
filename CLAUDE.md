# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Run on macOS (primary target)
cd app && flutter run -d macos

# Run on Windows
cd app && flutter run -d windows

# Build
cd app && flutter build macos
cd app && flutter build windows

# Lint / analyze
cd app && flutter analyze

# Tests
cd app && flutter test
cd app && flutter test test/services/sync_service_test.dart   # single test file
```

## Makefile targets (Rust core — inactive/future)

```bash
make setup          # Install deps (Rust targets, xcodegen)
make core           # Build universal .a + Swift bindings
make swift-bindings # Regenerate Swift bindings only
make open           # Generate Xcode project and open it
make clean          # Remove Rust build artifacts + generated bindings
```

## Architecture

The active codebase is `app/` — a Flutter app targeting macOS and Windows. The `core/` Rust library is **not currently used at runtime**; it was built in Sprint 1 and kept for future `flutter_rust_bridge` integration.

**Data flow:**

```
Flutter UI (widgets/screens)
  └── Providers (ChangeNotifier, via provider package)
        └── SshService / StorageService
              └── dartssh2 (SSH, SFTP, port forwarding)
              └── flutter_secure_storage (Keychain / Credential Manager)
              └── shared_preferences (host list, app settings)
```

**Providers** (`app/lib/providers/`):
- `HostProvider` — CRUD for saved SSH hosts; fires `onMutation` callback to trigger sync push
- `SessionProvider` — manages active `SshSession` objects; wires key lookup, auto-reconnect, tmux, and host-key verification via callbacks set in `main.dart`
- `KeyProvider` — SSH key entries (path + optional passphrase)
- `PortForwardProvider` — local/remote/dynamic tunnel configs
- `SnippetProvider` — reusable command snippets
- `SyncProvider` — holds sync config (Supabase URL/key, enabled flag, status)
- `KnownHostsProvider` — persists known host fingerprints; exposes `pendingChallenge` for TOFU dialog
- `SettingsProvider` — app-wide prefs (auto-reconnect, tmux, hotkeys, feature flags for DevOps/WebTools/Snippets)
- `TerminalLayoutProvider` — split layout (none/horizontal/vertical) and input bar visibility
- `LocalSessionProvider` — manages local shell sessions via `flutter_pty`
- `AiChatProvider` — AI chat sidebar state (messages, Claude API calls)

**Services** (`app/lib/services/`):
- `SshService` — owns `SSHClient` and `SSHSession` maps keyed by host ID; handles connect, shell, exec, sftp, `testConnection` (TCP+auth without opening a shell), disconnect
- `StorageService` — host list as JSON in `SharedPreferences`; passwords/passphrases in `FlutterSecureStorage` (`pw_<hostId>`, `pp_<keyId>`); falls back to `SharedPreferences` if secure storage fails
- `SyncService` — push/pull host data encrypted via `SyncEncryption` (AES-256-GCM, key derived from Supabase anon key) to a Supabase table; retries failed pushes every 30 s via a timer
- `SupabaseService` — thin HTTP wrapper around Supabase REST API (upsert/fetch/delete a single row in `sync_data` table); no `supabase_flutter` SDK used here — raw `http` calls
- `LocalShellService` / `PtyRunner` — local terminal via `flutter_pty`
- `HotkeyService` — global hotkey registration via `hotkey_manager`; hotkey names (`new_session`, `close_session`, `next_session`, `prev_session`, `toggle_input_bar`, `split_horizontal`, `split_vertical`) are configured in `SettingsProvider`

**Key models** (`app/lib/models/`):
- `Host` — connection profile (host, port, username, `AuthType`: password/privateKey/agent)
- `SshSession` — wraps an xterm `Terminal`; bridges `dartssh2` shell I/O to the widget; has `SessionStatus` (connecting/connected/disconnected/error) and reconnect attempt counter
- `SshKeyEntry`, `PortForward`, `Snippet`, `KnownHost`

**UI entry point:** `app/lib/main.dart` — instantiates services and long-lived providers, wires callbacks between them (key lookup, host-key verifier, sync-on-mutation), then mounts `MainScreen` under `MultiProvider`. The app is dark-only (`ThemeMode.dark`); theme constants live in `app/lib/theme/app_theme.dart` (`AppColors`).

**Navigation:** `MainScreen` (`app/lib/screens/main_screen.dart`) renders a top tab bar (pinned Home/SFTP + scrollable SSH session tabs) and a left sidebar (`NavSection` enum). Active SSH sessions display `SplitTerminalView`; navigation sections map to top-level screen widgets in `app/lib/widgets/`.

## Sync feature

Sync is opt-in. When enabled, host data is AES-256-GCM encrypted (key = HKDF-SHA256 of the Supabase anon key) before upload. `SyncService.push` is called via `HostProvider.onMutation` on every host change and retried every 30 s if a push fails (`sync_pending_push` flag in `SharedPreferences`). `SyncService.pull` is called on `WindowFocus` and only applies remote data if `remote.updated_at > last_push_at`.

## Credential storage

Passwords use a dual-write strategy: primary is `FlutterSecureStorage` (Keychain on macOS, Credential Manager on Windows); fallback read/write to `SharedPreferences` for environments where secure storage is unavailable. Key: `pw_<hostId>` for passwords, `pp_<keyId>` for key passphrases.
