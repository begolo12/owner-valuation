import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../api.dart';
import '../criteria.dart';
import '../theme.dart';
import '../widgets.dart';

class OwnerScreen extends StatefulWidget {
  const OwnerScreen({super.key, required this.ownerId});
  final String ownerId;

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  Owner? _owner;
  List<Assessment> _assessments = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_owner == null) setState(() => _loading = true);
    try {
      final d = await Api.i.ownerDetail(widget.ownerId);
      if (!mounted) return;
      setState(() {
        _owner = d.owner;
        _assessments = d.assessments;
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

  Future<void> _assess() async {
    // Dialog butuh meta (model, bobot, kuartal). Ambil kalau belum ada.
    if (Api.i.meta == null) {
      try {
        await Api.i.fetchMeta();
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e is ApiException ? e.message : '$e');
        return;
      }
    }
    final saved = await showShadDialog<bool>(
      context: context,
      builder: (_) => _AssessDialog(ownerId: widget.ownerId, existing: _assessments),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(Assessment a) async {
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Hapus penilaian?'),
        description: Text('Penilaian ${a.quarter} · ${modelLabels[a.model]} akan dihapus permanen.'),
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
      await Api.i.deleteAssessment(widget.ownerId, a.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final owner = _owner;
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        title: Text(owner?.name ?? 'Owner'),
      ),
      floatingActionButton: owner == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _assess,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.primaryForeground,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Nilai'),
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
                if (owner != null) ...[
                  Text(owner.name, style: theme.textTheme.h2),
                  if (owner.holdingName != null)
                    Text(owner.holdingName!, style: theme.textTheme.muted),
                  if (owner.project != null) ...[
                    const SizedBox(height: 4),
                    Text(owner.project!, style: theme.textTheme.small),
                  ],
                  const SizedBox(height: 20),
                  _LatestRow(latest: owner.latest),
                  const SizedBox(height: 20),
                ],
                Text('Riwayat penilaian', style: theme.textTheme.large),
                const SizedBox(height: 4),
                Text('Satu nilai per model per kuartal. Nilai ulang akan menimpa kuartal yang sama.',
                    style: theme.textTheme.muted),
                const SizedBox(height: 12),
                if (_assessments.isEmpty)
                  const Notice(message: 'Belum ada penilaian. Tekan "Nilai" untuk mulai.')
                else
                  ..._assessments.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AssessTile(assessment: a, onDelete: () => _delete(a)),
                      )),
              ],
            ),
    );
  }
}

class _LatestRow extends StatelessWidget {
  const _LatestRow({required this.latest});
  final List<LatestScore> latest;

  @override
  Widget build(BuildContext context) {
    if (latest.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (final l in latest) ...[
          Expanded(
            child: ShadCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(modelLabels[l.model] ?? l.model, style: ShadTheme.of(context).textTheme.small),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(l.total.toStringAsFixed(1),
                          style: ShadTheme.of(context).textTheme.h3),
                      const SizedBox(width: 8),
                      GradeBadge(grade: l.grade, compact: true),
                    ],
                  ),
                  Text(l.quarter, style: ShadTheme.of(context).textTheme.muted),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _AssessTile extends StatelessWidget {
  const _AssessTile({required this.assessment, required this.onDelete});
  final Assessment assessment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final a = assessment;
    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(a.quarter, style: theme.textTheme.p),
              const SizedBox(width: 8),
              ShadBadge.secondary(child: Text(modelLabels[a.model] ?? a.model)),
              const Spacer(),
              Text(a.total.toStringAsFixed(1), style: theme.textTheme.p),
              const SizedBox(width: 8),
              GradeBadge(grade: a.grade, compact: true),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: theme.colorScheme.mutedForeground),
                onSelected: (_) => onDelete(),
                itemBuilder: (_) => const [PopupMenuItem(value: 'd', child: Text('Hapus'))],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${paymentLabels[a.paymentMethod] ?? a.paymentMethod} · ${a.paymentTenor} bln · '
            'bayar ${rupiah(a.paidAmount)} · proyeksi ${rupiah(a.projectionValue)}',
            style: theme.textTheme.small,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in a.scores.entries)
                ShadBadge.outline(
                  child: Text('${scoreLabels[e.key] ?? e.key} ${e.value.toStringAsFixed(0)}'),
                ),
            ],
          ),
          if (a.projectionNotes != null && a.projectionNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(a.projectionNotes!, style: theme.textTheme.muted),
          ],
        ],
      ),
    );
  }
}

const scoreLabels = {
  'holding': 'Holding',
  'payment': 'Bayar',
  'tenor': 'Tenor',
  'projection': 'Proyeksi',
};


/// Form penilaian satu kuartal. Urutannya mengikuti cara orang berpikir:
/// model & kuartal → pembayaran → kondisi holding → prospek.
/// Hanya dua hal yang dinilai manual; sisanya diturunkan dari fakta.
class _AssessDialog extends StatefulWidget {
  const _AssessDialog({required this.ownerId, this.existing = const []});
  final String ownerId;
  final List<Assessment> existing;

  @override
  State<_AssessDialog> createState() => _AssessDialogState();
}

class _AssessDialogState extends State<_AssessDialog> {
  late Meta _meta;
  late String _model;
  late String _quarter;
  late String _payment;
  int _tenor = 12;
  String _holdingLevel = 'Cukup';
  String _projectionLevel = 'Stabil';
  final _tenorCtl = TextEditingController(text: '12');
  final _paidCtl = TextEditingController();
  final _projCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _meta = Api.i.meta!;
    _model = _meta.models.first;
    _quarter = _meta.currentQuarter;
    _payment = _meta.paymentMethods.first;
    _prefill();
  }

  /// Kalau kuartal+model ini sudah pernah dinilai, buka form dengan nilai lama
  /// supaya pengguna mengoreksi, bukan mengisi dari nol.
  void _prefill() {
    Assessment? prev;
    for (final a in widget.existing) {
      if (a.model == _model && a.quarter == _quarter) prev = a;
    }
    if (prev == null) return;
    _payment = prev.paymentMethod;
    _tenor = prev.paymentTenor;
    _tenorCtl.text = '${prev.paymentTenor}';
    _paidCtl.text = prev.paidAmount == 0 ? '' : prev.paidAmount.toStringAsFixed(0);
    _projCtl.text = prev.projectionValue == 0 ? '' : prev.projectionValue.toStringAsFixed(0);
    _notesCtl.text = prev.projectionNotes ?? '';
    _holdingLevel = levelFor('holding', prev.scores['holding'] ?? 60).label;
    _projectionLevel = levelFor('projection', prev.scores['projection'] ?? 60).label;
  }

  @override
  void dispose() {
    _tenorCtl.dispose();
    _paidCtl.dispose();
    _projCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  /// 8 kuartal terakhir, terbaru dulu.
  List<String> get _quarters {
    final parts = _meta.currentQuarter.split('-Q');
    var year = int.parse(parts[0]);
    var q = int.parse(parts[1]);
    return [
      for (var i = 0; i < 8; i++)
        () {
          final label = '$year-Q$q';
          q--;
          if (q == 0) {
            q = 4;
            year--;
          }
          return label;
        }(),
    ];
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  Map<String, double> get _scores => {
        'holding': _levelScore('holding', _holdingLevel),
        'payment': paymentScore(_payment),
        'tenor': tenorScore(_tenor),
        'projection': _levelScore('projection', _projectionLevel),
      };

  double _levelScore(String key, String label) =>
      criteria.firstWhere((c) => c.key == key).levels.firstWhere((l) => l.label == label).score;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Api.i.saveAssessment(
        widget.ownerId,
        quarter: _quarter,
        model: _model,
        paymentMethod: _payment,
        paymentTenor: _tenor,
        paidAmount: _num(_paidCtl),
        projectionValue: _num(_projCtl),
        projectionNotes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
        scores: _scores,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final preview = _meta.score(_model, _scores);
    return ShadDialog(
      title: const Text('Nilai owner'),
      description: const Text('Pilih kondisi yang paling mendekati. Total dihitung otomatis.'),
      constraints: const BoxConstraints(maxWidth: 560),
      child: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Notice(message: _error!, icon: Icons.error_outline),
                const SizedBox(height: 12),
              ],

              // ---- 1. konteks ----
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Model'),
                        ShadSelect<String>(
                          initialValue: _model,
                          selectedOptionBuilder: (_, v) => Text(modelLabels[v] ?? v),
                          options: [
                            for (final m in _meta.models)
                              ShadOption(value: m, child: Text(modelLabels[m] ?? m)),
                          ],
                          onChanged: (v) => setState(() {
                            _model = v ?? _model;
                            _prefill();
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Kuartal'),
                        ShadSelect<String>(
                          initialValue: _quarter,
                          selectedOptionBuilder: (_, v) => Text(v),
                          options: [for (final q in _quarters) ShadOption(value: q, child: Text(q))],
                          onChanged: (v) => setState(() {
                            _quarter = v ?? _quarter;
                            _prefill();
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ---- 2. pembayaran ----
              const _Section('Pembayaran'),
              const _Label('Cara bayar'),
              ShadSelect<String>(
                initialValue: _payment,
                selectedOptionBuilder: (_, v) => Text(paymentLabels[v] ?? v),
                options: [
                  for (final p in _meta.paymentMethods)
                    ShadOption(value: p, child: Text(paymentLabels[p] ?? p)),
                ],
                onChanged: (v) => setState(() => _payment = v ?? _payment),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(paymentHint(_payment), style: theme.textTheme.small),
              ),
              const _Label('Masa pembayaran (bulan)'),
              ShadInput(
                controller: _tenorCtl,
                keyboardType: TextInputType.number,
                placeholder: const Text('12'),
                onChanged: (v) => setState(() => _tenor = int.tryParse(v) ?? 0),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Skor tenor ${tenorScore(_tenor).toStringAsFixed(0)} — makin pendek makin baik.',
                  style: theme.textTheme.small,
                ),
              ),
              const _Label('Sudah dibayar (Rp, opsional)'),
              ShadInput(
                controller: _paidCtl,
                keyboardType: TextInputType.number,
                placeholder: const Text('0'),
              ),
              const _Label('Proyeksi nilai ke depan (Rp, opsional)'),
              ShadInput(
                controller: _projCtl,
                keyboardType: TextInputType.number,
                placeholder: const Text('0'),
              ),

              // ---- 3. penilaian ----
              for (final c in criteria) ...[
                _Section(c.label),
                Text(c.question, style: theme.textTheme.small),
                const SizedBox(height: 8),
                _ChoiceGroup(
                  levels: c.levels,
                  selected: c.key == 'holding' ? _holdingLevel : _projectionLevel,
                  onChanged: (label) => setState(() {
                    if (c.key == 'holding') {
                      _holdingLevel = label;
                    } else {
                      _projectionLevel = label;
                    }
                  }),
                ),
              ],

              const _Label('Catatan (opsional)'),
              ShadInput(controller: _notesCtl, placeholder: const Text('alasan singkat, mis. lokasi strategis')),

              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Total', style: theme.textTheme.large),
                  const Spacer(),
                  Text(preview.total.toStringAsFixed(2), style: theme.textTheme.h2),
                  const SizedBox(width: 8),
                  GradeBadge(grade: preview.grade),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Bobot: ${_meta.weights[_model]!.entries.map((e) => '${scoreLabels[e.key]} ${(e.value * 100).round()}%').join(' · ')}',
                style: theme.textTheme.small,
              ),
            ],
          ),
        ),
      ),
      actions: [
        ShadButton.outline(
          child: const Text('Batal'),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        ShadButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
        ),
      ],
    );
  }
}

/// Pilihan berlabel untuk satu kriteria. Satu baris per level, skor di kanan.
class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({required this.levels, required this.selected, required this.onChanged});

  final List<Level> levels;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      children: [
        for (final l in levels)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => onChanged(l.label),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: l.label == selected ? theme.colorScheme.primary : theme.colorScheme.border,
                    width: l.label == selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      l.label == selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 16,
                      color: l.label == selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.label, style: theme.textTheme.p),
                          Text(l.hint, style: theme.textTheme.small),
                        ],
                      ),
                    ),
                    Text(l.score.toStringAsFixed(0), style: theme.textTheme.small),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 2),
        child: Text(text, style: ShadTheme.of(context).textTheme.large),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text, style: ShadTheme.of(context).textTheme.small),
      );
}
