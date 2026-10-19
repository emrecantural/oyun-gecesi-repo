import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/dogruluk_cesaret/tod_mantik.dart';
import 'package:oyungecesi/shell/ortak/oyuncular.dart';

List<Oyuncu> _o(int n) =>
    [for (var i = 1; i <= n; i++) Oyuncu(id: i, ad: 'O$i', stilNo: i - 1)];

int _sayac = 0;
TodKart? _kart(TodTur tur, {bool alternatif = false}) {
  _sayac++;
  return TodKart(
    id: 'k$_sayac',
    tur: tur,
    metin: 'm$_sayac',
    grup: false,
    fiziksel: false,
  );
}

TodOyunu _oyun(int n, {int pas = 1, int joker = 1, int hedef = 0, int sn = 0, TodSira sira = TodSira.sirayla}) =>
    TodOyunu(
      oyuncular: _o(n),
      ayar: TodAyar(sira: sira, pas: pas, joker: joker, gorevSn: sn, kartHedefi: hedef),
      kartCek: _kart,
      rastgele: Random(7),
    );

void main() {
  test('sırayla ilerler, tamam sonrası sıra seçilir', () {
    final o = _oyun(3);
    expect(o.siraCek(), 1);
    o.sec(TodTur.dogruluk);
    expect(o.asama, TodAsama.yap);
    o.tamam();
    expect(o.asama, TodAsama.siraSec);
    expect(o.siraCek(), 2);
    expect(o.durum(1).tamamlanan, 1);
  });

  test('süre açıkken kart fazı ve başla', () {
    final o = _oyun(3, sn: 30);
    o.siraCek();
    o.sec(TodTur.cesaret);
    expect(o.asama, TodAsama.kart);
    o.basla();
    expect(o.asama, TodAsama.yap);
  });

  test('pas hakkı düşer, hak bitince alternatif hak harcamaz', () {
    final o = _oyun(3, pas: 1);
    o.siraCek();
    o.sec(TodTur.cesaret);
    o.pas();
    expect(o.durum(1).pasKalan, 0);
    expect(o.gecmis.last.sonuc, TodSonuc.pas);
    o.pas(); // hak yok → alternatif
    expect(o.durum(1).pasKalan, 0);
    expect(o.gecmis.last.sonuc, TodSonuc.alternatif);
    o.tamam();
    expect(o.durum(1).tamamlanan, 1);
  });

  test('joker: yalnız tek kişilik cesaret; devralan tamamlar', () {
    final o = _oyun(3);
    o.siraCek();
    o.sec(TodTur.dogruluk);
    expect(o.jokerKullanilabilir, isFalse);
    final p = _oyun(3);
    p.siraCek();
    p.sec(TodTur.cesaret);
    expect(p.jokerKullanilabilir, isTrue);
    p.joker(2);
    expect(p.durum(1).jokerKalan, 0);
    expect(p.gorevSahibi.id, 2);
    expect(p.jokerKullanilabilir, isFalse); // zincirleme devir yok
    p.tamam();
    expect(p.durum(2).tamamlanan, 1);
    expect(p.durum(1).tamamlanan, 0);
  });

  test('joker kendine verilemez', () {
    final p = _oyun(3);
    p.siraCek();
    p.sec(TodTur.cesaret);
    expect(() => p.joker(1), throwsStateError);
  });

  test('geç: devralan hak harcamaz ve tamamlanmış sayılmaz', () {
    final p = _oyun(3);
    p.siraCek();
    p.sec(TodTur.cesaret);
    p.joker(2);
    p.gec();
    expect(p.tamamlananToplam, 0);
    expect(p.oynanan, 1);
  });

  test('kart hedefi dolunca biter', () {
    final o = _oyun(2, hedef: 2);
    o.siraCek();
    o.sec(TodTur.dogruluk);
    o.tamam();
    o.siraCek();
    o.sec(TodTur.dogruluk);
    o.tamam();
    expect(o.asama, TodAsama.bitti);
  });

  test('şişe: iki kişide sıralı, aynı kişi art arda gelmez', () {
    final o = _oyun(2, sira: TodSira.sise);
    var onceki = o.siraCek();
    for (var i = 0; i < 6; i++) {
      o.sec(TodTur.dogruluk);
      o.tamam();
      final s = o.siraCek();
      expect(s, isNot(onceki));
      onceki = s;
    }
  });

  test('kura: herkes bir kez çıkmadan tekrar yok', () {
    final o = _oyun(4, sira: TodSira.kura);
    final cikan = <int>[];
    for (var i = 0; i < 4; i++) {
      cikan.add(o.siraCek());
      o.sec(TodTur.dogruluk);
      o.tamam();
    }
    expect(cikan.toSet().length, 4);
  });

  test('rozetler: eşitlikte hepsine, sayı 0 ise verilmez', () {
    final o = _oyun(3);
    expect(o.enCesurlar, isEmpty);
    o.siraCek();
    o.sec(TodTur.cesaret);
    o.tamam();
    expect(o.enCesurlar.map((e) => e.id), [1]);
    expect(o.durustler, isEmpty);
  });

  test('oyuncu çıkarsa ve sıra ondaysa yeniden çekilir; <2 duraklat', () {
    final o = _oyun(3);
    o.siraCek();
    expect(o.oyuncuCikar(1), isTrue);
    expect(o.asama, TodAsama.siraSec);
    expect(o.oyuncuCikar(2), isFalse);
  });

  test('yanlış fazda hata', () {
    final o = _oyun(3);
    expect(() => o.sec(TodTur.dogruluk), throwsStateError);
    expect(() => o.tamam(), throwsStateError);
  });
}
