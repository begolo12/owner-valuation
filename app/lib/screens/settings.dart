import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../api.dart';
import '../main.dart' show dataVersion, themeMode;
import '../update.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtl = TextEditingController(text: Api.i.baseUrl);
  final _tokenCtl = TextEditingController(text: Api.i.token);
  String _version = '—';
  String? _status;
  UpdateInfo? _update;
  bool _busy = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = '${i.version}+${i.buildNumber}');
    });
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    _tokenCtl.dispose();
    super.dispose();
  }

  Future<void> _saveConn() async {
    await Api.i.save(baseUrl: _urlCtl.text.trim(), token: _tokenCtl.text.trim());
    try {
      final meta = await Api.i.fetchMeta();
      if (!mounted) return;
      setState(() => _status = 'Tersambung. Kuartal berjalan ${meta.currentQuarter}.');
      dataVersion.value++;
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal: ${e is ApiException ? e.message : e}');
    }
  }

  Future<void> _toggleTheme(bool dark) async {
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    await const FlutterSecureStorage().write(key: 'theme_mode', value: dark ? 'dark' : 'light');
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    final info = await checkUpdate();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _update = info;
      _status = info == null
          ? 'Tidak bisa cek rilis (offline atau belum ada rilis).'
          : info.hasUpdate
              ? 'Versi ${info.latestVersion} tersedia.'
              : 'Sudah versi terbaru (${info.currentVersion}).';
    });
  }

  Future<void> _install() async {
    final info = _update;
    if (info == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _status = 'Mengunduh…';
    });
    try {
      final msg = await downloadAndInstall(info, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Gagal: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hasUpdate = _update?.hasUpdate ?? false;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          const PageHeader(
            title: 'Pengaturan',
            subtitle: 'Koneksi server, tampilan, dan pembaruan aplikasi',
          ),
          const SizedBox(height: 20),
          if (_status != null) ...[
            Notice(message: _status!),
            const SizedBox(height: 16),
          ],
          ShadCard(
            title: const Text('Server'),
            description: const Text('Alamat backend Vercel dan token aplikasi.'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShadInput(
                  controller: _urlCtl,
                  keyboardType: TextInputType.url,
                  placeholder: const Text('https://contoh.vercel.app'),
                ),
                const SizedBox(height: 10),
                ShadInput(
                  controller: _tokenCtl,
                  obscureText: true,
                  placeholder: const Text('Token aplikasi'),
                ),
                const SizedBox(height: 14),
                ShadButton(onPressed: _saveConn, child: const Text('Simpan & uji koneksi')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('Tampilan'),
            child: ShadSwitch(
              value: themeMode.value == ThemeMode.dark,
              label: const Text('Mode gelap'),
              sublabel: const Text('Tema oil: aksen amber di atas dasar stone.'),
              onChanged: _toggleTheme,
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('Pembaruan'),
            description: Text('Versi terpasang: $_version'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_busy && _progress > 0) ...[
                  ShadProgress(value: _progress),
                  const SizedBox(height: 8),
                  Text('${(_progress * 100).toStringAsFixed(0)}%', style: theme.textTheme.small),
                  const SizedBox(height: 10),
                ],
                if (hasUpdate && _update!.notes.isNotEmpty) ...[
                  Text(
                    _update!.notes,
                    style: theme.textTheme.small,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    ShadButton.outline(
                      onPressed: _busy ? null : _check,
                      child: Text(_busy ? 'Memproses…' : 'Cek pembaruan'),
                    ),
                    if (hasUpdate && !_busy) ...[
                      const SizedBox(width: 10),
                      ShadButton(onPressed: _install, child: const Text('Unduh & pasang')),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('Alur kerja'),
            child: Text(
              '1. Tambah holding.\n'
              '2. Tambah proyek/owner di dalam holding.\n'
              '3. Tekan "Nilai" untuk skor kuartal berjalan.\n'
              '4. Pilih model: Market Baru atau Market Existing.',
              style: theme.textTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
