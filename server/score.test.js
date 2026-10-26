import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  MODELS,
  PAYMENT_METHODS,
  WEIGHTS,
  computeScore,
  currentQuarter,
  gradeOf,
  paymentScore,
  tenorScore,
} from './score.js';

test('bobot tiap model berjumlah 1', () => {
  for (const m of MODELS) {
    const sum = Object.values(WEIGHTS[m]).reduce((a, b) => a + b, 0);
    assert.ok(Math.abs(sum - 1) < 1e-9, `${m} = ${sum}`);
  }
});

test('ambang grade', () => {
  assert.equal(gradeOf(85), 'A');
  assert.equal(gradeOf(84.99), 'B');
  assert.equal(gradeOf(70), 'B');
  assert.equal(gradeOf(55), 'C');
  assert.equal(gradeOf(40), 'D');
  assert.equal(gradeOf(39.99), 'E');
});

test('market_baru: 80/60/40/100 -> 76 B', () => {
  const r = computeScore('market_baru', { holding: 80, payment: 60, tenor: 40, projection: 100 });
  assert.equal(r.total, 76);
  assert.equal(r.grade, 'B');
});

test('market_existing: 90/90/80/70 -> 85 A', () => {
  const r = computeScore('market_existing', { holding: 90, payment: 90, tenor: 80, projection: 70 });
  assert.equal(r.total, 85);
  assert.equal(r.grade, 'A');
});

test('skor skema bayar konstruksi turun sesuai risiko', () => {
  const scores = PAYMENT_METHODS.map(paymentScore);
  for (let i = 1; i < scores.length; i++) {
    assert.ok(scores[i] <= scores[i - 1], `${PAYMENT_METHODS[i]} harus <= ${PAYMENT_METHODS[i - 1]}`);
  }
  assert.equal(paymentScore('cash'), 100);
  assert.equal(paymentScore('retention'), 30);
});

test('skor tenor turun saat TOP memanjang', () => {
  assert.equal(tenorScore(14), 100);
  assert.equal(tenorScore(30), 85);
  assert.equal(tenorScore(60), 65);
  assert.equal(tenorScore(90), 45);
  assert.equal(tenorScore(120), 25);
});

test('skema bayar tak dikenal ditolak', () => {
  assert.throws(() => paymentScore('kpr'));
  assert.throws(() => paymentScore('installment'));
});

test('kuartal berformat YYYY-Qn', () => {
  assert.match(currentQuarter(new Date('2026-10-26T00:00:00Z')), /^2026-Q4$/);
  assert.match(currentQuarter(new Date('2026-01-01T00:00:00Z')), /^2026-Q1$/);
});
