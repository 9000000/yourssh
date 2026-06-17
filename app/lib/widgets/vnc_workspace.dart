import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vnc_session.dart';
import '../services/hotkey_service.dart';
import '../theme/app_theme.dart';
import '../util/vnc_input_mapping.dart';

/// Full workspace for an active VNC tab: rendered remote framebuffer,
/// input capture, slim toolbar, and status overlays.
///
/// In fullscreen ([isFullscreen]) the toolbar is replaced by an auto-hiding
/// pill revealed by hovering the top screen edge (mirrors RdpWorkspace);
/// the widget reports enter/exit intents via [onFullscreenChanged] — the
/// caller owns the actual window state and collapses the app chrome.
class VncWorkspace extends StatefulWidget {
  const VncWorkspace({
    super.key,
    required this.session,
    this.onReconnect,
    this.isFullscreen = false,
    this.onFullscreenChanged,
  });

  final VncSession session;
  final VoidCallback? onReconnect;
  final bool isFullscreen;
  final ValueChanged<bool>? onFullscreenChanged;

  @override
  State<VncWorkspace> createState() => _VncWorkspaceState();
}

class _VncWorkspaceState extends State<VncWorkspace> {
  VncSession get session => widget.session;
  final FocusNode _focusNode = FocusNode();
  // Last pointer state sent (fb-x, fb-y, button mask). Identical consecutive
  // events are dropped so a fast-moving mouse doesn't flood the session
  // command channel (and starve frame decode behind the biased run-loop).
  (int, int, int)? _lastPointer;
  String? _lastPushedClipboard;
  bool _hoverBarVisible = false;
  Timer? _hoverBarTimer;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
    if (widget.isFullscreen) _flashHoverBar();
  }

  @override
  void didUpdateWidget(VncWorkspace old) {
    super.didUpdateWidget(old);
    if (!identical(old.session, widget.session)) {
      old.session.removeListener(_onSessionChanged);
      session.addListener(_onSessionChanged);
      _lastPointer = null;
    }
    // Entering fullscreen: show the pill briefly so the exit affordance is
    // discoverable, then auto-hide until the user hovers the top edge.
    if (widget.isFullscreen && !old.isFullscreen) _flashHoverBar();
    if (widget.isFullscreen && session.status != VncSessionStatus.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFullscreenChanged?.call(false);
      });
    }
  }

  @override
  void dispose() {
    _hoverBarTimer?.cancel();
    _focusNode.dispose();
    session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _flashHoverBar() {
    setState(() => _hoverBarVisible = true);
    _hoverBarTimer?.cancel();
    _hoverBarTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _hoverBarVisible = false);
    });
  }

  void _showHoverBar() {
    _hoverBarTimer?.cancel();
    if (!_hoverBarVisible) setState(() => _hoverBarVisible = true);
  }

  void _hideHoverBarSoon() {
    _hoverBarTimer?.cancel();
    _hoverBarTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _hoverBarVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFullscreen) {
      return Stack(children: [
        Positioned.fill(child: _buildBody()),
        // Invisible reveal strip along the top screen edge.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 8,
          child: MouseRegion(
            opaque: false,
            onEnter: (_) => _showHoverBar(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedOpacity(
              opacity: _hoverBarVisible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: IgnorePointer(
                ignoring: !_hoverBarVisible,
                child: MouseRegion(
                  onEnter: (_) => _showHoverBar(),
                  onExit: (_) => _hideHoverBarSoon(),
                  child: _ExitFullscreenPill(
                    onExit: () => widget.onFullscreenChanged?.call(false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    }
    return Column(children: [
      _Toolbar(
        session: session,
        onEnterFullscreen: widget.onFullscreenChanged == null
            ? null
            : () => widget.onFullscreenChanged!.call(true),
      ),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    switch (session.status) {
      case VncSessionStatus.connecting:
        return const Center(
            child: Text('Connecting…',
                style: TextStyle(color: AppColors.textSecondary)));
      case VncSessionStatus.error:
      case VncSessionStatus.disconnected:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(session.lastMessage ?? 'Disconnected',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: widget.onReconnect, child: const Text('Retry')),
          ]),
        );
      case VncSessionStatus.connected:
        return LayoutBuilder(builder: (context, constraints) {
          final w = session.width;
          final h = session.height;
          if (w == 0 || h == 0) {
            return const SizedBox.expand();
          }
          final scale =
              math.min(constraints.maxWidth / w, constraints.maxHeight / h);
          final offX = (constraints.maxWidth - w * scale) / 2;
          final offY = (constraints.maxHeight - h * scale) / 2;

          (int, int) toFb(Offset local) => vncSessionPoint(
              localX: local.dx,
              localY: local.dy,
              offX: offX,
              offY: offY,
              scale: scale,
              width: w,
              height: h);

          void sendPointer(Offset local, int mask) {
            final (x, y) = toFb(local);
            if (_lastPointer == (x, y, mask)) return; // drop duplicate events
            _lastPointer = (x, y, mask);
            session.client.sendPointer(x: x, y: y, buttonMask: mask);
          }

          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onFocusChange: (gained) async {
              if (!gained) return;
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              final text = data?.text;
              if (text != null &&
                  text.isNotEmpty &&
                  text != _lastPushedClipboard) {
                _lastPushedClipboard = text;
                session.client.sendClipboardText(text);
              }
            },
            onKeyEvent: (node, event) {
              // Let app-level hotkeys win over the remote.
              if (HotkeyService().shouldSwallowKeyEvent(event)) {
                return KeyEventResult.handled;
              }
              final keysym = vncKeysymFor(event.physicalKey);
              if (keysym == null) return KeyEventResult.ignored;
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                session.client.sendKey(keysym: keysym, down: true);
              } else if (event is KeyUpEvent) {
                session.client.sendKey(keysym: keysym, down: false);
              }
              return KeyEventResult.handled;
            },
            child: Listener(
              onPointerHover: (e) => sendPointer(e.localPosition, 0),
              onPointerMove: (e) =>
                  sendPointer(e.localPosition, _vncButtonMask(e.buttons)),
              onPointerDown: (e) {
                _focusNode.requestFocus();
                sendPointer(e.localPosition, _vncButtonMask(e.buttons));
              },
              // On pointer up Flutter has already cleared the released button
              // from e.buttons, so the derived mask is the post-release state.
              onPointerUp: (e) =>
                  sendPointer(e.localPosition, _vncButtonMask(e.buttons)),
              onPointerSignal: (e) {
                if (e is PointerScrollEvent && e.scrollDelta.dy != 0) {
                  final mask = _vncButtonMask(e.buttons);
                  final wheel = e.scrollDelta.dy < 0 ? 0x08 : 0x10; // up : down
                  final (x, y) = toFb(e.localPosition);
                  // A wheel notch is a press+release of the wheel "button".
                  session.client
                      .sendPointer(x: x, y: y, buttonMask: mask | wheel);
                  session.client.sendPointer(x: x, y: y, buttonMask: mask);
                  _lastPointer = (x, y, mask);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _FramePainter(session, offX, offY, scale),
                  ),
                  // Connected but no frame decoded yet — keep the surface
                  // interactive while showing the cue (restored from M2).
                  if (session.image == null)
                    const Center(
                        child: Text('Waiting for first frame…',
                            style: TextStyle(color: AppColors.textSecondary))),
                ],
              ),
            ),
          );
        });
    }
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.session, this.onEnterFullscreen});
  final VncSession session;
  final VoidCallback? onEnterFullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      color: AppColors.card,
      child: Row(children: [
        const SizedBox(width: 8),
        Text(session.tabLabel, style: Theme.of(context).textTheme.labelMedium),
        const Spacer(),
        IconButton(
          tooltip: 'Push clipboard to remote',
          icon: const Icon(Icons.content_paste_go, size: 16),
          onPressed: () => _pushClipboard(session),
        ),
        if (onEnterFullscreen != null)
          IconButton(
            tooltip: 'Fullscreen',
            icon: const Icon(Icons.fullscreen, size: 16),
            onPressed: session.status == VncSessionStatus.connected
                ? onEnterFullscreen
                : null,
          ),
        IconButton(
          tooltip: 'Disconnect',
          icon: const Icon(Icons.power_settings_new, size: 16),
          onPressed: () => session.client.disconnect(),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }
}

class _ExitFullscreenPill extends StatelessWidget {
  const _ExitFullscreenPill({required this.onExit});
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onExit,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.fullscreen_exit, size: 16),
            SizedBox(width: 6),
            Text('Exit fullscreen'),
          ]),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  /// `repaint: session` redraws on every decoded frame without rebuilding the
  /// surrounding widget tree (the workspace only rebuilds on status changes).
  _FramePainter(this.session, this.offX, this.offY, this.scale)
      : super(repaint: session);

  final VncSession session;
  final double offX, offY, scale;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? img = session.image;
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(offX, offY, img.width * scale, img.height * scale),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      !identical(old.session, session) ||
      old.scale != scale ||
      old.offX != offX ||
      old.offY != offY;
}

Future<void> _pushClipboard(VncSession session) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  if (data?.text != null) {
    session.client.sendClipboardText(data!.text!);
  }
}

/// Flutter's pressed-buttons bitfield -> RFB button bitmask
/// (bit0 left, bit1 middle, bit2 right).
int _vncButtonMask(int flutterButtons) {
  var mask = 0;
  if (flutterButtons & kPrimaryMouseButton != 0) mask |= 0x1;
  if (flutterButtons & kMiddleMouseButton != 0) mask |= 0x2;
  if (flutterButtons & kSecondaryMouseButton != 0) mask |= 0x4;
  return mask;
}
