import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/dilsiz_sinema/dilsiz_mantik.dart';

DilsizOyunu yeni({int pas = 3, bool ceza = false, int tur = 1}) => DilsizOyunu(
      oyuncuIdleri: [1, 2, 3, 4],
      takimSayisi: 2,
      turPerTakim: tur,
      pasHakki: pas,
      pasCezali: ceza,
    );

void main() {
  test('sıra ve anlatıcı rotasyonu', () {
    final o = yeni(tur: 2);
    expect(o.toplamTur, 4);
    expect(o.turBaslat().anlaticiId, 1);
    o.turuBitir();
    expect(o.turBaslat().anlaticiId, 2);
    o.turuBitir();
    expect(o.turBaslat().anlaticiId, 3);
    o.turuBitir();
    expect(o.turBaslat().anlaticiId, 4);
    o.turuBitir();
    expect(o.bitti, isTrue);
  });

  test('puan: doğru, ihlal, pas cezası, yarım kalan', () {
    final o = yeni(ceza: true);
    o.turBaslat();
    o.dogru('a', 'A');
    o.dogru('b', 'B');
    o.pas('c', 'C');
    o.yarimKalan('d', 'D');
    final t = o.aktif!;
    o.ihlalIsaretle(t.ogeler[1], true);
    expect(t.dogru(), 1);
    expect(t.ihlal(), 1);
    expect(t.puan(pasCezali: true), 1 - 1 - 1);
    expect(o.ihlalIsaretle(t.ogeler[2], true), isFalse); // pas'ta ihlal olmaz
    o.turuBitir();
    expect(o.skor[0], -1);
  });

  test('düzeltme: ihlalli doğru → pas ihlali siler', () {
    final o = yeni();
    o.turBaslat();
    o.dogru('a', 'A');
    final k = o.aktif!.ogeler.first;
    o.ihlalIsaretle(k, true);
    o.duzelt(k);
    expect(k.durum, DurumOge.pas);
    expect(k.ihlal, isFalse);
    o.duzelt(k);
    expect(k.durum, DurumOge.dogru);
  });

  test('pas hakkı ve geri al', () {
    final o = yeni(pas: 1);
    o.turBaslat();
    o.pas('a', 'A');
    expect(o.pasVar, isFalse);
    expect(() => o.pas('b', 'B'), throwsStateError);
    expect(o.geriAl()?.id, 'a');
    expect(o.pasVar, isTrue);
    expect(o.geriAl(), isNull);
    final s = yeni(pas: -1);
    s.turBaslat();
    for (var i = 0; i < 10; i++) {
      s.pas('$i', 'x');
    }
    expect(s.pasVar, isTrue);
  });

  test('mimik ustası', () {
    final o = yeni();
    o.turBaslat();
    o.dogru('a', 'A');
    o.turuBitir();
    o.turBaslat();
    o.dogru('b', 'B');
    o.dogru('c', 'C');
    o.turuBitir();
    expect(o.mimikUstasi(), 2);
    expect(o.kazananlar(), [1]);
  });
}
