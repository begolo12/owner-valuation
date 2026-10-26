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
  Criterion('holding', 'Kredibilitas owner',
      'Siapa yang akan menerima barang dan menandatangani PO?', [
    Level(100, 'BUMN / korporasi besar', 'PO resmi, termin jelas, ada jaminan pembayaran'),
    Level(80, 'Developer mapan', 'Proyek berjalan, riwayat bayar ke supplier lancar'),
    Level(60, 'Kontraktor menengah', 'Kredibel, tapi bergantung arus kas proyek'),
    Level(40, 'Kontraktor kecil', 'Kas tipis, pembayaran sering menunggu owner'),
    Level(20, 'Owner perorangan', 'Tanpa badan usaha, sulit ditagih'),
  ]),
  Criterion('projection', 'Prospek proyek', 'Bagaimana kelanjutan proyek ini ke depan?', [
    Level(100, 'Multi-tahap, dana siap', 'Tahap berikutnya sudah kontrak, anggaran tersedia'),
    Level(80, 'Berjalan lancar', 'Progres fisik sesuai jadwal, kebutuhan material lanjut'),
    Level(60, 'Sesuai rencana', 'Tidak ada percepatan, tapi tidak ada tanda stop'),
    Level(40, 'Melambat', 'Progres seret, pembelian material menurun'),
    Level(20, 'Berisiko stop', 'Pekerjaan berhenti atau dana belum jelas'),
  ]),
];

/// Skor cara pembayaran. Diturunkan dari pilihan, tidak diisi manual.
/// Harus sama dengan PAYMENT_SCORES di server/score.js.
double paymentScore(String method) => switch (method) {
      'cash' => 100,
      'scf' => 90,
      'lc' => 85,
      'top' => 60,
      'termin' => 45,
      'retention' => 30,
      _ => 30,
    };

String paymentHint(String method) => switch (method) {
      'cash' => 'Dibayar sebelum barang dikirim — risiko paling kecil',
      'scf' => 'Supply Chain Financing — bank/fintech melunasi tagihan',
      'lc' => 'Letter of Credit / SBLC — dijamin bank penerbit',
      'top' => 'Open account — supplier menalangi dulu, ditagih belakangan',
      'termin' => 'Tagihan mengikuti progres pekerjaan',
      'retention' => 'Termin dengan retensi 5–10% ditahan sampai PHO',
      _ => 'Skema lain / belum pasti',
    };

/// Skor tenor (HARI): makin pendek makin baik.
/// Harus sama dengan tenorScore di server/score.js.
double tenorScore(int days) {
  if (days <= 14) return 100;
  if (days <= 30) return 85;
  if (days <= 60) return 65;
  if (days <= 90) return 45;
  return 25;
}

/// Level terdekat dengan skor tersimpan, untuk prefill saat menilai ulang.
Level levelFor(String key, double score) {
  final levels = criteria.firstWhere((c) => c.key == key).levels;
  return levels.reduce((a, b) => (a.score - score).abs() <= (b.score - score).abs() ? a : b);
}
