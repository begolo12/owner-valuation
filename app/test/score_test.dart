import 'package:flutter_test/flutter_test.dart';
import 'package:owner_valuation/api.dart';

void main() {
  test('pratinjau skor klien sama dengan bobot server', () {
    final meta = Meta(
      models: const ['market_baru', 'market_existing'],
      weights: const {
        'market_baru': {'holding': 0.25, 'payment': 0.25, 'tenor': 0.15, 'projection': 0.35},
        'market_existing': {'holding': 0.35, 'payment': 0.30, 'tenor': 0.20, 'projection': 0.15},
      },
      paymentMethods: const ['cash'],
      currentQuarter: '2026-Q4',
    );
    const s = {'holding': 80.0, 'payment': 60.0, 'tenor': 40.0, 'projection': 100.0};
    expect(meta.score('market_baru', s).total, 76);
    expect(meta.score('market_baru', s).grade, 'B');
    expect(meta.score('market_existing', s).total, 69);
    expect(meta.score('market_existing', s).grade, 'C');
  });
}
