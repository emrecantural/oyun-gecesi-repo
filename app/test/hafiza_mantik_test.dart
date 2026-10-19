import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/hafiza_duellosu/hafiza_mantik.dart';

/// 1,1,2,2,... dizilimi: kart 2k ve 2k+1 eşleşir.
HafizaOyunu oyun(List<int> idler, {int cift = 8, bool bonus = true}) =>
    HafizaOyunu(
      oyuncuIdleri: idler,
      dizilim: [for (var i = 0; i < cift; i++) ...[i, i]],
      seriBonus: bonus,
    );

void eslestir(HafizaOyunu o, int k) {
  o.ac(2 * k);
  expect(o.ac(2 * k + 1), HamleSonucu.eslesti);
}

void main() {
  test('seri puanı: 2,2,1 serileri = 6; tek seri 3 = 4,5', () {
    final o = oyun([1, 2], cift: 8);
    // Ayşe (1): 2 çift, kaçır, 2 çift, kaçır, 1 çift
    eslestir(o, 0);
    eslestir(o, 1);
    o.ac(4);
    expect(o.ac(6), HamleSonucu.uyusmadi);
    o.kapat(); // sıra Bora
    o.ac(4);
    expect(o.ac(6), HamleSonucu.uyusmadi);
    o.kapat(); // sıra Ayşe
    eslestir(o, 2);
    eslestir(o, 3);
    o.ac(8);
    o.ac(10);
    o.kapat(); // Bora
    o.ac(8);
    o.ac(10);
    o.kapat(); // Ayşe
    eslestir(o, 4);
    expect(o.oyuncular[0].puan2, 2 * 6);
    expect(puanYaz(o.oyuncular[0].puan2), '6');
  });

  test('bonus kapalıysa çift başına 1; puanYaz ondalık virgül', () {
    final o = oyun([1, 2], bonus: false);
    eslestir(o, 0);
    eslestir(o, 1);
    eslestir(o, 2);
    expect(o.oyuncular[0].puan2, 6);
    expect(puanYaz(5), '2,5');
    expect(ciftPuani2(1, true), 2);
    expect(ciftPuani2(2, true), 3);
    expect(ciftPuani2(5, true), 4);
  });

  test('eşit puanda en uzun seri öne geçer', () {
    final o = oyun([1, 2, 3]);
    // Ayşe: tek tek (2,1,1)=4,5 ; Bora: seri 3 = 4,5
    o.oyuncular[0]
      ..puan2 = 9
      ..enUzunSeri = 2;
    o.oyuncular[1]
      ..puan2 = 9
      ..enUzunSeri = 3;
    o.oyuncular[2]
      ..puan2 = 2
      ..enUzunSeri = 1;
    final s = o.siralama();
    expect(s.map((e) => e.oyuncuId), [2, 1, 3]);
    expect(s.map((e) => e.sira), [1, 2, 3]);
  });

  test('tam eşitlikte sıra paylaşılır', () {
    final o = oyun([1, 2]);
    o.oyuncular[0].puan2 = 4;
    o.oyuncular[1].puan2 = 4;
    expect(o.siralama().map((e) => e.sira), [1, 1]);
  });

  test('aynı/eşleşmiş karta ve kilitliyken dokunma durumu değiştirmez', () {
    final o = oyun([1, 2]);
    expect(o.ac(0), HamleSonucu.acildi);
    expect(o.ac(0), HamleSonucu.reddedildi);
    expect(o.ac(1), HamleSonucu.eslesti);
    expect(o.ac(0), HamleSonucu.reddedildi);
    o.ac(2);
    o.ac(4);
    expect(o.kilitli, isTrue);
    expect(o.ac(6), HamleSonucu.reddedildi);
  });

  test('süre doldu: açık kart kapanır, seri sıfırlanır, sıra geçer', () {
    final o = oyun([1, 2]);
    eslestir(o, 0);
    o.ac(2);
    o.sureDoldu();
    expect(o.oyuncular[0].seri, 0);
    expect(o.oyuncular[0].hata, 1);
    expect(o.siradaki.id, 2);
    expect(o.kartlar[2].acik, isFalse);
  });

  test('son 2 kart otomatik sırası olana yazılır; 8 çift', () {
    final o = oyun([1, 2]);
    for (var k = 0; k < 7; k++) {
      eslestir(o, k);
    }
    expect(o.kalanKart, 2);
    expect(o.sonCiftiOtomatik(), isTrue);
    expect(o.bitti, isTrue);
    expect(o.oyuncular.fold<int>(0, (a, e) => a + e.cift), 8);
  });

  test('oyuncu ayrılır: sırası atlanır', () {
    final o = oyun([1, 2, 3]);
    o.ac(0);
    o.oyuncuCikar(1);
    expect(o.siradaki.id, 2);
    expect(o.acik, isEmpty);
    o.ac(2);
    o.ac(4);
    o.kapat();
    expect(o.siradaki.id, 3);
    o.ac(2);
    o.ac(4);
    o.kapat();
    expect(o.siradaki.id, 2); // 1 atlandı
  });

  test('Fil Hafızası: en az 3 hamle, en az hata, eşitlikte hepsi', () {
    final o = oyun([1, 2, 3]);
    o.oyuncular[0]
      ..hamle = 4
      ..hata = 1;
    o.oyuncular[1]
      ..hamle = 4
      ..hata = 1;
    o.oyuncular[2]
      ..hamle = 2
      ..hata = 0;
    expect(o.filHafizasi(), [1, 2]);
  });

  test('dizilim: her sembol tam iki kez, çift sayısı doğru, tekdüze', () {
    final rng = Random(7);
    final ilk = <int, int>{};
    for (var n = 0; n < 5000; n++) {
      final d = dizilimUret(8, List.generate(10, (i) => i), rng);
      expect(d.length, 16);
      final sayim = <int, int>{};
      for (final s in d) {
        sayim[s] = (sayim[s] ?? 0) + 1;
      }
      expect(sayim.values.every((v) => v == 2), isTrue);
      ilk[d[0]] = (ilk[d[0]] ?? 0) + 1;
    }
    for (final v in ilk.values) {
      expect(v, inInclusiveRange(5000 / 10 * 0.8, 5000 / 10 * 1.2));
    }
  });
}
