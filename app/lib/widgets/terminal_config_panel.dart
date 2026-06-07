import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/keyword_highlight_rule.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'terminal_appearance_controls.dart';
import 'workspace_side_panel.dart';

class TerminalConfigPanel extends StatelessWidget {
  final VoidCallback? onClose;
  final VoidCallback? onOpenSettings;

  const TerminalConfigPanel({super.key, this.onClose, this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return WorkspaceSidePanel(
      title: 'Terminal',
      closeTooltip: 'Close terminal settings',
      onClose: onClose,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TerminalAppearanceControls(
            layout: AppearanceControlsLayout.vertical,
          ),
          const SizedBox(height: 20),
          _KeywordHighlightCompact(onOpenSettings: onOpenSettings),
        ],
      ),
    );
  }
}

class _KeywordHighlightCompact extends StatelessWidget {
  final VoidCallback? onOpenSettings;
  const _KeywordHighlightCompact({this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KEYWORD HIGHLIGHTING',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text('Enable',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 13)),
            ),
            Switch(
              value: settings.keywordHighlightingEnabled,
              onChanged: (v) => context
                  .read<SettingsProvider>()
                  .save(keywordHighlightingEnabled: v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...settings.keywordHighlightRules.asMap().entries.map((entry) {
          final i = entry.key;
          final rule = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                if (rule.background != null)
                  _Dot(color: rule.background!),
                if (rule.foreground != null) ...[
                  if (rule.background != null) const SizedBox(width: 4),
                  _Dot(color: rule.foreground!, border: true),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.label,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12),
                  ),
                ),
                Switch(
                  value: rule.enabled,
                  onChanged: (v) {
                    final updated = List<AppKeywordHighlightRule>.from(
                        settings.keywordHighlightRules);
                    updated[i] = rule.copyWith(enabled: v);
                    context
                        .read<SettingsProvider>()
                        .save(keywordHighlightRules: updated);
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        if (onOpenSettings != null)
          GestureDetector(
            onTap: onOpenSettings,
            child: const Text(
              'Manage rules in Settings →',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  decoration: TextDecoration.underline),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final bool border;
  const _Dot({required this.color, this.border = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border
            ? Border.all(color: AppColors.textSecondary, width: 1)
            : null,
      ),
    );
  }
}
