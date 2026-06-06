import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/host.dart';
import '../services/os_detection.dart';
import '../theme/app_theme.dart';

/// Termius-style visual chain editor for the single-hop jump host.
///
/// Pure presentational: data in via constructor, the only output is
/// [onSelect] — a picked jump host, or null when the user taps Clear.
/// Spec: docs/superpowers/specs/2026-06-06-host-chain-editor-design.md
class HostChainEditor extends StatelessWidget {
  /// Label of the host being edited (bottom card / helper text).
  final String currentHostLabel;

  /// detectedOs of the host being edited (null → generic glyph).
  final String? currentHostOs;

  /// The selected jump host, or null for a direct connection.
  final Host? jumpHost;

  /// Shows the key glyph on the jump card when agent forwarding is on.
  final bool agentForwarding;

  /// Hosts selectable as jump (caller excludes the host being edited).
  final List<Host> candidates;

  final ValueChanged<Host?> onSelect;

  const HostChainEditor({
    super.key,
    required this.currentHostLabel,
    this.currentHostOs,
    this.jumpHost,
    this.agentForwarding = false,
    required this.candidates,
    required this.onSelect,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<Host>(
      context: context,
      builder: (_) => _HostPickerDialog(candidates: candidates),
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final jump = jumpHost;
    if (jump == null) return _emptyState(context);
    return _chain(context, jump);
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              text: 'Adding a host will route the connection to ',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              children: [
                TextSpan(
                  text: currentHostLabel,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _pick(context),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.cardHover,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Add a Host',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chain(BuildContext context, Host jump) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HostCard(
          label: jump.label.isNotEmpty
              ? jump.label
              : '${jump.username}@${jump.host}',
          detectedOs: jump.detectedOs,
          trailing: agentForwarding
              ? const Tooltip(
                  message:
                      'Agent forwarding on — this hop can use your local keys',
                  child: Icon(Icons.key, size: 14, color: AppColors.accent),
                )
              : null,
          onTap: () => _pick(context),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Icon(Icons.arrow_downward,
              size: 16, color: AppColors.textTertiary),
        ),
        _HostCard(label: currentHostLabel, detectedOs: currentHostOs),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => onSelect(null),
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Clear',
              style: TextStyle(
                  color: AppColors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// One host row in the chain: OS glyph tile + label (+ optional trailing).
class _HostCard extends StatelessWidget {
  final String label;
  final String? detectedOs;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _HostCard({
    required this.label,
    this.detectedOs,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final asset = osIconAsset(detectedOs);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.cardHover,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: asset != null
                  ? SvgPicture.asset(
                      asset,
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                          AppColors.textPrimary, BlendMode.srcIn),
                    )
                  : const Icon(Icons.dns_outlined,
                      size: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// Picker dialog added in Task 3.
class _HostPickerDialog extends StatelessWidget {
  final List<Host> candidates;
  const _HostPickerDialog({required this.candidates});

  @override
  Widget build(BuildContext context) => const Dialog();
}
