import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'theme.dart';

/// Badge grade A–E.
class GradeBadge extends StatelessWidget {
  const GradeBadge({super.key, required this.grade, this.total, this.compact = false});

  final String grade;
  final double? total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(grade);
    return ShadBadge(
      backgroundColor: color.withValues(alpha: 0.16),
      foregroundColor: color,
      child: Text(
        compact || total == null
            ? grade
            : '$grade  ·  ${total!.toStringAsFixed(1)}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// Header halaman dengan judul + aksi.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.h2),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: theme.textTheme.muted),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Kartu statistik ringkas.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.muted),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.h2),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: theme.textTheme.small),
          ],
        ],
      ),
    );
  }
}

/// Kotak pesan error/kosong.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.message, this.icon = Icons.info_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.mutedForeground),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: theme.textTheme.muted)),
        ],
      ),
    );
  }
}

/// Dialog input teks sederhana (nama, catatan, dst).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? description,
  String? hint,
  String? initial,
  String confirm = 'Simpan',
}) {
  final controller = TextEditingController(text: initial);
  return showShadDialog<String>(
    context: context,
    builder: (ctx) => ShadDialog(
      title: Text(title),
      description: description == null ? null : Text(description),
      child: ShadInput(controller: controller, placeholder: Text(hint ?? ''), autofocus: true),
      actions: [
        ShadButton.outline(child: const Text('Batal'), onPressed: () => Navigator.pop(ctx)),
        ShadButton(
          child: Text(confirm),
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
        ),
      ],
    ),
  );
}

/// Format tanggal singkat Indonesia.
String tanggal(DateTime d) {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${d.day} ${bulan[d.month - 1]} ${d.year}';
}
