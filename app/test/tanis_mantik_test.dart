import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/birbirimizi_taniyoruz/tanis_mantik.dart';

const _s = [
  TanisSoru('a', 'Soru A', ['1', '2', '3', '4']),
  TanisSoru('b', 'Soru B', ['1', '2', '3', '4']),
];

void main() {
  test('odak sırası ve tahminciler', () {
    final o = TanisOyunu(oyuncuIdleri: [1, 2, 3], odakTur: 2);
    expect(o.odakSirasi, [1, 2, 3, 1, 2, 3]);
    expect(o.tahminciler(2), [1, 3]);
  });

  test('puan: doğru 1, hızlı 1,5; odak puan almaz', () {
    final o = TanisOyunu(oyuncuIdleri: [1, 2, 3], odakTur: 1);
    final b = o.blokAc(1, _s);
    o.odakCevapla(b, 0, 2);
    o.odakCevapla(b, 1, null); // cevapsız
    o.tahminEt(b, 2, 0, 2, 3000);
    o.tahminEt(b, 3, 0, 1, 2000);
    final r = o.revealHesapla(b);
    expect(r.length, 1);
    expect(r.first.bilen, [2]);
    expect(r.first.bilemeyen, [3]);
    expect(o.puan[2], 1.5);
    expect(o.puan[1], isNull);
  });

  test('yavaş doğru 1,0; açık kitap ve gizemli', () {
    final o = TanisOyunu(oyuncuIdleri: [1, 2, 3], odakTur: 1);
    final b = o.blokAc(1, _s);
    o.odakCevapla(b, 0, 0);
    o.odakCevapla(b, 1, 3);
    o.tahminEt(b, 2, 0, 0, 9000);
    o.tahminEt(b, 3, 0, 0, 9000);
    o.tahminEt(b, 2, 1, 1, 100);
    o.tahminEt(b, 3, 1, 2, 100);
    final r = o.revealHesapla(b);
    expect(r[0].acikKitap, isTrue);
    expect(r[1].gizemli, isTrue);
    expect(o.puan[2], 1.0);
    expect(o.acikKitap, 1);
    expect(o.gizemli, 1);
    expect(o.enCokAcikKitap(), 1);
  });

  test('hatalar', () {
    final o = TanisOyunu(oyuncuIdleri: [1, 2], odakTur: 1);
    final b = o.blokAc(1, _s);
    expect(() => o.tahminEt(b, 1, 0, 0, 1), throwsStateError);
    o.tahminEt(b, 2, 0, 0, 1);
    expect(() => o.tahminEt(b, 2, 0, 0, 1), throwsStateError);
  });
}
