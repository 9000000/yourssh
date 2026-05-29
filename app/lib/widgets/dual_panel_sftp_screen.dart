import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/host.dart';
import '../models/local_entry.dart';
import '../models/sftp_entry.dart';
import '../providers/host_provider.dart';
import '../providers/local_file_panel_provider.dart';
import '../providers/sftp_panel_provider.dart';
import '../services/sftp_transfer_service.dart';
import '../services/ssh_service.dart';
import 'local_file_panel.dart';
import 'sftp_panel.dart';

class DualPanelSftpScreen extends StatefulWidget {
  const DualPanelSftpScreen({super.key});

  @override
  State<DualPanelSftpScreen> createState() => _DualPanelSftpScreenState();
}

class _DualPanelSftpScreenState extends State<DualPanelSftpScreen> {
  Host? _remoteHost;
  late LocalFilePanelProvider _localProvider;
  late SftpPanelProvider _remoteProvider;
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    _localProvider = LocalFilePanelProvider();
    _remoteProvider = SftpPanelProvider();
  }

  @override
  void dispose() {
    _localProvider.dispose();
    _remoteProvider.dispose();
    super.dispose();
  }

  Future<void> _pickHost() async {
    final hosts = context.read<HostProvider>().allHosts;
    if (hosts.isEmpty) return;
    final picked = await showDialog<Host>(
      context: context,
      builder: (ctx) => _HostPickerDialog(hosts: hosts, current: _remoteHost),
    );
    if (picked != null && picked.id != _remoteHost?.id) {
      setState(() => _remoteHost = picked);
    }
  }

  Future<void> _uploadSelected() async {
    final host = _remoteHost;
    if (host == null) return;
    final selected = _localProvider.selectedEntries
        .where((e) => !e.isDirectory)
        .toList();
    if (selected.isEmpty) return;

    setState(() => _isTransferring = true);
    final service = context.read<SftpTransferService>();
    final remoteDir = _remoteProvider.currentPath;
    try {
      for (final entry in selected) {
        await service.copyLocalToRemote(
          localPath: entry.path,
          remoteHost: host,
          remoteDir: remoteDir,
        );
      }
      if (!mounted) return;
      _remoteProvider.setLoadState(SftpPanelLoadState.loading);
      try {
        final entries = await service.listDirectory(host, remoteDir);
        if (!mounted) return;
        _remoteProvider
          ..setEntries(entries)
          ..setLoadState(SftpPanelLoadState.loaded);
      } catch (e) {
        if (mounted) _remoteProvider.setLoadState(SftpPanelLoadState.error, error: e.toString());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: const Color(0xFF2A1A1A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _downloadSelected() async {
    final host = _remoteHost;
    if (host == null) return;
    final selected = _remoteProvider.selectedEntries
        .where((e) => !e.isDirectory)
        .toList();
    if (selected.isEmpty) return;

    setState(() => _isTransferring = true);
    final service = context.read<SftpTransferService>();
    final localDir = _localProvider.currentPath;
    try {
      for (final entry in selected) {
        await service.copyRemoteToLocal(
          remoteHost: host,
          remoteEntry: entry,
          localDir: localDir,
        );
      }
      if (!mounted) return;
      await _localProvider.reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: const Color(0xFF2A1A1A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _onLocalEntryDroppedOnRemote(LocalEntry entry) async {
    if (_remoteHost == null || entry.isDirectory) return;
    _localProvider.selectOnly(entry);
    await _uploadSelected();
  }

  Future<void> _onRemoteEntryDroppedOnLocal(SftpEntry entry) async {
    if (_remoteHost == null || entry.isDirectory) return;
    _remoteProvider.toggleSelection(entry);
    await _downloadSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (ctx) => SftpTransferService(ctx.read<SshService>()),
      child: ListenableBuilder(
        listenable: Listenable.merge([_localProvider, _remoteProvider]),
        builder: (context, _) => Column(
          children: [
            if (_isTransferring)
              const LinearProgressIndicator(
                color: Color(0xFF22C55E),
                backgroundColor: Color(0xFF1A1A1A),
                minHeight: 2,
              ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: DragTarget<SftpEntry>(
                      onAcceptWithDetails: (d) =>
                          _onRemoteEntryDroppedOnLocal(d.data),
                      builder: (context, candidates, _) => Container(
                        decoration: BoxDecoration(
                          border: candidates.isNotEmpty
                              ? Border.all(
                                  color: const Color(0xFF22C55E)
                                      .withValues(alpha: 0.4),
                                  width: 2)
                              : null,
                        ),
                        child: LocalFilePanel(provider: _localProvider),
                      ),
                    ),
                  ),
                  _buildTransferBar(),
                  Expanded(
                    child: DragTarget<LocalEntry>(
                      onAcceptWithDetails: (d) =>
                          _onLocalEntryDroppedOnRemote(d.data),
                      builder: (context, candidates, _) => Container(
                        decoration: BoxDecoration(
                          border: candidates.isNotEmpty
                              ? Border.all(
                                  color: const Color(0xFF22C55E)
                                      .withValues(alpha: 0.4),
                                  width: 2)
                              : null,
                        ),
                        child: SftpPanel(
                          key: ValueKey('remote_${_remoteHost?.id}'),
                          host: _remoteHost,
                          panelId: 'remote',
                          provider: _remoteProvider,
                          onChangeHost: _pickHost,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferBar() {
    final canUpload = _remoteHost != null &&
        _localProvider.selectedEntries.any((e) => !e.isDirectory) &&
        !_isTransferring;
    final canDownload = _remoteHost != null &&
        _remoteProvider.selectedEntries.any((e) => !e.isDirectory) &&
        !_isTransferring;

    return Container(
      width: 36,
      color: const Color(0xFF111111),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TransferButton(
            icon: Icons.arrow_forward,
            tooltip: 'Upload to remote',
            enabled: canUpload,
            onTap: _uploadSelected,
          ),
          const SizedBox(height: 8),
          _TransferButton(
            icon: Icons.arrow_back,
            tooltip: 'Download to local',
            enabled: canDownload,
            onTap: _downloadSelected,
          ),
        ],
      ),
    );
  }
}

class _TransferButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _TransferButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled
                  ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                  : const Color(0xFF252525),
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: enabled
                ? const Color(0xFF22C55E)
                : const Color(0xFF333333),
          ),
        ),
      ),
    );
  }
}

class _HostPickerDialog extends StatelessWidget {
  final List<Host> hosts;
  final Host? current;

  const _HostPickerDialog({required this.hosts, required this.current});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFF2A2A2A)))),
              child: Row(
                children: [
                  const Icon(Icons.dns_outlined,
                      size: 15, color: Color(0xFF888888)),
                  const SizedBox(width: 8),
                  const Text('Select Remote Host',
                      style: TextStyle(
                          color: Color(0xFFD4D4D4),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        size: 14, color: Color(0xFF555555)),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: hosts.length,
                itemBuilder: (_, i) {
                  final h = hosts[i];
                  final isActive = h.id == current?.id;
                  return InkWell(
                    onTap: () => Navigator.pop(context, h),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: isActive
                          ? const Color(0xFF22C55E)
                              .withValues(alpha: 0.08)
                          : Colors.transparent,
                      child: Row(children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.dns,
                              size: 14,
                              color: Color(0xFF22C55E)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(h.label,
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFD4D4D4),
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  )),
                              Text(
                                '${h.username}@${h.host}:${h.port}',
                                style: const TextStyle(
                                    color: Color(0xFF555555),
                                    fontSize: 11,
                                    fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          const Icon(Icons.check,
                              size: 14,
                              color: Color(0xFF22C55E)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
