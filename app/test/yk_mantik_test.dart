import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/yasak_kelime/yk_mantik.dart';

void main() {
  YasakOyunu yeni({int n = 6, int takim = 2, int tur = 2, int pas = 3}) =>
      YasakOyunu(
        oyuncuIdleri: List.generate(n, (i) => i + 1),
        takimSayisi: takim,
        turPerTakim: tur,
        pasHakki: pas,
      );

  test('takım ataması ve en az 2 kişi kuralı', () {
    final o = yeni(n: 6, takim: 2);
    expect(o.takimlar, [[1, 3, 5], [2, 4, 6]]);
    final p = yeni(n: 5, takim: 4); // 5 kişi 4 takıma yetmez → 2 takım
    expect(p.takimSayisi, 2);
    final q = yeni(n: 8, takim: 4);
    expect(q.takimSayisi, 4);
    expect(q.takimlar.every((t) => t.length >= 2), isTrue);
  });

  test('sıra dönüşümlü, anlatıcı ve hakem rotasyonu', () {
    final o = yeni(n: 6, takim: 2, tur: 2);
    expect(o.toplamTur, 4);
    final t1 = o.turBaslat();
    expect(t1.takim, 0);
    expect(t1.anlaticiId, 1);
    expect(t1.hakemId, 2);
    o.turuBitir();
    final t2 = o.turBaslat();
    expect(t2.takim, 1);
    expect(t2.anlaticiId, 2);
    expect(t2.hakemId, 1); // takım 0'dan sıradaki
    o.turuBitir();
    final t3 = o.turBaslat();
    expect(t3.anlaticiId, 3);
    expect(t3.hakemId, 4);
  });

  test('puan: doğru +1, ihlal ve pas 0; geri al', () {
    final o = yeni();
    o.turBaslat();
    o.kartGoster('a', 0);
    expect(o.isaretle(YkSonuc.dogru, 'a', 'Çay', 5000), isTrue);
    o.kartGoster('b', 5000);
    expect(o.isaretle(YkSonuc.pas, 'b', 'X', 6000), isTrue);
    expect(o.pasKalan, 2);
    expect(o.geriAl(), isTrue);
    expect(o.pasKalan, 3);
    expect(o.geriAl(), isFalse); // tek seviye
    o.kartGoster('c', 6000);
    expect(o.isaretle(YkSonuc.ihlal, 'c', 'Y', 6100), isFalse); // 800 ms kilidi
    expect(o.isaretle(YkSonuc.ihlal, 'c', 'Y', 7000), isTrue);
    final t = o.turuBitir();
    expect(t.dogru, 1);
    expect(t.ihlal, 1);
    expect(t.puan, 1);
    expect(o.skor[0], 1);
  });

  test('pas hakkı bitince hata; sınırsızda yok', () {
    final o = yeni(pas: 1);
    o.turBaslat();
    o.kartGoster('a', 0);
    o.isaretle(YkSonuc.pas, 'a', 'x', 1000);
    o.kartGoster('b', 1000);
    expect(() => o.isaretle(YkSonuc.pas, 'b', 'y', 2000), throwsStateError);
    final s = yeni(pas: 0);
    s.turBaslat();
    s.kartGoster('a', 0);
    for (var i = 0; i < 5; i++) {
      s.kartGoster('k$i', i * 1000);
      expect(s.isaretle(YkSonuc.pas, 'k$i', 'x', i * 1000 + 900), isTrue);
    }
    expect(s.pasVar, isTrue);
  });

  test('bitiş ve kazananlar', () {
    final o = yeni(tur: 1);
    for (var i = 0; i < 2; i++) {
      o.turBaslat();
      o.kartGoster('a', 0);
      o.isaretle(YkSonuc.dogru, 'a', 'x', 1000);
      o.turuBitir();
    }
    expect(o.bitti, isTrue);
    expect(o.kazananlar(), [0, 1]);
  });
}
