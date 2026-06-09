# K8s Panel Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the Kubernetes panel in the DevOps plugin: context switcher (per-session `--context` flag), in-panel `logs -f` viewer, and 1-click port-forward (kubectl pf + SSH local tunnel to localhost).

**Architecture:** Add `SshService.execStream` for persistent SSH exec channels; extend `ContainerService` with `listContexts`, `streamLogs`, and `startPodPortForward`; extract `KubernetesPanel` widget from `ContainersScreen` with an in-panel split layout (pod list above, log viewer below); port-forward creates a `ServerSocket + client.forwardLocal` local tunnel backed by a background kubectl process, tracked in a `K8sForwardHandle`.

**Tech Stack:** Flutter/Dart, dartssh2 (`SSHClient.execute`, `SSHClient.forwardLocal`, `SSHForwardChannel`), `dart:io` (`ServerSocket`), `dart:async` (`StreamController`, `Completer`).

---

## File map

| File | Action |
|---|---|
| `app/lib/services/ssh_service.dart` | Add `execStream` method (~30 lines, after `exec`) |
| `app/lib/services/container_service.dart` | Add `parseContextNames`, `listContexts`, `currentContext`, `streamLogs`, `startPodPortForward`, `_pipeK8s` |
| `app/lib/models/container_entry.dart` | Add `K8sForwardHandle` class |
| `app/lib/widgets/kubernetes_panel.dart` | New — full K8s tab widget |
| `app/lib/widgets/containers_screen.dart` | Replace K8s body with `KubernetesPanel`, remove `_execPod` (K8s logic moved to panel) |
| `packages/yourssh_devops/lib/src/devops_plugin_config.dart` | Add optional `onOpenBrowser` field |
| `app/lib/plugins/plugin_registry.dart` | Pass `onOpenBrowser` callback to `ContainersScreen` |
| `app/test/services/container_service_test.dart` | Add `parseContextNames` tests |

---

## Task 1: `SshService.execStream`

**Files:**
- Modify: `app/lib/services/ssh_service.dart` (insert after `exec` method, ~line 1014)

- [ ] **Step 1: Add `execStream` after `exec`**

  Find the comment `// ── SFTP ───` (currently line ~1015) and insert above it:

  ```dart
  /// Opens a persistent SSH exec channel and yields stdout lines.
  /// Cancelling the returned stream's subscription closes the channel —
  /// the remote process receives SIGHUP.
  Stream<String> execStream(
    Host host,
    String command, {
    String? auditSource,
  }) {
    final controller = StreamController<String>();
    _ensureClient(host).then((client) async {
      final SSHSession session;
      try {
        session = await client.execute(command);
      } catch (e) {
        controller.addError(e);
        unawaited(controller.close());
        return;
      }
      if (auditSource != null) {
        audit?.record(AuditEvent.now(
          type: AuditEventType.exec,
          host: host,
          command: command,
          meta: {'source': auditSource},
        ));
      }
      final sub = session.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              session.close();
              if (!controller.isClosed) unawaited(controller.close());
            },
            cancelOnError: false,
          );
      controller.onCancel = () async {
        await sub.cancel();
        session.close();
      };
    }).catchError(controller.addError);
    return controller.stream;
  }
  ```

- [ ] **Step 2: Run analyzer**

  ```bash
  cd app && flutter analyze lib/services/ssh_service.dart
  ```
  Expected: no new errors.

- [ ] **Step 3: Commit**

  ```bash
  git add app/lib/services/ssh_service.dart
  git commit -m "feat(ssh): add execStream for persistent exec channels"
  ```

---

## Task 2: ContainerService — context list methods + tests

**Files:**
- Modify: `app/lib/services/container_service.dart`
- Modify: `app/test/services/container_service_test.dart`

- [ ] **Step 1: Write failing tests first**

  Add to `app/test/services/container_service_test.dart`:

  ```dart
  group('parseContextNames', () {
    test('parses newline-separated context names', () {
      const out = 'minikube\nprod-cluster\ndev-cluster\n';
      expect(ContainerService.parseContextNames(out),
          ['minikube', 'prod-cluster', 'dev-cluster']);
    });

    test('ignores blank lines and whitespace', () {
      const out = '  minikube  \n\n  prod  \n';
      expect(ContainerService.parseContextNames(out), ['minikube', 'prod']);
    });

    test('empty output returns empty list', () {
      expect(ContainerService.parseContextNames(''), isEmpty);
      expect(ContainerService.parseContextNames('  \n  \n'), isEmpty);
    });
  });
  ```

- [ ] **Step 2: Run tests to confirm they fail**

  ```bash
  cd app && flutter test test/services/container_service_test.dart --name "parseContextNames"
  ```
  Expected: FAIL — `parseContextNames` not defined.

- [ ] **Step 3: Add `parseContextNames`, `listContexts`, `currentContext` to ContainerService**

  Add after `podContainers` (around line 43 in container_service.dart):

  ```dart
  // ── Contexts ──────────────────────────────────────────

  Future<List<String>> listContexts(Host host) async {
    final r = await ssh.exec(host, 'kubectl config get-contexts -o name',
        auditSource: 'devops');
    if (r.exitCode != 0) return const [];
    return parseContextNames(r.stdout);
  }

  Future<String?> currentContext(Host host) async {
    final r = await ssh.exec(host, 'kubectl config current-context',
        auditSource: 'devops');
    if (r.exitCode != 0) return null;
    final name = r.stdout.trim();
    return name.isEmpty ? null : name;
  }

  static List<String> parseContextNames(String stdout) {
    return stdout
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
  ```

- [ ] **Step 4: Run tests**

  ```bash
  cd app && flutter test test/services/container_service_test.dart --name "parseContextNames"
  ```
  Expected: all 3 tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add app/lib/services/container_service.dart \
          app/test/services/container_service_test.dart
  git commit -m "feat(k8s): add listContexts / parseContextNames to ContainerService"
  ```

---

## Task 3: `K8sForwardHandle` model

**Files:**
- Modify: `app/lib/models/container_entry.dart`

- [ ] **Step 1: Add imports and `K8sForwardHandle` at the bottom of `container_entry.dart`**

  Add to the top of the file (after existing imports):
  ```dart
  import 'dart:async';
  import 'dart:io';
  import 'package:dartssh2/dartssh2.dart';
  ```

  Add at the bottom of the file:
  ```dart
  /// Tracks a running `kubectl port-forward` process and the matching local
  /// TCP server. Call [stop] to tear both down.
  class K8sForwardHandle {
    K8sForwardHandle({
      required this.pod,
      required this.namespace,
      required this.podPort,
      required this.localPort,
      required StreamSubscription<String> kubectlSub,
      required ServerSocket server,
      required StreamSubscription<Socket> serverSub,
      required List<void Function()> closers,
    })  : _kubectlSub = kubectlSub,
          _server = server,
          _serverSub = serverSub,
          _closers = closers;

    final String pod;
    final String namespace;
    final int podPort;
    final int localPort;

    final StreamSubscription<String> _kubectlSub;
    final ServerSocket _server;
    final StreamSubscription<Socket> _serverSub;
    final List<void Function()> _closers;

    Future<void> stop() async {
      await _serverSub.cancel();
      await _server.close();
      for (final c in List.of(_closers)) {
        c();
      }
      await _kubectlSub.cancel();
    }
  }
  ```

- [ ] **Step 2: Analyze**

  ```bash
  cd app && flutter analyze lib/models/container_entry.dart
  ```
  Expected: no errors.

- [ ] **Step 3: Commit**

  ```bash
  git add app/lib/models/container_entry.dart
  git commit -m "feat(k8s): add K8sForwardHandle model"
  ```

---

## Task 4: ContainerService — `streamLogs` + `startPodPortForward`

**Files:**
- Modify: `app/lib/services/container_service.dart`

- [ ] **Step 1: Add required imports to `container_service.dart`**

  Replace the existing imports at the top:
  ```dart
  import 'dart:async';
  import 'dart:io';
  import 'dart:math';

  import 'package:dartssh2/dartssh2.dart';

  import '../models/container_entry.dart';
  import '../models/host.dart';
  import 'ssh_service.dart';
  ```

- [ ] **Step 2: Add `streamLogs` after `currentContext`**

  ```dart
  // ── Log streaming ─────────────────────────────────────

  /// Streams stdout lines from `kubectl logs -f`.
  /// Cancel the subscription to stop the stream and close the SSH channel.
  Stream<String> streamLogs(
    Host host,
    String pod,
    String namespace,
    String? context, {
    String? container,
    int tail = 100,
  }) {
    final ctxFlag = context != null ? ' --context=$context' : '';
    final cFlag = container != null ? ' -c $container' : '';
    final cmd =
        'kubectl logs -f $pod -n $namespace --tail=$tail$ctxFlag$cFlag';
    return ssh.execStream(host, cmd, auditSource: 'devops');
  }
  ```

- [ ] **Step 3: Add `startPodPortForward` and `_pipeK8s` before the install hint section**

  Add after `streamLogs`:

  ```dart
  // ── Port forwarding ───────────────────────────────────

  /// Starts `kubectl port-forward` on [host] and creates a local [ServerSocket]
  /// on [localPort] that tunnels connections to the pod via SSH.
  ///
  /// Throws [TimeoutException] if kubectl does not print "Forwarding from"
  /// within 10 seconds, or any [Exception] on kubectl error.
  Future<K8sForwardHandle> startPodPortForward(
    Host host,
    String pod,
    String namespace,
    String? context,
    int podPort,
    int localPort,
  ) async {
    final remotePfPort = 40000 + Random().nextInt(9999);
    final ctxFlag = context != null ? ' --context=$context' : '';
    final cmd = 'kubectl port-forward --address 0.0.0.0 pod/$pod '
        '$remotePfPort:$podPort -n $namespace$ctxFlag';

    final ready = Completer<void>();
    final lines = <String>[];
    final logStream = ssh.execStream(host, cmd, auditSource: 'devops');

    late StreamSubscription<String> kubectlSub;
    kubectlSub = logStream.listen(
      (line) {
        lines.add(line);
        if (line.contains('Forwarding from') && !ready.isCompleted) {
          ready.complete();
        }
      },
      onError: (e) {
        if (!ready.isCompleted) ready.completeError(e);
      },
      onDone: () {
        if (!ready.isCompleted) {
          ready.completeError(
            Exception('kubectl exited: ${lines.join(' | ')}'),
          );
        }
      },
    );

    try {
      await ready.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      await kubectlSub.cancel();
      rethrow;
    }

    final client = await ssh.ensureClient(host);
    final server =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, localPort);
    final closers = <void Function()>[];

    final serverSub = server.listen((socket) async {
      try {
        final channel = await client.forwardLocal('localhost', remotePfPort);
        _pipeK8s(socket, channel, closers);
      } catch (_) {
        socket.destroy();
      }
    });

    return K8sForwardHandle(
      pod: pod,
      namespace: namespace,
      podPort: podPort,
      localPort: localPort,
      kubectlSub: kubectlSub,
      server: server,
      serverSub: serverSub,
      closers: closers,
    );
  }

  static void _pipeK8s(
      Socket local, SSHSocket remote, List<void Function()> closers) {
    var done = false;
    late final void Function() finish;
    finish = () {
      if (done) return;
      done = true;
      local.destroy();
      remote.destroy();
      closers.remove(finish);
    };
    closers.add(finish);
    unawaited(remote.stream
        .cast<List<int>>()
        .pipe(local)
        .catchError((_) {})
        .whenComplete(finish));
    unawaited(local
        .cast<List<int>>()
        .pipe(remote.sink)
        .catchError((_) {})
        .whenComplete(finish));
  }
  ```

- [ ] **Step 4: Analyze**

  ```bash
  cd app && flutter analyze lib/services/container_service.dart
  ```
  Expected: no errors.

- [ ] **Step 5: Run existing container tests to confirm nothing broke**

  ```bash
  cd app && flutter test test/services/container_service_test.dart
  ```
  Expected: all pass.

- [ ] **Step 6: Commit**

  ```bash
  git add app/lib/services/container_service.dart
  git commit -m "feat(k8s): add streamLogs and startPodPortForward to ContainerService"
  ```

---

## Task 5: Create `KubernetesPanel` — skeleton + context switcher + pod list

**Files:**
- Create: `app/lib/widgets/kubernetes_panel.dart`

- [ ] **Step 1: Create the file**

  ```dart
  import 'dart:async';

  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';

  import '../models/container_entry.dart';
  import '../models/host.dart';
  import '../providers/session_provider.dart';
  import '../services/container_service.dart';
  import '../services/ssh_service.dart';
  import '../theme/app_theme.dart';

  class KubernetesPanel extends StatefulWidget {
    const KubernetesPanel({
      super.key,
      required this.host,
      this.onOpenBrowser,
    });

    final Host host;
    /// If non-null, "Open in Browser" buttons are shown for active port-forwards.
    final void Function(String url)? onOpenBrowser;

    @override
    State<KubernetesPanel> createState() => _KubernetesPanelState();
  }

  class _KubernetesPanelState extends State<KubernetesPanel> {
    ContainerService? _svc;

    // ── Namespace / context ────────────────────────────
    String _namespace = 'default';
    bool _allNamespaces = false;
    late TextEditingController _nsCtrl;

    String? _context; // null = omit --context flag
    List<String> _contexts = [];

    // ── Pod list ───────────────────────────────────────
    List<PodEntry> _pods = [];
    bool _loading = false;
    String? _error;

    // ── Log panel ─────────────────────────────────────
    PodEntry? _logPod;
    String? _logContainer;
    StreamSubscription<String>? _logSub;
    final List<String> _logLines = [];
    final ScrollController _logScroll = ScrollController();

    // ── Port forwards ──────────────────────────────────
    final List<K8sForwardHandle> _forwards = [];

    @override
    void initState() {
      super.initState();
      _nsCtrl = TextEditingController(text: _namespace);
      _loadContexts();
    }

    @override
    void didUpdateWidget(KubernetesPanel old) {
      super.didUpdateWidget(old);
      if (old.host.id != widget.host.id) {
        _context = null;
        _contexts = [];
        _pods = [];
        _error = null;
        _closeLogPanel();
        _loadContexts();
      }
    }

    @override
    void dispose() {
      _nsCtrl.dispose();
      _logSub?.cancel();
      _logScroll.dispose();
      for (final f in _forwards) {
        f.stop();
      }
      super.dispose();
    }

    ContainerService _service() =>
        _svc ??= ContainerService(context.read<SshService>());

    Future<void> _loadContexts() async {
      final ctxs = await _service().listContexts(widget.host);
      if (mounted) setState(() => _contexts = ctxs);
    }

    Future<void> _refresh() async {
      _namespace =
          _nsCtrl.text.trim().isEmpty ? 'default' : _nsCtrl.text.trim();
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        _pods = await _service().listPods(
          widget.host,
          namespace: _namespace,
          allNamespaces: _allNamespaces,
          context: _context,
        );
      } catch (e) {
        _error = e.toString();
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(),
          if (_forwards.isNotEmpty) _activeForwardsBar(),
          Expanded(child: _body()),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _logPod != null ? _logPanel() : const SizedBox.shrink(),
          ),
        ],
      );
    }

    // ── Header ─────────────────────────────────────────

    Widget _headerRow() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_contexts.isNotEmpty) _contextDropdown(),
            SizedBox(
              width: 180,
              child: TextField(
                enabled: !_allNamespaces,
                decoration: const InputDecoration(
                    labelText: 'Namespace', isDense: true),
                controller: _nsCtrl,
                onSubmitted: (_) => _refresh(),
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(
                value: _allNamespaces,
                onChanged: (v) => setState(() {
                  _allNamespaces = v ?? false;
                  _refresh();
                }),
              ),
              const Text('All namespaces'),
            ]),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _refresh,
            ),
          ],
        ),
      );
    }

    Widget _contextDropdown() {
      return DropdownButton<String?>(
        value: _context,
        hint: const Text('Context'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('(default context)'),
          ),
          for (final c in _contexts)
            DropdownMenuItem<String?>(value: c, child: Text(c)),
        ],
        onChanged: (v) => setState(() {
          _context = v;
          _refresh();
        }),
      );
    }

    // ── Body ───────────────────────────────────────────

    Widget _body() {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        );
      }
      if (_pods.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox, size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              const Text('No pods. Tap refresh to scan.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: const Text('Scan')),
            ],
          ),
        );
      }
      return _podList();
    }

    Widget _podList() {
      return ListView.separated(
        itemCount: _pods.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = _pods[i];
          return ListTile(
            title: Text(p.name),
            subtitle: Text(
                '${p.namespace}  •  ${p.ready}  •  ${p.status}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.terminal, size: 18),
                  tooltip: 'Exec',
                  onPressed: () => _execPod(p),
                ),
                IconButton(
                  icon: const Icon(Icons.article_outlined, size: 18),
                  tooltip: 'Logs',
                  onPressed: () => _openLogs(p),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  tooltip: 'Forward port',
                  onPressed: () => _showForwardDialog(p),
                ),
              ],
            ),
          );
        },
      );
    }

    // ── Exec ───────────────────────────────────────────

    Future<void> _execPod(PodEntry p) async {
      String? container;
      final names =
          await _service().podContainers(widget.host, p.name, p.namespace);
      if (names.length > 1 && mounted) {
        container = await showDialog<String>(
          context: context,
          builder: (_) => SimpleDialog(
            title: const Text('Select container'),
            children: [
              for (final n in names)
                SimpleDialogOption(
                  child: Text(n),
                  onPressed: () => Navigator.pop(context, n),
                ),
            ],
          ),
        );
        if (container == null) return;
      } else if (names.length == 1) {
        container = names.first;
      }
      if (!mounted) return;
      await context.read<SessionProvider>().connect(
        widget.host,
        initialCommand: ContainerService.kubectlExecCommand(
            p.name, p.namespace, container),
      );
    }

    // ── Log panel ──────────────────────────────────────

    Future<void> _openLogs(PodEntry p) async {
      String? container;
      final names =
          await _service().podContainers(widget.host, p.name, p.namespace);
      if (names.length > 1 && mounted) {
        container = await showDialog<String>(
          context: context,
          builder: (_) => SimpleDialog(
            title: const Text('Select container'),
            children: [
              for (final n in names)
                SimpleDialogOption(
                  child: Text(n),
                  onPressed: () => Navigator.pop(context, n),
                ),
            ],
          ),
        );
        if (container == null) return;
      } else if (names.length == 1) {
        container = names.first;
      }
      if (!mounted) return;
      _closeLogPanel();
      setState(() {
        _logPod = p;
        _logContainer = container;
        _logLines.clear();
      });
      _logSub = _service()
          .streamLogs(widget.host, p.name, p.namespace, _context,
              container: container)
          .listen(
        (line) {
          if (!mounted) return;
          setState(() {
            _logLines.add(line);
            if (_logLines.length > 500) _logLines.removeAt(0);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_logScroll.hasClients) {
              _logScroll
                  .jumpTo(_logScroll.position.maxScrollExtent);
            }
          });
        },
        onError: (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Log stream ended')),
            );
            _closeLogPanel();
          }
        },
        onDone: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Log stream ended')),
            );
            setState(() => _logPod = null);
          }
        },
      );
    }

    void _closeLogPanel() {
      _logSub?.cancel();
      _logSub = null;
      if (mounted) setState(() => _logPod = null);
    }

    Widget _logPanel() {
      final pod = _logPod!;
      return Container(
        height: 240,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.article_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'pod/${pod.name}'
                      '${_logContainer != null ? '  •  $_logContainer' : ''}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Close logs',
                    onPressed: _closeLogPanel,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Log lines
            Expanded(
              child: _logLines.isEmpty
                  ? const Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : ListView.builder(
                      controller: _logScroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: _logLines.length,
                      itemBuilder: (_, i) => Text(
                        _logLines[i],
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    // ── Port-forward dialog ────────────────────────────

    Future<void> _showForwardDialog(PodEntry p) async {
      await showDialog<void>(
        context: context,
        builder: (_) => _PortForwardDialog(
          pod: p,
          onConfirm: (podPort, localPort) =>
              _startForward(p, podPort, localPort),
        ),
      );
    }

    Future<void> _startForward(PodEntry p, int podPort, int localPort) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final handle = await _service().startPodPortForward(
          widget.host,
          p.name,
          p.namespace,
          _context,
          podPort,
          localPort,
        );
        if (mounted) {
          setState(() => _forwards.add(handle));
          messenger.showSnackBar(SnackBar(
            content: Text(
                'Forwarding localhost:$localPort → pod/${p.name}:$podPort'),
          ));
        } else {
          await handle.stop();
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Port-forward failed: $e')),
        );
      }
    }

    Future<void> _stopForward(K8sForwardHandle h) async {
      await h.stop();
      if (mounted) setState(() => _forwards.remove(h));
    }

    // ── Active forwards bar ────────────────────────────

    Widget _activeForwardsBar() {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACTIVE FORWARDS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            for (final f in _forwards)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'pod/${f.pod}  :${f.podPort} → localhost:${f.localPort}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onOpenBrowser != null)
                      TextButton(
                        onPressed: () => widget.onOpenBrowser!(
                            'http://localhost:${f.localPort}'),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap),
                        child: const Text('Open ↗',
                            style: TextStyle(fontSize: 12)),
                      ),
                    TextButton(
                      onPressed: () => _stopForward(f),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap),
                      child: const Text('■ Stop',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
  }

  // ── Port-forward dialog ──────────────────────────────────

  class _PortForwardDialog extends StatefulWidget {
    const _PortForwardDialog({required this.pod, required this.onConfirm});
    final PodEntry pod;
    final void Function(int podPort, int localPort) onConfirm;

    @override
    State<_PortForwardDialog> createState() => _PortForwardDialogState();
  }

  class _PortForwardDialogState extends State<_PortForwardDialog> {
    final _formKey = GlobalKey<FormState>();
    final _podPortCtrl = TextEditingController();
    final _localPortCtrl = TextEditingController();

    @override
    void dispose() {
      _podPortCtrl.dispose();
      _localPortCtrl.dispose();
      super.dispose();
    }

    String? _validatePort(String? v) {
      final n = int.tryParse(v ?? '');
      if (n == null || n < 1 || n > 65535) return '1–65535';
      return null;
    }

    @override
    Widget build(BuildContext context) {
      return AlertDialog(
        title: const Text('Forward port'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('pod/${widget.pod.name}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _podPortCtrl,
                decoration: const InputDecoration(
                    labelText: 'Pod port', isDense: true),
                keyboardType: TextInputType.number,
                autofocus: true,
                validator: _validatePort,
                onChanged: (v) {
                  if (_localPortCtrl.text.isEmpty) {
                    _localPortCtrl.text = v;
                  }
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _localPortCtrl,
                decoration: const InputDecoration(
                    labelText: 'Local port', isDense: true),
                keyboardType: TextInputType.number,
                validator: _validatePort,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              final podPort = int.parse(_podPortCtrl.text);
              final localPort = int.parse(_localPortCtrl.text);
              Navigator.pop(context);
              widget.onConfirm(podPort, localPort);
            },
            child: const Text('Start Forward'),
          ),
        ],
      );
    }
  }
  ```

  > Note: `listPods` in ContainerService needs a `context` parameter (currently it doesn't have one). Add `{String? context}` as optional named param. Update the command to append `${context != null ? ' --context=$context' : ''}` before running. See Step 2.

- [ ] **Step 2: Add `context` parameter to `ContainerService.listPods`**

  In `container_service.dart`, update `listPods`:
  ```dart
  Future<List<PodEntry>> listPods(
    Host host, {
    String namespace = 'default',
    bool allNamespaces = false,
    String? context,
  }) async {
    final scope = allNamespaces ? '-A' : '-n $namespace';
    final ctxFlag = context != null ? ' --context=$context' : '';
    final r = await ssh.exec(host, 'kubectl get pods $scope$ctxFlag',
        auditSource: 'devops');
    if (r.exitCode != 0) {
      throw Exception(r.stderr.trim().isEmpty ? 'kubectl failed' : r.stderr.trim());
    }
    return parsePods(r.stdout, namespace: namespace, allNamespaces: allNamespaces);
  }
  ```

- [ ] **Step 3: Analyze**

  ```bash
  cd app && flutter analyze lib/widgets/kubernetes_panel.dart \
                            lib/services/container_service.dart
  ```
  Expected: no errors.

- [ ] **Step 4: Commit**

  ```bash
  git add app/lib/widgets/kubernetes_panel.dart \
          app/lib/services/container_service.dart
  git commit -m "feat(k8s): add KubernetesPanel widget with context switcher, logs, port-forward"
  ```

---

## Task 6: Wire `KubernetesPanel` into `ContainersScreen`

**Files:**
- Modify: `app/lib/widgets/containers_screen.dart`

- [ ] **Step 1: Add import and `onOpenBrowser` param to `ContainersScreen`**

  At the top of `containers_screen.dart`, add:
  ```dart
  import 'kubernetes_panel.dart';
  ```

  Change the class definition:
  ```dart
  class ContainersScreen extends StatefulWidget {
    const ContainersScreen({super.key, this.onOpenBrowser});
    final void Function(String url)? onOpenBrowser;

    @override
    State<ContainersScreen> createState() => _ContainersScreenState();
  }
  ```

- [ ] **Step 2: Replace K8s body with `KubernetesPanel`**

  In `_body()`, replace the line:
  ```dart
  return _tab == _Tab.docker ? _dockerList() : _podList();
  ```
  with:
  ```dart
  if (_tab == _Tab.docker) return _dockerList();
  final host = _hostForSelected();
  if (host == null) return const _CenterHint(icon: Icons.link_off, message: 'Session not found.');
  return KubernetesPanel(host: host, onOpenBrowser: widget.onOpenBrowser);
  ```

- [ ] **Step 3: Remove now-dead K8s-specific state and methods**

  In `_ContainersScreenState`, remove:
  - `List<PodEntry> _pods = [];` field
  - `String _namespace = 'default';` field
  - `bool _allNamespaces = false;` field
  - `late final TextEditingController _nsController;` field
  - `_nsController` init/dispose in `initState`/`dispose`
  - `_namespaceControls()` widget method
  - `_podList()` widget method
  - `_execPod(PodEntry p)` method (moved to KubernetesPanel)
  - The `if (_tab == _Tab.kubernetes) _namespaceControls()` row in `build`
  - K8s branch in `_refresh()` (`_pods = await svc.listPods(...)`)

  Also remove the unused import `import '../models/host.dart';` if it's only used by the removed code (check first — it may still be used by `_hostForSelected`).

  > `_refresh()` now only runs for Docker. Keep it for Docker tab only. You may also choose to remove it entirely from `_ContainersScreenState` if you want, since each tab manages its own refresh — but keeping Docker refresh in ContainersScreen is fine.

- [ ] **Step 4: Remove unused import of `container_entry.dart` PodEntry if applicable**

  Check if `PodEntry` is still referenced in containers_screen.dart after the removal. If not, update the import to only import what's needed.

- [ ] **Step 5: Analyze**

  ```bash
  cd app && flutter analyze lib/widgets/containers_screen.dart
  ```
  Expected: no errors.

- [ ] **Step 6: Run all tests**

  ```bash
  cd app && flutter test
  ```
  Expected: all pass.

- [ ] **Step 7: Commit**

  ```bash
  git add app/lib/widgets/containers_screen.dart
  git commit -m "refactor(containers): delegate K8s tab to KubernetesPanel"
  ```

---

## Task 7: Wire `onOpenBrowser` through DevOpsPluginConfig

**Files:**
- Modify: `packages/yourssh_devops/lib/src/devops_plugin_config.dart`
- Modify: `app/lib/plugins/plugin_registry.dart`

- [ ] **Step 1: Add `onOpenBrowser` to `DevOpsPluginConfig`**

  In `devops_plugin_config.dart`, add the field:
  ```dart
  class DevOpsPluginConfig {
    const DevOpsPluginConfig({
      required this.containersScreen,
      required this.networkToolsScreen,
      required this.cloudflareScreen,
      required this.mailCatcherScreen,
      required this.mcpServerScreen,
      this.onOpenBrowser,   // ← new
    });

    // ... existing fields ...
    final void Function(String url)? onOpenBrowser;
  }
  ```

- [ ] **Step 2: Check how `containersScreen` is rendered in `devops_hub_screen.dart`**

  Open `packages/yourssh_devops/lib/src/screens/devops_hub_screen.dart` and find where `config.containersScreen` is rendered. Confirm it's just rendered as-is (a Widget). No changes needed — the `onOpenBrowser` callback is passed at construction in plugin_registry.

- [ ] **Step 3: Update `plugin_registry.dart`**

  Find the `ContainersScreen()` instantiation and update it. The callback can be null for now — `onOpenBrowser` is an optional parameter. Update to:
  ```dart
  containersScreen: const ContainersScreen(),
  ```
  This stays `const` because `onOpenBrowser` defaults to null. If you want to wire up WebTools, pass a callback — but `null` is sufficient for this feature (the "Open" button is simply hidden).

  > Note: If you want to wire WebTools later, change to:
  > ```dart
  > containersScreen: ContainersScreen(
  >   onOpenBrowser: (url) { /* launch url via platform */ },
  > ),
  > ```
  > This is a follow-up and not required for P0.

- [ ] **Step 4: Analyze everything**

  ```bash
  cd app && flutter analyze
  ```
  Expected: no errors.

- [ ] **Step 5: Run all tests**

  ```bash
  cd app && flutter test
  ```
  Expected: all pass.

- [ ] **Step 6: Commit**

  ```bash
  git add packages/yourssh_devops/lib/src/devops_plugin_config.dart \
          app/lib/plugins/plugin_registry.dart
  git commit -m "feat(devops): add onOpenBrowser to DevOpsPluginConfig"
  ```

---

## Task 8: Manual smoke test + final commit

- [ ] **Step 1: Run the app**

  ```bash
  cd app && flutter run -d macos
  ```

- [ ] **Step 2: Smoke test context switcher**
  - Open DevOps → Containers → Kubernetes tab
  - If server has multiple kubectl contexts: confirm dropdown appears and switching context triggers a pod re-list
  - If server has one context: confirm dropdown is hidden

- [ ] **Step 3: Smoke test log streaming**
  - Tap the log icon (article) on any running pod
  - Confirm log panel slides up at bottom of screen
  - Confirm lines stream in real-time
  - Tap ✕ to close — confirm panel hides and stream stops

- [ ] **Step 4: Smoke test port-forward**
  - Tap the swap icon on a pod with a known HTTP port (e.g., 8080)
  - Enter pod port and local port in dialog, tap Start Forward
  - Confirm snackbar appears: "Forwarding localhost:XXXX → pod/name:XXXX"
  - Confirm entry appears in active forwards bar
  - In a terminal: `curl http://localhost:XXXX` — confirm connection reaches the pod
  - Tap ■ Stop — confirm entry disappears

- [ ] **Step 5: Final commit if needed**

  ```bash
  cd app && git add -p && git commit -m "chore(k8s): post-smoke-test fixups"
  ```

---

## Summary

After all tasks:
- `SshService.execStream` — persistent SSH exec channel as a cancellable `Stream<String>`
- `ContainerService` — `listContexts`, `currentContext`, `streamLogs`, `startPodPortForward`
- `K8sForwardHandle` — tracks kubectl background process + local ServerSocket tunnel
- `KubernetesPanel` — full K8s tab: context switcher, pod list (Exec/Logs/Forward), in-panel 240px log viewer, active forwards bar
- `ContainersScreen` — delegates K8s tab to KubernetesPanel, receives optional `onOpenBrowser`
- All existing tests pass; new `parseContextNames` unit tests added
