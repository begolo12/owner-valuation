import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../api.dart';
import '../widgets.dart';

/// Layar kunci: diminta sekali saat token belum ada di perangkat.
/// Token tidak pernah ikut ter-build ke bundle publik.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _tokenCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tokenCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _tokenCtl.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Token belum diisi.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.i.save(token: token);
      await Api.i.fetchMeta();
      if (!mounted) return;
      widget.onUnlocked();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.message : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Penilaian Owner', style: theme.textTheme.h2),
                  const SizedBox(height: 6),
                  Text(
                    'Masukkan token aplikasi untuk membuka data penilaian.',
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Notice(message: _error!, icon: Icons.error_outline),
                    const SizedBox(height: 16),
                  ],
                  ShadInput(
                    controller: _tokenCtl,
                    obscureText: true,
                    autofocus: true,
                    placeholder: const Text('Token aplikasi'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  ShadButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Memeriksa…' : 'Buka'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Token dibuat di server (env APP_TOKEN). Hanya perlu sekali di tiap perangkat.',
                    style: theme.textTheme.small,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
