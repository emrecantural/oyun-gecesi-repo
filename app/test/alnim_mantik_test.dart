import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/alnimdaki_kim/alnim_mantik.dart';

KelimeSatiri s(Sonuc r, [int ms = 8000]) => KelimeSatiri('x', 'x', r, ms);

void main() {
  test('tur puanı', () {
    final l = [s(Sonuc.dogru), s(Sonuc.dogru), s(Sonuc.pas), s(Sonuc.ihlal), s(Sonuc.iptal)];
    expect(turPuani(l), 1);
    expect(turPuani(l, pasCezali: true), 0);
  });

  test('bireysel sıra ve tur sayısı', () {
    final o = AlnimdakiOyunu(oyuncuIdleri: [1, 2, 3], turPerOyuncu: 2);
    expect(o.toplamTur, 6);
    final sira = <int>[];
    while (!o.bitti) {
      sira.add(o.siradaki!);
      o.turuBitir([s(Sonuc.dogru)]);
    }
    expect(sira, [1, 2, 3, 1, 2, 3]);
    expect(o.bireyselPuan(), {1: 2, 2: 2, 3: 2});
  });

  test('takımlıda dönüşümlü sıra ve takım puanı', () {
    final o = AlnimdakiOyunu(
        oyuncuIdleri: [1, 2, 3, 4, 5], turPerOyuncu: 1, takimSayisi: 2);
    final sira = <int>[];
    while (!o.bitti) {
      sira.add(o.siradaki!);
      o.turuBitir([s(Sonuc.dogru)]);
    }
    // takım0: 1,3,5  takım1: 2,4
    expect(sira, [1, 2, 3, 4, 5]);
    expect(o.takimPuani(), {0: 3, 1: 2});
  });

  test('pas hakkı', () {
    final o = AlnimdakiOyunu(oyuncuIdleri: [1, 2], turPerOyuncu: 1);
    expect(o.pasKalan([s(Sonuc.pas), s(Sonuc.pas)]), 1);
    expect(o.pasKalan([s(Sonuc.pas), s(Sonuc.pas), s(Sonuc.pas), s(Sonuc.pas)]), 0);
    final s2 = AlnimdakiOyunu(oyuncuIdleri: [1, 2], turPerOyuncu: 1, pasHakki: 0);
    expect(s2.pasKalan([s(Sonuc.pas)]) > 100, isTrue);
  });

  test('rozetler', () {
    final o = AlnimdakiOyunu(oyuncuIdleri: [1, 2], turPerOyuncu: 1);
    o.turuBitir([s(Sonuc.dogru, 3000)]);
    o.turuBitir([s(Sonuc.dogru), s(Sonuc.pas)]);
    expect(o.dilBilmez(), [1]);
    expect(o.telepati(), [1]);
  });
}
