import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/geri_sayimi_yakala/gys_mantik.dart';

void main() {
  test('örnek tur: 5/3/2/1/0', () {
    final r = turPuanla(sapmalar: {1: 12, 2: 50, 3: -130, 4: 300, 5: null});
    final puan = {for (final s in r) s.oyuncuId: s.puan};
    expect(puan, {1: 5, 2: 3, 3: 2, 4: 1, 5: 0});
    expect(r.firstWhere((s) => s.oyuncuId == 5).uyudu, isTrue);
  });

  test('beraberlik: eşik içindekiler aynı puan, sıradaki sırayı atlar', () {
    final r = turPuanla(sapmalar: {1: 10, 2: 14, 3: 200, 4: 400}, esikMs: 16);
    final puan = {for (final s in r) s.oyuncuId: s.puan};
    expect(puan[1], 5);
    expect(puan[2], 5);
    expect(puan[3], 2); // 3. sıra (iki kişi 1.'de)
    expect(puan[4], 1);
  });

  test('erken ve geç mutlak değerle karşılaştırılır', () {
    final r = turPuanla(sapmalar: {1: -20, 2: 30});
    expect(r.firstWhere((s) => s.oyuncuId == 1).sira, 1);
  });

  test('eşik: 8 ms örnekleme → 16, 17 ms → 34, en az 5', () {
    expect(beraberlikEsigi(8), 16);
    expect(beraberlikEsigi(17), 34);
    expect(beraberlikEsigi(1), 5);
  });

  test('kimse dokunmadı: herkes 0', () {
    final r = turPuanla(sapmalar: {1: null, 2: null});
    expect(r.every((s) => s.puan == 0), isTrue);
  });

  test('toplam puan ve rozetler', () {
    final o = GysOyunu(oyuncuIdleri: [1, 2], turSayisi: 2);
    o.turBitir({1: 10, 2: -300});
    o.turBitir({1: 20, 2: 50});
    expect(o.bitti, isTrue);
    expect(o.siralama.first.oyuncuId, 1);
    expect(o.zamanUstasi, 1);
    expect(o.kusGibi, 2);
  });

  test('zaman ustası: en az yarı tur dokunmayan aday değil', () {
    final o = GysOyunu(oyuncuIdleri: [1, 2], turSayisi: 3);
    o.turBitir({1: 1, 2: null});
    o.turBitir({1: null, 2: 100});
    o.turBitir({1: null, 2: 100});
    expect(o.zamanUstasi, 2);
  });
}
