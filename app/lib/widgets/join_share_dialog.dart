import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/share_provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_theme.dart';

class JoinShareDialog extends StatefulWidget {
  const JoinShareDialog({super.key});

  @override
  State<JoinShareDialog> createState() => _JoinShareDialogState();
}

class _JoinShareDialogState extends State<JoinShareDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _joining = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join(BuildContext context) async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter a 6-character share code');
      return;
    }

    final sync = context.read<SyncProvider>();
    if (!sync.isSupabaseConfigured) {
      setState(() => _error = 'Configure Supabase first (Settings → Sync)');
      return;
    }

    setState(() { _joining = true; _error = null; });
    try {
      await context.read<ShareProvider>().joinSession(
        code,
        sync.supabaseUrl,
        sync.supabaseAnonKey,
      );
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _joining = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebar,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Join Shared Session', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  _UpperCaseFormatter(),
                ],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 4,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'A3K9PX',
                  hintStyle: const TextStyle(color: Color(0xFF333333), letterSpacing: 4),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                  errorText: _error,
                ),
                onSubmitted: (_) => _join(context),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  onPressed: _joining ? null : () => _join(context),
                  child: _joining
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Join', style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
