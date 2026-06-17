import 'package:flutter/material.dart';

import '../models/host.dart';
import '../theme/app_theme.dart';

/// Small pill marking a remote-desktop host's protocol (RDP / VNC). One widget
/// shared by the dashboard cards, list rows, and the host detail header so a
/// restyle can't leave the call sites visually diverged. SSH renders nothing.
class ProtocolBadge extends StatelessWidget {
  const ProtocolBadge(this.protocol, {super.key});

  final HostProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (protocol) {
      HostProtocol.rdp => ('RDP', AppColors.blue),
      HostProtocol.vnc => ('VNC', AppColors.purple),
      HostProtocol.ssh => ('', AppColors.blue),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
