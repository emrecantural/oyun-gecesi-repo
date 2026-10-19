import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/room/oyun_koy_paket.dart';

void main() {
  test('varsayılan paket toplamı oyuncu sayısına eşit (6..20)', () {
    for (var n = 6; n <= 20; n++) {
      final p = varsayilanPaket(n);
      expect(p.values.fold<int>(0, (a, b) => a + b), n, reason: '$n');
      expect(p.values.every((v) => v >= 0), isTrue, reason: '$n');
    }
  });
}
