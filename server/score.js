export const MODELS = ['market_baru', 'market_existing'];
export const QUARTER_RE = /^\d{4}-Q[1-4]$/;

// Bobot tiap model. Jumlah per model = 1.
// market_baru menekankan proyeksi, market_existing menekankan rekam jejak holding + cara bayar.
export const WEIGHTS = {
  market_baru: { holding: 0.25, payment: 0.25, tenor: 0.15, projection: 0.35 },
  market_existing: { holding: 0.35, payment: 0.3, tenor: 0.2, projection: 0.15 },
};

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
