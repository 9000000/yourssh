# K8s Panel Completion Design

**Date:** 2026-06-09
**Feature:** Kubernetes panel — context switcher, log streaming, 1-click port-forward
**Priority:** P0

---

## Goal

Complete the Kubernetes story in the DevOps plugin. The container browser and exec shipped in
0.1.12. This spec adds the three remaining features:

1. **Context switcher** — select a kubectl context per-session without mutating `~/.kube/config`
2. **Log streaming** — `kubectl logs -f` rendered in an in-panel log viewer
3. **1-click port-forward** — kubectl pf + SSH local tunnel so the port lands on `localhost` of the user's machine

---

## Architecture

### ContainersScreen refactor (minimal)

`ContainersScreen` currently owns both Docker and K8s tab bodies. The K8s tab body
(`_podList` + namespace controls) is extracted into a new `KubernetesPanel` widget
(`app/lib/widgets/kubernetes_panel.dart`). `ContainersScreen` keeps the session
selector, tab buttons, Docker list, and namespace controls are moved into
`KubernetesPanel`.

`ContainersScreen` change: replace `_podList()` call with:
```dart
KubernetesPanel(
  host: host,
  onExecPod: _execPod,
  onOpenBrowser: widget.onOpenBrowser, // nullable, injected from DevOpsPluginConfig
)
```

### SshService — `execStream`

New method on `SshService`:

```dart
Stream<String> execStream(Host host, String command, {String? auditSource});
```

Opens an SSH exec channel and yields stdout line by line. Cancelling the
`StreamSubscription` closes the channel — the remote process receives SIGHUP and exits.
The stream closes naturally when the remote process exits. Stderr lines are swallowed
(callers that need them can use the existing `exec` method).

Implementation: `SSHClient.execute(command)` returns an `SSHSession`; `session.stdout`
is a `Stream<Uint8List>`. Transform via `utf8.decoder` → `LineSplitter`.

### ContainerService additions

```dart
// Returns context names from `kubectl config get-contexts -o name`.
// Returns [] on error (single-context servers).
Future<List<String>> listContexts(Host host) async { ... }
static List<String> parseContextNames(String stdout) { ... }

// Returns the current context name, or null on error.
Future<String?> currentContext(Host host) async { ... }

// Streams lines from `kubectl logs -f <pod>`.
// context is passed as --context=<name> if non-null.
Stream<String> streamLogs(
  Host host,
  String pod,
  String namespace,
  String? context, {
  String? container,
  int tail = 100,
}) { ... }

// Starts a port-forward. Throws on timeout (10s) or kubectl error.
Future<K8sForwardHandle> startPodPortForward(
  Host host,
  String pod,
  String namespace,
  String? context,
  int podPort,
  int localPort,
) async { ... }
```

**`startPodPortForward` implementation:**

1. Pick `remotePfPort` — random int in 40000–49999.
2. Open `execStream` for:
   ```
   kubectl port-forward --address 0.0.0.0 pod/<pod> <remotePfPort>:<podPort>
     -n <ns> [--context=<ctx>]
   ```
3. Collect lines until `"Forwarding from"` appears or 10 s elapses. On timeout:
   cancel stream, throw `TimeoutException`.
4. Call `SshService.forwardLocal(host, localPort, 'localhost', remotePfPort)` →
   returns an `SSHForwardChannel` (or equivalent handle from dartssh2).
5. Return `K8sForwardHandle`.

### Model: `K8sForwardHandle`

```dart
class K8sForwardHandle {
  final String pod;
  final String namespace;
  final int podPort;
  final int localPort;

  // internal
  final StreamSubscription<String> _kubectlSub;
  final dynamic _tunnel; // SSHForwardChannel / whatever dartssh2 exposes

  Future<void> stop() async {
    await _kubectlSub.cancel();
    _tunnel.close();
  }
}
```

Lives in `app/lib/models/container_entry.dart` (alongside `ContainerEntry`, `PodEntry`).

---

## KubernetesPanel widget

**File:** `app/lib/widgets/kubernetes_panel.dart`

### State

```dart
String? _context;           // null = omit --context flag
List<String> _contexts;     // loaded once on mount
String _namespace;
bool _allNamespaces;

List<PodEntry> _pods;
bool _loading;
String? _error;

PodEntry? _logPod;          // currently viewed pod
String? _logContainer;      // selected container (multi-container pods)
StreamSubscription<String>? _logSub;
List<String> _logLines;     // ring buffer, max 500 lines
ScrollController _logScroll;

List<K8sForwardHandle> _forwards;
```

### Layout

```
Column
├── Row: [Context ▼] [Namespace field] [All ns checkbox] [Refresh]
├── if _forwards.isNotEmpty → _ActiveForwardsBar
├── Expanded → pod ListView  (or loading / error / empty states)
└── AnimatedSize → _LogPanel  (height 240, visible when _logPod != null)
```

### Context switcher

`DropdownButton<String?>` with items `[null (Any / default), ...contexts]`.
Null item label: `"(default context)"`.
`listContexts()` is called once in `initState` — result stored in `_contexts`.
If `_contexts.isEmpty` the dropdown is hidden.
Changing context sets `_context` and calls `_refresh()`.

All kubectl calls in this widget pass `_context` to `ContainerService` methods.

### Pod list row

```dart
ListTile(
  title: Text(p.name),
  subtitle: Text('${p.namespace}  •  ${p.ready}  •  ${p.status}'),
  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(icon: Icon(Icons.terminal),       tooltip: 'Exec',    onPressed: () => widget.onExecPod(p)),
    IconButton(icon: Icon(Icons.article_outlined), tooltip: 'Logs',  onPressed: () => _openLogs(p)),
    IconButton(icon: Icon(Icons.swap_horiz),     tooltip: 'Forward', onPressed: () => _showForwardDialog(p)),
  ]),
)
```

### Log panel

`_openLogs(PodEntry p)`:
1. If multi-container: show `SimpleDialog` to pick container (same as exec dialog).
2. Cancel existing `_logSub` if any.
3. Clear `_logLines`, set `_logPod = p`, `_logContainer = container`.
4. Subscribe to `ContainerService.streamLogs(...)`.
5. On each line: append to `_logLines` (cap at 500), `setState`, scroll to bottom.

Log panel widget:
```
Container(height: 240)
  Column
  ├── Row: [pod/container label] [container ▼ if multi] [✕ close]
  └── Expanded → ListView(controller: _logScroll)
        items: _logLines mapped to Text(monospace, size 11)
```

Auto-scroll: after each `setState`, schedule
`WidgetsBinding.instance.addPostFrameCallback` →
`_logScroll.jumpTo(_logScroll.position.maxScrollExtent)`.

Close button: cancel `_logSub`, set `_logPod = null`.

### Port-forward dialog

`_showForwardDialog(PodEntry p)` → `showDialog` with `_PortForwardDialog`:

```
AlertDialog
  title: "Forward port"
  content:
    Column
    ├── Text("pod/${p.name}")
    ├── TextFormField(label: "Pod port", initialValue: "")
    └── TextFormField(label: "Local port", initialValue: same as pod port)
  actions: [Cancel, Start Forward]
```

On "Start Forward":
1. Validate both ports (int, 1–65535).
2. Pop dialog, call `ContainerService.startPodPortForward(...)`.
3. On success: add handle to `_forwards`, show snackbar `"Forwarding localhost:<localPort> → pod/<name>:<podPort>"`.
4. On error: show snackbar with error message.

### Active forwards bar

`_ActiveForwardsBar` — thin horizontal strip above the pod list:

```
ACTIVE FORWARDS
  [pod/my-app  :8080 → :8080]  [Open ↗]  [■ Stop]
  [pod/redis   :6379 → :6379]            [■ Stop]
```

"Open in Browser" button calls `widget.onOpenBrowser?.call('http://localhost:$localPort')`.
`widget.onOpenBrowser` is `void Function(String url)?` — injected from `ContainersScreen`,
which receives it from `DevOpsPluginConfig` (new optional field, null = button hidden).

### Dispose

```dart
@override
void dispose() {
  _logSub?.cancel();
  for (final f in _forwards) { f.stop(); }
  _logScroll.dispose();
  super.dispose();
}
```

---

## DevOpsPluginConfig change

Add one optional field:

```dart
final void Function(String url)? onOpenBrowser;
```

Wired in `plugin_registry.dart` to `WebToolsService.openUrl` if the WebTools plugin is
active. Null when WebTools is not installed — the "Open" button is simply hidden.

---

## Namespace controls

Moved from `ContainersScreen` into `KubernetesPanel`. No behavior change — same
TextField + "All namespaces" checkbox.

---

## Error handling

| Scenario | Behaviour |
|---|---|
| `listContexts` fails (no kubeconfig) | `_contexts = []`, dropdown hidden |
| `streamLogs` channel dies | Stream closes → `_logSub` done callback sets `_logPod = null`, snackbar "Log stream ended" |
| `startPodPortForward` timeout | Snackbar "Port-forward timed out — is kubectl accessible on this host?" |
| `startPodPortForward` SSH tunnel fails | Handle's `stop()` called automatically, snackbar with error |
| SSH session dropped while forwards active | dartssh2 closes channels → `_kubectlSub` done → handle cleans up; `_forwards` stays in UI until user refreshes or closes panel |

---

## Testing

**Unit tests** (no SSH):
- `ContainerService.parseContextNames` — newline-separated names, empty input
- `ContainerService.parsePods` existing coverage unchanged

**Widget tests** (existing pattern — mock `ContainerService`):
- Context dropdown hidden when `listContexts` returns `[]`
- Context dropdown shows items, selecting one calls `_refresh` with correct context
- Log panel appears after tapping Logs; disappears on close
- Port-forward dialog validates port range; calls `startPodPortForward` with correct args
- Active forwards bar hidden when `_forwards` is empty; shows entry after start

---

## Files changed

| File | Change |
|---|---|
| `app/lib/services/ssh_service.dart` | Add `execStream` method |
| `app/lib/services/container_service.dart` | Add `listContexts`, `currentContext`, `streamLogs`, `startPodPortForward` |
| `app/lib/models/container_entry.dart` | Add `K8sForwardHandle` |
| `app/lib/widgets/containers_screen.dart` | Extract K8s body → delegate to `KubernetesPanel` |
| `app/lib/widgets/kubernetes_panel.dart` | New widget (context switcher + pod list + logs + forwards) |
| `packages/yourssh_devops/lib/src/devops_plugin_config.dart` | Add `onOpenBrowser` field |
| `app/lib/plugins/plugin_registry.dart` | Wire `onOpenBrowser` if WebTools active |
| `app/test/services/container_service_test.dart` | New parse tests |
| `app/test/widgets/kubernetes_panel_test.dart` | New widget tests |
