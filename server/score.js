export const MODELS = ['market_baru', 'market_existing'];
export const QUARTER_RE = /^\d{4}-Q[1-4]$/;

// Bobot tiap model. Jumlah per model = 1.
// market_baru menekankan proyeksi, market_existing menekankan rekam jejak owner + skema bayar.
export const WEIGHTS = {
  market_baru: { holding: 0.25, payment: 0.25, tenor: 0.15, projection: 0.35 },
  market_existing: { holding: 0.35, payment: 0.3, tenor: 0.2, projection: 0.15 },
};

// Skema pembayaran yang lazim di supplier konstruksi.
// Urut dari risiko paling kecil ke paling besar.
export const PAYMENT_METHODS = ['cash', 'scf', 'lc', 'top', 'termin', 'retention'];

// Skor diturunkan dari skema, bukan diisi manual. Semakin cepat uang masuk
// dan semakin kecil eksposur ke owner, semakin tinggi.
export const PAYMENT_SCORES = {
  cash: 100, // CBD - dibayar sebelum kirim
  scf: 90, // Supply Chain Financing - bank/fintech melunasi, risiko pindah ke bank
  lc: 85, // LC / SBLC - dijamin bank, ada biaya & dokumen
  top: 60, // TOP / open account - kita menalangi
  termin: 45, // progress billing - bayar mengikuti progres
  retention: 30, // termin + retensi 5-10% ditahan sampai PHO
};

export function paymentScore(method) {
  const score = PAYMENT_SCORES[method];
  if (score === undefined) throw new Error(`skema bayar tidak dikenal: ${method}`);
  return score;
}

// Term of payment dalam HARI. Semakin pendek semakin baik.
export function tenorScore(days) {
  if (days <= 14) return 100;
  if (days <= 30) return 85;
  if (days <= 60) return 65;
  if (days <= 90) return 45;
  return 25;
}

export function gradeOf(total) {
  if (total >= 85) return 'A';
  if (total >= 70) return 'B';
  if (total >= 55) return 'C';
  if (total >= 40) return 'D';
  return 'E';
}

export function computeScore(model, { holding, payment, tenor, projection }) {
  const w = WEIGHTS[model];
  if (!w) throw new Error(`model tidak dikenal: ${model}`);
  const raw =
    holding * w.holding + payment * w.payment + tenor * w.tenor + projection * w.projection;
  const total = Math.round(raw * 100) / 100;
  return { total, grade: gradeOf(total) };
}

export function currentQuarter(d = new Date()) {
  return `${d.getUTCFullYear()}-Q${Math.floor(d.getUTCMonth() / 3) + 1}`;
}
