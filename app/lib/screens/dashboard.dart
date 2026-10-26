import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'holding.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Dashboard? _dash;
  List<Holding> _holdings = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Api.i.fetchMeta();
      final results = await Future.wait([Api.i.dashboard(), Api.i.holdings()]);
      if (!mounted) return;
      setState(() {
        _dash = results[0] as Dashboard;
        _holdings = results[1] as List<Holding>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal memuat: $e';
        _loading = false;
      });
    }
  }

  Future<void> _addHolding() async {
    final name = await promptText(
      context,
      title: 'Holding baru',
      description: 'Holding adalah grup usaha. Tambahkan proyek/owner di dalamnya setelah ini.',
      hint: 'Contoh: PT Sinar Abadi',
    );
    if (name == null || name.isEmpty) return;
    try {
      await Api.i.createHolding(name);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
          children: [
            PageHeader(
              title: 'Penilaian Owner',
              subtitle: _dash == null
                  ? 'Memuat data…'
                  : 'Kuartal ${_dash!.quarter} · ${_dash!.owners} owner',
              trailing: ShadButton(
                size: ShadButtonSize.sm,
                leading: const Icon(Icons.add, size: 16),
                onPressed: _addHolding,
                child: const Text('Holding'),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Notice(message: _error!, icon: Icons.error_outline),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_dash != null) ...[
              _Stats(dash: _dash!),
              const SizedBox(height: 16),
              _ModelSummary(dash: _dash!),
              if (_dash!.top.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TopList(dash: _dash!),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Holding', style: theme.textTheme.large),
                  const Spacer(),
                  if (_dash!.missing > 0)
                    ShadBadge.secondary(child: Text('${_dash!.missing} belum dinilai')),
                ],
              ),
              const SizedBox(height: 12),
              if (_holdings.isEmpty)
                const Notice(
                  message: 'Belum ada holding. Tekan tombol "Holding" untuk menambah.',
                  icon: Icons.inbox_outlined,
                )
              else
                ..._holdings.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HoldingTile(holding: h, onChanged: _load),
                    )),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.dash});
  final Dashboard dash;

  @override
  Widget build(BuildContext context) {
    final done = dash.owners == 0 ? 0 : (dash.assessed * 100 / dash.owners).round();
    return LayoutBuilder(
      builder: (context, c) {
        final two = c.maxWidth < 520;
        final cards = [
          StatCard(label: 'Holding', value: '${dash.holdings}'),
          StatCard(label: 'Owner / Proyek', value: '${dash.owners}'),
          StatCard(
            label: 'Sudah dinilai',
            value: '$done%',
            hint: '${dash.assessed} dari ${dash.owners}',
          ),
        ];
        return GridView.count(
          crossAxisCount: two ? 2 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: two ? 2.0 : 1.9,
          children: cards,
        );
      },
    );
  }
}

class _ModelSummary extends StatelessWidget {
  const _ModelSummary({required this.dash});
  final Dashboard dash;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    if (dash.byModel.isEmpty) {
      return const Notice(message: 'Belum ada penilaian di kuartal ini.');
    }
    return ShadCard(
      title: const Text('Rata-rata per model'),
      description: Text('Kuartal ${dash.quarter}'),
      child: Column(
        children: [
          for (final m in dash.byModel)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(child: Text(modelLabels[m.model] ?? m.model, style: theme.textTheme.p)),
                  Text('${m.avg.toStringAsFixed(1)}  ·  ${m.count} owner',
                      style: theme.textTheme.muted),
                  const SizedBox(width: 10),
                  GradeBadge(grade: gradeOf(m.avg), compact: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopList extends StatelessWidget {
  const _TopList({required this.dash});
  final Dashboard dash;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      title: const Text('Peringkat teratas'),
      description: Text('Berdasarkan skor kuartal ${dash.quarter}'),
      child: Column(
        children: [
          for (final (i, t) in dash.top.take(5).indexed)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  SizedBox(width: 22, child: Text('${i + 1}', style: theme.textTheme.muted)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: theme.textTheme.p),
                        Text(
                          '${t.holding}${t.project == null ? '' : ' · ${t.project}'}',
                          style: theme.textTheme.small,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${t.total.toStringAsFixed(1)}  ', style: theme.textTheme.p),
                  GradeBadge(grade: t.grade, compact: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.holding, required this.onChanged});

  final Holding holding;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => HoldingScreen(holding: holding)),
          );
          await onChanged();
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.accent,
              child: Text(
                holding.name.characters.first.toUpperCase(),
                style: TextStyle(color: theme.colorScheme.accentForeground),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(holding.name, style: theme.textTheme.p),
                  Text('${holding.ownerCount} owner/proyek', style: theme.textTheme.small),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}
