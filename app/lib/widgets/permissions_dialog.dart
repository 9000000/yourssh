// app/lib/widgets/permissions_dialog.dart
import 'package:flutter/material.dart';
import '../util/file_mode.dart';

/// chmod dialog: a 9-checkbox rwx grid (owner/group/others) two-way synced
/// with an octal text field. Returns `(mode, recursive)` via Navigator.pop,
/// or null when cancelled. Special bits (setuid/setgid/sticky) survive a
/// checkbox-only edit; the octal field accepts 4-digit values to set them.
class PermissionsDialog extends StatefulWidget {
  final String entryName;
  final int initialMode;
  final bool isDirectory;

  const PermissionsDialog({
    super.key,
    required this.entryName,
    required this.initialMode,
    required this.isDirectory,
  });

  @override
  State<PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<PermissionsDialog> {
  late int _mode = widget.initialMode & 0xFFF;
  late final TextEditingController _octalCtrl =
      TextEditingController(text: modeToOctal(_mode));
  bool _recursive = false;

  static const _fg = Color(0xFFD4D4D4);
  static const _dim = Color(0xFF888888);

  // (row label, read bit, write bit, execute bit) per permission class.
  static const _rows = [
    ('Owner', 0x100, 0x80, 0x40),
    ('Group', 0x20, 0x10, 0x8),
    ('Others', 0x4, 0x2, 0x1),
  ];
  // Key suffixes per row for widget tests: perm_u_r, perm_g_w, perm_o_x...
  static const _rowKeys = ['u', 'g', 'o'];

  void _setBit(int bit, bool on) {
    setState(() {
      _mode = on ? (_mode | bit) : (_mode & ~bit);
      _octalCtrl.text = modeToOctal(_mode);
    });
  }

  void _onOctalChanged(String text) {
    final parsed = parseOctal(text);
    if (parsed == null) return; // keep last valid mode while typing
    setState(() => _mode = parsed);
  }

  @override
  void dispose() {
    _octalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text('Permissions — ${widget.entryName}',
          style: const TextStyle(color: _fg, fontSize: 14)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {0: FixedColumnWidth(64)},
            children: [
              const TableRow(children: [
                SizedBox.shrink(),
                Text('Read',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _dim, fontSize: 11)),
                Text('Write',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _dim, fontSize: 11)),
                Text('Execute',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _dim, fontSize: 11)),
              ]),
              for (final (i, row) in _rows.indexed)
                TableRow(children: [
                  Text(row.$1,
                      style: const TextStyle(color: _fg, fontSize: 12)),
                  for (final (j, bit) in [row.$2, row.$3, row.$4].indexed)
                    Checkbox(
                      key: Key('perm_${_rowKeys[i]}_${'rwx'[j]}'),
                      value: _mode & bit != 0,
                      onChanged: (v) => _setBit(bit, v ?? false),
                      side: const BorderSide(color: Color(0xFF444444)),
                      activeColor: const Color(0xFF22C55E),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Octal', style: TextStyle(color: _dim, fontSize: 12)),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _octalCtrl,
                onChanged: _onOctalChanged,
                style: const TextStyle(
                    color: _fg, fontSize: 13, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  isDense: true,
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF2A2A2A))),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF22C55E))),
                ),
              ),
            ),
          ]),
          if (widget.isDirectory) ...[
            const SizedBox(height: 8),
            Row(children: [
              Checkbox(
                key: const Key('perm_recursive'),
                value: _recursive,
                onChanged: (v) => setState(() => _recursive = v ?? false),
                side: const BorderSide(color: Color(0xFF444444)),
                activeColor: const Color(0xFF22C55E),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const Text('Apply recursively',
                  style: TextStyle(color: _fg, fontSize: 12)),
            ]),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _dim)),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, (mode: _mode, recursive: _recursive)),
          child:
              const Text('Apply', style: TextStyle(color: Color(0xFF22C55E))),
        ),
      ],
    );
  }
}
