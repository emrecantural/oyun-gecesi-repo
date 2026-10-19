import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/kelime_zinciri/zincir_mantik.dart';

ZincirOyunu yeni({int can = 1, int n = 3}) => ZincirOyunu(
      oyuncuIdleri: List.generate(n, (i) => i + 1),
      baslangicMs: 10000,
      azalmaMs: 500,
      minMs: 3000,
      can: can,
      ilkHarf: 'K',
    );

void main() {
  test('harf normalleştirme', () {
    expect(zincirHarfNorm('i'), 'İ');
    expect(zincirHarfNorm('ı'), 'I');
    expect(zincirHarfNorm('â'), 'A');
    expect(zincirHarfNorm('î'), 'İ');
    expect(zincirHarfNorm('û'), 'U');
  });

  test('sıra, çevrim ve süre azalması', () {
    final o = yeni();
    expect(o.limitMs, 10000);
    o.kabul('m', kalanMs: 5000);
    o.kabul('t', kalanMs: 5000);
    expect(o.cevrim, 0);
    o.kabul('a', kalanMs: 5000);
    expect(o.cevrim, 1);
    expect(o.aktifId, 1);
    expect(o.limitMs, 9500);
    expect(o.need, 'A');
    expect(o.zincir.length, 3);
  });

  test('süre en az minimum', () {
    final o = yeni();
    o.cevrim = 100;
    expect(o.limitMs, 3000);
  });

  test('ğ ile biten serbest harf yapar', () {
    final o = yeni();
    o.kabul('ğ', kalanMs: 5000);
    expect(o.need, isNull);
  });

  test('tek hata: elenir, harf korunur, son kalan kazanır', () {
    final o = yeni();
    o.kabul('m', kalanMs: 5000); // 1 → sıra 2
    expect(o.aktifId, 2);
    expect(o.hata(), isTrue);
    expect(o.sira, [1, 3]);
    expect(o.need, 'M');
    expect(o.aktifId, 3);
    expect(o.elenenler.single.id, 2);
    expect(o.elenenler.single.kelimeNo, 2);
    expect(o.hata(), isTrue);
    expect(o.bitti, isTrue);
    expect(o.kazanan, 1);
  });

  test('3 can', () {
    final o = yeni(can: 3, n: 2);
    expect(o.hata(), isFalse);
    expect(o.canOf(1), 2);
    o.hata(); // oyuncu 2
    o.hata(); // 1: can 1
    o.hata(); // 2: can 1
    expect(o.hata(), isTrue); // 1 elendi
    expect(o.bitti, isTrue);
  });

  test('oy kuralı ve rozetler', () {
    expect(ZincirOyunu.oyGecerli(2, 1), isTrue);
    expect(ZincirOyunu.oyGecerli(1, 1), isTrue);
    expect(ZincirOyunu.oyGecerli(0, 0), isTrue);
    expect(ZincirOyunu.oyGecerli(1, 2), isFalse);
    final o = yeni();
    o.kabul('a', kalanMs: 2000);
    o.kabul('b', kalanMs: 8000);
    o.kabul('c', kalanMs: 8000);
    o.kabul('d', kalanMs: 8000);
    expect(o.kelimeHazinesi(), 1);
    expect(o.sonNefesRozeti(), 1);
  });

  test('ilk harf: ağırlıklı, ğ asla, azı dışarıda', () {
    final liste = ['aslan', 'arı', 'ayı', 'kedi', 'kuş', 'kaz', 'ğ-test', 'zebra'];
    for (var i = 0; i < 50; i++) {
      final h = ZincirOyunu.ilkHarfSec(liste, i);
      expect(['A', 'K'].contains(h), isTrue);
    }
  });
}
