import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Aksen "oil": amber hangat di atas dasar stone gelap/terang.
const _oil = Color(0xFFE0A458);

ShadThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = dark ? const ShadStoneColorScheme.dark() : const ShadStoneColorScheme.light();
  final scheme = base.copyWith(
    primary: dark ? _oil : const Color(0xFF2B2118),
    primaryForeground: dark ? const Color(0xFF1A140E) : const Color(0xFFFBF7F0),
    ring: _oil,
    accent: dark ? const Color(0xFF2A2118) : const Color(0xFFF6EFE4),
    accentForeground: dark ? const Color(0xFFF5E9D7) : const Color(0xFF2B2118),
    border: dark ? const Color(0xFF2C2721) : const Color(0xFFE8E0D3),
    input: dark ? const Color(0xFF2C2721) : const Color(0xFFE8E0D3),
  );

  return ShadThemeData(
    brightness: brightness,
    colorScheme: scheme,
    radius: const BorderRadius.all(Radius.circular(14)),
    cardTheme: ShadCardTheme(
      padding: const EdgeInsets.all(20),
      radius: const BorderRadius.all(Radius.circular(18)),
      border: ShadBorder.all(color: scheme.border),
    ),
  );
}

/// Warna badge per grade.
Color gradeColor(String grade) => switch (grade) {
      'A' => const Color(0xFF3F9B6B),
      'B' => const Color(0xFF5B8DEF),
      'C' => const Color(0xFFE0A458),
      'D' => const Color(0xFFD97642),
      _ => const Color(0xFFD9534F),
    };

const modelLabels = {
  'market_baru': 'Market Baru',
  'market_existing': 'Market Existing',
};

const paymentLabels = {
  'cash': 'Cash',
  'scf': 'SCF',
  'lc': 'LC / SBLC',
  'top': 'TOP (open account)',
  'termin': 'Termin progres',
  'retention': 'Termin + retensi',
};

String rupiah(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}
