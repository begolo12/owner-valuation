import assert from 'node:assert/strict';
import test from 'node:test';
import { WEIGHTS, computeScore, currentQuarter, gradeOf } from './score.js';

test('bobot tiap model berjumlah 1', () => {
  for (const [model, w] of Object.entries(WEIGHTS)) {
    const sum = w.holding + w.payment + w.tenor + w.projection;
    assert.ok(Math.abs(sum - 1) < 1e-9, `${model} jumlahnya ${sum}`);
  }
});

test('computeScore memakai bobot model masing-masing', () => {
  const s = { holding: 80, payment: 60, tenor: 40, projection: 100 };
  // market_baru: .25*80 + .25*60 + .15*40 + .35*100 = 76
  assert.deepEqual(computeScore('market_baru', s), { total: 76, grade: 'B' });
  // market_existing: .35*80 + .30*60 + .20*40 + .15*100 = 69
  assert.deepEqual(computeScore('market_existing', s), { total: 69, grade: 'C' });
});

test('model tak dikenal ditolak', () => {
  assert.throws(() => computeScore('market_lain', {}));
});

test('batas grade', () => {
  assert.equal(gradeOf(85), 'A');
  assert.equal(gradeOf(84.99), 'B');
  assert.equal(gradeOf(70), 'B');
  assert.equal(gradeOf(39.99), 'E');
});

test('currentQuarter', () => {
  assert.equal(currentQuarter(new Date('2026-01-15T00:00:00Z')), '2026-Q1');
  assert.equal(currentQuarter(new Date('2026-10-26T00:00:00Z')), '2026-Q4');
});
