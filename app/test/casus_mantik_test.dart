import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/kim_casus/casus_mantik.dart';

List<Mekan> _mekanlar([int n = 5]) => [
      for (var i = 0; i < n; i++)
        Mekan(
          id: 'm$i',
          ad: 'Mekan$i',
          kategori: 'kamu',
          roller: ['a$i', 'b$i', 'c$i', 'd$i', 'e$i', 'f$i'],
          ipuclari: ['i$i'],
        ),
    ];

const _ayar = CasusAyar(
  sureMs: 480000,
  turSayisi: 3,
  rolKartlari: true,
  kategoriIpucu: false,
  kura: false,
);

CasusOyunu _oyun(int n, {int seed = 1, int mekan = 5, CasusAyar ayar = _ayar}) {
  final o = CasusOyunu(
    oyuncuSayisi: n,
    mekanlar: _mekanlar(mekan),
    ayar: ayar,
    rastgele: Random(seed),
  );
  o.turBaslat();
  o.rolDagitimiBitti();
  return o;
}

int _masum(CasusOyunu o) => (o.casusIdx + 1) % o.oyuncuSayisi;

void main() {
  test('casus kartında mekân bilgisi yok, masumda var', () {
    final o = _oyun(5);
    final c = o.kartiGor(o.casusIdx);
    expect(c.casus, isTrue);
    expect(c.mekan, isNull);
    expect(c.rol, isNull);
    expect(c.ipucu, isNull);
    final m = o.kartiGor(_masum(o));
    expect(m.mekan, o.mekan.ad);
    expect(m.rol, isNotNull);
  });

  test('3 kişide kategori ipucu otomatik açık', () {
    final o = _oyun(3);
    expect(o.kartiGor(o.casusIdx).kategori, 'kamu');
    final p = _oyun(5);
    expect(p.kartiGor(p.casusIdx).kategori, isNull);
  });

  test('12 oyuncuda roller tekrar edebilir ama atanır', () {
    final o = _oyun(12);
    for (var i = 0; i < 12; i++) {
      if (i == o.casusIdx) continue;
      expect(o.kartiGor(i).rol, isNotEmpty);
    }
  });

  test('casus dağılımı eşit (1000 tur, ±%3 + tolerans)', () {
    final sayim = List.filled(8, 0);
    final o = CasusOyunu(
        oyuncuSayisi: 8, mekanlar: _mekanlar(), ayar: _ayar, rastgele: Random(5));
    for (var i = 0; i < 4000; i++) {
      o.turBaslat();
      sayim[o.casusIdx]++;
    }
    for (final s in sayim) {
      expect((s / 4000 - 1 / 8).abs() < 0.03, isTrue);
    }
  });

  test('aynı mekân art arda gelmez (100 tur)', () {
    final o = CasusOyunu(
        oyuncuSayisi: 4, mekanlar: _mekanlar(3), ayar: _ayar, rastgele: Random(9));
    String? onceki;
    for (var i = 0; i < 100; i++) {
      o.turBaslat();
      expect(o.mekan.id, isNot(onceki));
      onceki = o.mekan.id;
    }
  });

  test('soran–cevaplayan karşılıklı yasak', () {
    final o = _oyun(5);
    final a = o.soranIdx;
    final b = (a + 1) % 5;
    o.sor(b);
    expect(() => o.sor(a), throwsA(isA<CasusHata>()));
    final c = (b + 1) % 5 == a ? (b + 2) % 5 : (b + 1) % 5;
    o.sor(c);
    expect(o.soranIdx, c);
  });

  test('suçlama hakkı tur başına bir kez', () {
    final o = _oyun(5);
    o.suclaBaslat(0, 1);
    // herkes hayır → geri döner
    for (final v in o.oyVerecekler) {
      o.suclamaOyu(v, false);
    }
    expect(o.asama, CasusAsama.soruCevap);
    expect(() => o.suclaBaslat(0, 2), throwsA(isA<CasusHata>()));
    o.suclaBaslat(1, 2);
  });

  test('oybirliği + casus: tahmin; doğru bilirse casus +1', () {
    final o = _oyun(5);
    final by = _masum(o);
    o.suclaBaslat(by, o.casusIdx);
    for (final v in o.oyVerecekler) {
      o.suclamaOyu(v, true);
    }
    expect(o.asama, CasusAsama.tahmin);
    final dogru = o.mekanlar.indexWhere((m) => m.id == o.mekan.id);
    o.tahminEt(dogru);
    expect(o.sonuc, TurSonucu.yakalandiMekanDogru);
    expect(o.puanlar[o.casusIdx], 1);
    expect(o.puanlar.reduce((a, b) => a + b), 1);
  });

  test('yakalandı ama yanlış: masumlar +1, suçlayan +1 ekstra', () {
    final o = _oyun(5);
    final by = _masum(o);
    o.suclaBaslat(by, o.casusIdx);
    for (final v in o.oyVerecekler) {
      o.suclamaOyu(v, true);
    }
    final yanlis = o.mekanlar.indexWhere((m) => m.id != o.mekan.id);
    o.tahminEt(yanlis);
    expect(o.sonuc, TurSonucu.yakalandiMekanYanlis);
    expect(o.puanlar[o.casusIdx], 0);
    expect(o.puanlar[by], 2);
    for (var i = 0; i < 5; i++) {
      if (i != o.casusIdx && i != by) expect(o.puanlar[i], 1);
    }
    expect(o.enIyiDedektif, by);
  });

  test('oybirliği masuma: yanlış suçlama, casus +2', () {
    final o = _oyun(5);
    final by = _masum(o);
    final masum = (by + 1) % 5 == o.casusIdx ? (by + 2) % 5 : (by + 1) % 5;
    o.suclaBaslat(by, masum);
    for (final v in o.oyVerecekler) {
      o.suclamaOyu(v, true);
    }
    expect(o.asama, CasusAsama.reveal);
    expect(o.sonuc, TurSonucu.casusYakalanmadi);
    expect(o.puanlar[o.casusIdx], 2);
  });

  test('4 evet 1 hayır → düşer; 3 evet 1 hayır → düşer', () {
    final o = _oyun(5);
    o.suclaBaslat(0, 1);
    final v = o.oyVerecekler;
    for (var i = 0; i < v.length; i++) {
      o.suclamaOyu(v[i], i != 0);
    }
    expect(o.asama, CasusAsama.soruCevap);
  });

  test('mekânı biliyorum: casus değilse gizli yanıt, oyun etkilenmez', () {
    final o = _oyun(5);
    expect(o.casusIddiasi(_masum(o)), isFalse);
    expect(o.asama, CasusAsama.soruCevap);
    expect(o.casusIddiasi(o.casusIdx), isTrue);
    expect(o.asama, CasusAsama.tahmin);
    final dogru = o.mekanlar.indexWhere((m) => m.id == o.mekan.id);
    o.tahminEt(dogru);
    expect(o.sonuc, TurSonucu.iddiaDogru);
    expect(o.puanlar[o.casusIdx], 2);
  });

  test('iddia yanlış: masumlar +1', () {
    final o = _oyun(4);
    o.casusIddiasi(o.casusIdx);
    o.tahminEt(o.mekanlar.indexWhere((m) => m.id != o.mekan.id));
    expect(o.sonuc, TurSonucu.iddiaYanlis);
    expect(o.puanlar.where((p) => p == 1).length, 3);
  });

  test('süre bitti açık oylama: eşitlikte casus kazanır', () {
    final o = _oyun(4);
    o.sureBitti();
    // 0→1, 1→0, 2→3, 3→2: dört kişi birer oy alır (eşit)
    o.aciOy(0, 1);
    o.aciOy(1, 0);
    o.aciOy(2, 3);
    o.aciOy(3, 2);
    expect(o.sonuc, TurSonucu.casusYakalanmadi);
    expect(o.puanlar[o.casusIdx], 2);
  });

  test('süre bitti açık oylama: çoğunluk casus → tahmin', () {
    final o = _oyun(4);
    o.sureBitti();
    final c = o.casusIdx;
    for (var v = 0; v < 4; v++) {
      o.aciOy(v, v == c ? (c + 1) % 4 : c);
    }
    expect(o.asama, CasusAsama.tahmin);
    expect(o.tahminBaglami, TahminBaglami.yakalandi);
  });

  test('tahmin süresi dolunca yanlış sayılır', () {
    final o = _oyun(4);
    o.casusIddiasi(o.casusIdx);
    o.tahminSuresiBitti();
    expect(o.sonuc, TurSonucu.iddiaYanlis);
  });

  test('tur sayısı dolunca final', () {
    final o = _oyun(4, ayar: const CasusAyar(
      sureMs: 1, turSayisi: 1, rolKartlari: true, kategoriIpucu: false, kura: false));
    o.casusIddiasi(o.casusIdx);
    o.tahminSuresiBitti();
    o.sonrakiTurVeyaFinal();
    expect(o.asama, CasusAsama.bitti);
  });

  test('kura: geri soru olmadan rastgele sıradaki', () {
    final o = _oyun(5);
    for (var i = 0; i < 20; i++) {
      final onceki = o.soranIdx;
      final yeni = o.kuraSoran();
      expect(yeni, isNot(onceki));
    }
  });
}
