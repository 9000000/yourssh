import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vnc_session.dart';
import '../services/hotkey_service.dart';
import '../theme/app_theme.dart';
import '../util/vnc_input_mapping.dart';

/// View-only VNC framebuffer surface. Mirrors RdpWorkspace's render pipeline:
/// the widget rebuilds only on status change, while frames repaint through the
/// painter's `repaint: session` listenable. Input/clipboard/fullscreen are
/// later milestones.
class VncWorkspace extends StatefulWidget {
  const VncWorkspace({super.key, required this.session, this.onReconnect});

  final VncSession session;
  final VoidCallback? onReconnect;

  @override
  State<VncWorkspace> createState() => _VncWorkspaceState();
}

class _VncWorkspaceState extends State<VncWorkspace> {
  VncSession get session => widget.session;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
  }

  @override
  void didUpdateWidget(VncWorkspace old) {
    super.didUpdateWidget(old);
    if (!identical(old.session, widget.session)) {
      old.session.removeListener(_onSessionChanged);
      session.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Toolbar(session: session),
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
            session.client.sendPointer(x: x, y: y, buttonMask: mask);
          }

          return Focus(
            focusNode: _focusNode,
            autofocus: true,
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
                }
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _FramePainter(session, offX, offY, scale),
              ),
            ),
          );
        });
    }
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.session});
  final VncSession session;

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
          tooltip: 'Disconnect',
          icon: const Icon(Icons.power_settings_new, size: 16),
          onPressed: () => session.client.disconnect(),
        ),
        const SizedBox(width: 4),
      ]),
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

/// Flutter's pressed-buttons bitfield -> RFB button bitmask
/// (bit0 left, bit1 middle, bit2 right).
int _vncButtonMask(int flutterButtons) {
  var mask = 0;
  if (flutterButtons & kPrimaryMouseButton != 0) mask |= 0x1;
  if (flutterButtons & kMiddleMouseButton != 0) mask |= 0x2;
  if (flutterButtons & kSecondaryMouseButton != 0) mask |= 0x4;
  return mask;
}
