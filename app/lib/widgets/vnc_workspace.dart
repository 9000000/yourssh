import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/vnc_session.dart';
import '../theme/app_theme.dart';

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
          final img = session.image;
          if (img == null) {
            return const Center(
                child: Text('Waiting for first frame…',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          final scale = math.min(constraints.maxWidth / img.width,
              constraints.maxHeight / img.height);
          final dw = img.width * scale;
          final dh = img.height * scale;
          final offX = (constraints.maxWidth - dw) / 2;
          final offY = (constraints.maxHeight - dh) / 2;
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _FramePainter(session, offX, offY, scale),
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
