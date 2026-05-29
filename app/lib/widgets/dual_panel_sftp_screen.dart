// app/lib/widgets/dual_panel_sftp_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../services/sftp_transfer_service.dart';
import '../services/ssh_service.dart';
import 'sftp_panel.dart';

class DualPanelSftpScreen extends StatelessWidget {
  const DualPanelSftpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>().activeSession;

    if (session == null) {
      return const Center(
        child: Text(
          'Connect to a host to browse files',
          style: TextStyle(color: Color(0xFF555555)),
        ),
      );
    }

    return Provider(
      create: (ctx) => SftpTransferService(ctx.read<SshService>()),
      child: Row(
        children: [
          Expanded(
            child: SftpPanel(session: session, panelId: 'left'),
          ),
          const VerticalDivider(width: 1, color: Color(0xFF2A2A2A)),
          Expanded(
            child: SftpPanel(session: session, panelId: 'right'),
          ),
        ],
      ),
    );
  }
}
