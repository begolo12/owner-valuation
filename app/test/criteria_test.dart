import 'package:flutter_test/flutter_test.dart';
import 'package:owner_valuation/criteria.dart';

void main() {
  test('skor cara bayar konstruksi: cash tertinggi, retensi terendah', () {
    expect(paymentScore('cash'), 100);
    expect(paymentScore('scf'), 90);
    expect(paymentScore('lc'), 85);
    expect(paymentScore('top'), 60);
    expect(paymentScore('termin'), 45);
    expect(paymentScore('retention'), 30);
  });

  test('skor tenor turun saat tenor memanjang', () {
    expect(tenorScore(7), 100);
    expect(tenorScore(30), 85);
    expect(tenorScore(45), 65);
    expect(tenorScore(90), 45);
    expect(tenorScore(180), 25);
  });

  test('levelFor memilih level terdekat untuk prefill', () {
    expect(levelFor('holding', 78).label, 'Developer mapan');
    expect(levelFor('projection', 100).label, 'Multi-tahap, dana siap');
  });

  test('semua level dalam 0..100', () {
    for (final c in criteria) {
      for (final l in c.levels) {
        expect(l.score, inInclusiveRange(0, 100));
      }
    }
  });
}
