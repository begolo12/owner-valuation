export const modelLabels = {
  market_baru: 'Market Baru',
  market_existing: 'Market Existing',
};

// Skema bayar khas supplier konstruksi. Urut dari risiko terkecil.
export const paymentLabels = {
  cash: 'Cash / CBD',
  scf: 'SCF',
  lc: 'LC / SBLC',
  top: 'TOP',
  termin: 'Termin progres',
  retention: 'Termin + retensi',
};

export const paymentHints = {
  cash: 'Dibayar sebelum barang dikirim',
  scf: 'Supply Chain Financing — bank/fintech melunasi',
  lc: 'Letter of Credit / SBLC — dijamin bank',
  top: 'Open account — supplier menalangi',
  termin: 'Tagihan mengikuti progres pekerjaan',
  retention: 'Termin dengan retensi 5–10% ditahan sampai PHO',
};

export const scoreLabels = {
  holding: 'Owner',
  payment: 'Skema bayar',
  tenor: 'TOP',
  projection: 'Proyeksi',
};

// Dua kriteria yang dinilai manual. Skor 0-100 supaya bobot server tetap.
export const criteria = [
  {
    key: 'holding',
    label: 'Kredibilitas owner',
    question: 'Siapa yang akan menerima barang dan menandatangani PO?',
    levels: [
      { score: 100, label: 'BUMN / korporasi besar', hint: 'APBN atau neraca kuat, pembayaran terjadwal' },
      { score: 80, label: 'Developer mapan', hint: 'Beberapa proyek berjalan, riwayat lancar' },
      { score: 60, label: 'Kontraktor menengah', hint: 'Stabil, tergantung satu-dua proyek' },
      { score: 40, label: 'Kontraktor kecil', hint: 'Kas tipis, sering minta perpanjangan' },
      { score: 20, label: 'Owner perorangan', hint: 'Tanpa badan usaha, jaminan lemah' },
    ],
  },
  {
    key: 'projection',
    label: 'Prospek proyek',
    question: 'Bagaimana kelanjutan proyek ini ke depan?',
    levels: [
      { score: 100, label: 'Multi-tahap, dana siap', hint: 'Tahap berikutnya sudah terkontrak' },
      { score: 80, label: 'Berjalan lancar', hint: 'Progres sesuai jadwal, kebutuhan material rutin' },
      { score: 60, label: 'Sesuai rencana', hint: 'Normal, tanpa percepatan' },
      { score: 40, label: 'Melambat', hint: 'Progres di bawah jadwal, order menurun' },
      { score: 20, label: 'Berisiko stop', hint: 'Pendanaan belum jelas, proyek bisa berhenti' },
    ],
  },
];

export const tenorBands = [
  { max: 14, label: '≤ 14 hari', score: 100 },
  { max: 30, label: '15–30 hari', score: 85 },
  { max: 60, label: '31–60 hari', score: 65 },
  { max: 90, label: '61–90 hari', score: 45 },
  { max: 365, label: '> 90 hari', score: 25 },
];

export const gradeOf = (total) =>
  total >= 85 ? 'A' : total >= 70 ? 'B' : total >= 55 ? 'C' : total >= 40 ? 'D' : 'E';

export const rupiah = (v) =>
  new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(v || 0);

export const levelScore = (key, label) =>
  criteria.find((c) => c.key === key).levels.find((l) => l.label === label)?.score ?? 60;
