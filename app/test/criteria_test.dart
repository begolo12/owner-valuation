import 'package:flutter_test/flutter_test.dart';
import 'package:owner_valuation/criteria.dart';

void main() {
  test('skor cara bayar: cash tertinggi, other terendah', () {
    expect(paymentScore('cash'), 100);
    expect(paymentScore('kpr'), 70);
    expect(paymentScore('installment'), 50);
    expect(paymentScore('other'), 30);
  });

  test('skor tenor turun saat tenor memanjang', () {
    expect(tenorScore(3), 100);
    expect(tenorScore(12), 80);
    expect(tenorScore(24), 60);
    expect(tenorScore(36), 40);
    expect(tenorScore(60), 20);
  });

  test('levelFor memilih level terdekat untuk prefill', () {
    expect(levelFor('holding', 78).label, 'Kuat');
    expect(levelFor('projection', 100).label, 'Sangat cerah');
  });

  test('semua level dalam 0..100', () {
    for (final c in criteria) {
      for (final l in c.levels) {
        expect(l.score, inInclusiveRange(0, 100));
      }
    }
  });
}
