import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../api.dart';
import '../widgets.dart';
import 'owner.dart';

class HoldingScreen extends StatefulWidget {
  const HoldingScreen({super.key, required this.holding});
  final Holding holding;

  @override
  State<HoldingScreen> createState() => _HoldingScreenState();
}

class _HoldingScreenState extends State<HoldingScreen> {
  List<Owner> _owners = const [];
  String _quarter = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Spinner hanya saat pertama; refresh memakai data lama agar terasa instan.
    if (_owners.isEmpty) setState(() => _loading = true);
    try {
      final detail = await Api.i.holdingDetail(widget.holding.id);
      if (!mounted) return;
      setState(() {
        _owners = detail.owners;
        _quarter = Api.i.meta?.currentQuarter ?? '';
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : '$e';
        _loading = false;
      });
    }
  }

  Future<void> _addOwner() async {
    final name = await promptText(
      context,
      title: 'Owner / proyek baru',
      description: 'Nama owner atau nama proyek di bawah ${widget.holding.name}.',
      hint: 'Contoh: Budi Santoso — Cluster Melati',
    );
    if (name == null || name.isEmpty) return;
    try {
      await Api.i.createOwner(widget.holding.id, name);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : '$e');
    }
  }

  Future<void> _open(Owner owner) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OwnerScreen(ownerId: owner.id)),
    );
    await _load();
  }

  Future<void> _delete(Owner owner) async {
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Hapus owner?'),
        description: Text('Semua penilaian "${owner.name}" ikut terhapus. Tindakan ini permanen.'),
        actions: [
          ShadButton.outline(child: const Text('Batal'), onPressed: () => Navigator.pop(ctx, false)),
          ShadButton.destructive(
            child: const Text('Hapus'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.i.deleteOwner(owner.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        title: Text(widget.holding.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOwner,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.primaryForeground,
        icon: const Icon(Icons.add),
        label: const Text('Owner'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: [
                if (_error != null) ...[
                  Notice(message: _error!, icon: Icons.error_outline),
                  const SizedBox(height: 16),
                ],
                Text('Proyek / owner', style: theme.textTheme.large),
                const SizedBox(height: 4),
                Text(
                  'Nilai per kuartal (kuartal berjalan: ${_quarter.isEmpty ? '—' : _quarter})',
                  style: theme.textTheme.muted,
                ),
                const SizedBox(height: 16),
                if (_owners.isEmpty)
                  const Notice(
                    message: 'Belum ada owner. Tekan tombol "Owner" di bawah.',
                    icon: Icons.inbox_outlined,
                  )
                else
                  ..._owners.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OwnerTile(
                          owner: o,
                          onTap: () => _open(o),
                          onDelete: () => _delete(o),
                        ),
                      )),
              ],
            ),
    );
  }
}

class _OwnerTile extends StatelessWidget {
  const _OwnerTile({required this.owner, required this.onTap, required this.onDelete});

  final Owner owner;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final existing = _score(owner.latest, 'market_existing');
    final baru = _score(owner.latest, 'market_baru');

    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(owner.name, style: theme.textTheme.p),
                  const SizedBox(height: 2),
                  Text(
                    owner.latest.isEmpty
                        ? 'Belum dinilai'
                        : 'Existing ${existing?.total.toStringAsFixed(1) ?? '—'}'
                            '  ·  Baru ${baru?.total.toStringAsFixed(1) ?? '—'}',
                    style: theme.textTheme.small,
                  ),
                ],
              ),
            ),
            if (existing != null) ...[
              GradeBadge(grade: existing.grade, compact: true),
              const SizedBox(width: 8),
            ],
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: theme.colorScheme.mutedForeground),
              onSelected: (v) {
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

LatestScore? _score(List<LatestScore> list, String model) {
  for (final l in list) {
    if (l.model == model) return l;
  }
  return null;
}

