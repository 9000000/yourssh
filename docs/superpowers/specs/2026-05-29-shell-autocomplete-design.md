# Shell Autocomplete Design

**Date:** 2026-05-29
**Status:** Approved

## Overview

Add history-based autocomplete to both the `TerminalInputBar` overlay and the raw xterm terminal. Suggestions are sourced exclusively from `CommandHistoryProvider` (no external requests, no shell round-trips). No new packages required.

## Scope

- **In scope:** `TerminalInputBar` keyboard navigation + Tab completion; raw xterm autocomplete via keystroke interception + fixed popup overlay.
- **Out of scope:** Shell-native completions (compgen/bash), path completion, static command dictionaries, cursor-following popup.

## Components

### 1. `suggestion_popup.dart` (new)

Reusable stateless widget shared by both surfaces.

```
SuggestionPopup({
  required List<String> suggestions,  // max 8 shown
  required int selectedIndex,         // -1 = none highlighted
  required void Function(String) onSelect,
  double maxHeight = 160,
})
```

- Dark container: background `#1C1C1C`, border `#2A2A2A`, border-radius 4
- Normal item: text `#D4D4D4`, monospace 13px
- Selected item: background `#1E3A5F`, text `#7DD3FC`
- Scrollable when items exceed `maxHeight`

### 2. `terminal_input_bar.dart` (modified)

**New state:** `int _selectedIndex = -1`

**Tab key behavior:**
- `_suggestions` non-empty → set `_controller.text = _suggestions[max(0, _selectedIndex)]`, move cursor to end, do NOT submit
- `_suggestions` empty → insert literal `\t`

**Arrow key behavior (when suggestions visible):**
- `↑` → `_selectedIndex = (_selectedIndex - 1).clamp(-1, _suggestions.length - 1)`
- `↓` → `_selectedIndex = (_selectedIndex + 1).clamp(-1, _suggestions.length - 1)`
- When `_suggestions.isEmpty`, arrows fall through to existing history navigation

**Enter behavior:** if `_selectedIndex >= 0` and suggestions visible → submit `_suggestions[_selectedIndex]`

**UI:** replace current `ListView.builder` with `SuggestionPopup`. Reset `_selectedIndex = -1` whenever `_suggestions` changes.

### 3. `terminal_view.dart` (modified)

Convert `_TerminalWidget` from `StatelessWidget` to `StatefulWidget`.

**New state:**
```dart
String _inputBuffer = '';
int _selectedIdx = 0;
List<String> _suggestions = [];
```

**Keystroke tracking via `Focus.onKeyEvent` wrapping `TerminalView`:**

| Event | Action |
|---|---|
| Printable char (length == 1, no Ctrl/Meta modifier) | `_inputBuffer += char`; refresh suggestions |
| `Backspace` | remove last char from `_inputBuffer`; refresh suggestions |
| `Enter` / `Ctrl+C` / `Ctrl+U` | `_inputBuffer = ''`; hide popup |
| `Tab` (suggestions non-empty) | call `_completeTo(_suggestions[_selectedIdx])`; return `handled` |
| `Tab` (suggestions empty) | return `ignored` (shell native Tab fallback) |
| `↑` (popup visible) | `_selectedIdx--`; clamp; return `handled` |
| `↓` (popup visible) | `_selectedIdx++`; clamp; return `handled` |
| All other keys | return `ignored` (xterm handles normally) |

**`_completeTo(String suggestion)`:**
```dart
session.terminal.textInput('\b' * _inputBuffer.length);
session.terminal.textInput(suggestion);
setState(() { _inputBuffer = suggestion; _suggestions = []; });
```

**`_refreshSuggestions()`:**
```dart
final provider = context.read<CommandHistoryProvider>();
setState(() {
  _suggestions = provider.suggestions(session.id, _inputBuffer);
  _selectedIdx = 0;
});
```

**UI structure:**
```
Stack(
  children: [
    Focus(onKeyEvent: ..., child: TerminalView(session.terminal, ...)),
    if (_suggestions.isNotEmpty)
      Positioned(
        bottom: 8, right: 8,
        width: 320,
        child: SuggestionPopup(
          suggestions: _suggestions,
          selectedIndex: _selectedIdx,
          onSelect: _completeTo,
        ),
      ),
  ],
)
```

## Data Flow

```
User types in TerminalInputBar
  → _onTextChanged → CommandHistoryProvider.suggestions(sessionId, prefix)
  → setState(_suggestions) → SuggestionPopup renders

User types in raw xterm
  → Focus.onKeyEvent intercepts printable chars / backspace
  → _inputBuffer updated → _refreshSuggestions()
  → SuggestionPopup renders as Stack overlay (bottom-right, fixed)

User presses Tab (either surface)
  → _completeTo(suggestion) → terminal.textInput('\b'*n + completion)
  → buffer reset, popup hidden
```

## Known Limitations

- `_inputBuffer` in raw xterm may drift if user uses `←→`, `Ctrl+A/E`, or `Ctrl+W`. This is acceptable: worst case shows irrelevant suggestions until next Enter/Ctrl+C resets the buffer.
- Suggestion source is history only — no path completion, no binary name awareness.

## Files Changed

| File | Change |
|---|---|
| `app/lib/widgets/suggestion_popup.dart` | New file |
| `app/lib/widgets/terminal_input_bar.dart` | Tab + arrow nav + SuggestionPopup |
| `app/lib/widgets/terminal_view.dart` | StatefulWidget + keystroke tracking + Stack overlay |
