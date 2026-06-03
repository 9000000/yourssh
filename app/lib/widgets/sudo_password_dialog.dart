import 'package:flutter/material.dart';
import '../models/host.dart';

/// Prompts for the sudo password used by elevated SFTP. Pops with
/// `(password:, remember:)` on OK, or null when cancelled. Persisting the
/// password (when remember is checked) is the caller's job.
class SudoPasswordDialog extends StatefulWidget {
  final Host host;
  const SudoPasswordDialog({super.key, required this.host});

  @override
  State<SudoPasswordDialog> createState() => _SudoPasswordDialogState();
}

class _SudoPasswordDialogState extends State<SudoPasswordDialog> {
  final _controller = TextEditingController();
  bool _remember = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.of(context)
        .pop((password: _controller.text, remember: _remember));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sudo password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Root SFTP on ${widget.host.username}@${widget.host.host} '
            'needs the sudo password.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          CheckboxListTile(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            title: const Text('Remember in system keychain',
                style: TextStyle(fontSize: 13)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
