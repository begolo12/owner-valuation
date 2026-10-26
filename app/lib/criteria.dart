// Rubrik penilaian: pengguna memilih keadaan nyata, bukan menggeser angka
// 0-100 yang tidak jelas artinya. Skor tetap 0-100 sehingga bobot server
// dan ambang grade tidak berubah.

class Level {
  const Level(this.score, this.label, this.hint);
  final double score;
  final String label;
  final String hint;
}

class Criterion {
  const Criterion(this.key, this.label, this.question, this.levels);
  final String key;
  final String label;
  final String question;
  final List<Level> levels;
}

/// Dua kriteria yang dinilai manual.
const criteria = <Criterion>[
  Criterion('holding', 'Kekuatan holding', 'Seberapa kuat holding di belakang proyek ini?', [
    Level(100, 'Sangat kuat', 'Brand dominan, kas solid, track record bersih'),
    Level(80, 'Kuat', 'Portofolio sehat, pembayaran lancar'),
    Level(60, 'Cukup', 'Stabil, bergantung beberapa proyek'),
    Level(40, 'Lemah', 'Kas ketat, bergantung proyek baru'),
    Level(20, 'Sangat lemah', 'Ada riwayat gagal bayar atau sengketa'),
  ]),
  Criterion('projection', 'Proyeksi ke depan', 'Bagaimana prospek nilai proyek ini?', [
    Level(100, 'Sangat cerah', 'Permintaan tinggi, harga naik konsisten'),
    Level(80, 'Cerah', 'Permintaan di atas rata-rata'),
    Level(60, 'Stabil', 'Sesuai pasar'),
    Level(40, 'Menurun', 'Harga atau permintaan melemah'),
    Level(20, 'Tidak jelas', 'Pasar belum terbaca'),
  ]),
];

/// Skor cara pembayaran. Diturunkan dari pilihan, tidak diisi manual.
double paymentScore(String method) => switch (method) {
      'cash' => 100,
      'kpr' => 70,
      'installment' => 50,
      _ => 30,
    };

String paymentHint(String method) => switch (method) {
      'cash' => 'Lunas di muka — risiko paling kecil',
      'kpr' => 'Didanai bank — risiko pindah ke bank',
      'installment' => 'Dicicil ke developer — perlu pemantauan',
      _ => 'Skema lain / belum pasti',
    };

/// Skor tenor: makin pendek makin baik.
double tenorScore(int months) {
  if (months <= 6) return 100;
  if (months <= 12) return 80;
  if (months <= 24) return 60;
  if (months <= 36) return 40;
  return 20;
}

/// Level terdekat dengan skor tersimpan, untuk prefill saat menilai ulang.
Level levelFor(String key, double score) {
  final levels = criteria.firstWhere((c) => c.key == key).levels;
  return levels.reduce((a, b) => (a.score - score).abs() <= (b.score - score).abs() ? a : b);
}
