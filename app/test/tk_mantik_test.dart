import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/tek_kelime/tk_mantik.dart';

void main() {
  test('normalleştirme ve kök', () {
    expect(tkNorm('Çiçek!'), 'cicek');
    expect(tkNorm('IŞIK'), 'isik');
    expect(tkKok('okumak'), 'oku');
    expect(tkKok('okuma'), 'oku');
    expect(tkKok('kitaplar'), 'kitap');
  });

  test('aynı say', () {
    expect(tkAyni('okumak', 'okuma'), isTrue);
    expect(tkAyni('Kitap', 'kitaplar'), isTrue);
    expect(tkAyni('kitap', 'sayfa'), isFalse);
    expect(tkAyni('ev', 'el'), isFalse); // kısa kelimede Levenshtein uygulanmaz
    expect(tkAyni('kütüphane', 'kutuphane'), isTrue);
    expect(tkAyni('araba', 'arabs'), isTrue);
  });

  test('şüpheli', () {
    expect(tkSupheli('kitabi', 'kitap'), isTrue);
    expect(tkSupheli('sayfa', 'okumak'), isFalse);
  });

  test('ipucu doğrulama', () {
    expect(tkIpucuDogrula('', 'kitap', []), IpucuHatasi.bos);
    expect(tkIpucuDogrula('iki kelime', 'kitap', []), IpucuHatasi.cokKelime);
    expect(tkIpucuDogrula('5', 'kitap', []), IpucuHatasi.sayiVeyaHarf);
    expect(tkIpucuDogrula('a', 'kitap', []), IpucuHatasi.sayiVeyaHarf);
    expect(tkIpucuDogrula('kitaplar', 'kitap', []), IpucuHatasi.kelimeninKendisi);
    expect(tkIpucuDogrula('defter', 'kitap', ['defter']), IpucuHatasi.yasakKok);
    expect(tkIpucuDogrula('sayfa', 'kitap', ['defter']), isNull);
  });

  test('eleme: aynı kökler silinir, örnek tur', () {
    final c = [Ipucu(1, 'okumak'), Ipucu(2, 'okuma'), Ipucu(3, 'sayfa'), Ipucu(4, 'kütüphane')];
    final g = tkEle(c);
    expect(g.length, 1);
    expect(g.first.durum, 'auto');
    expect(c.map((e) => e.silindi).toList(), [true, true, false, false]);
  });

  test('eleme: şüpheli karar bekler', () {
    final c = [Ipucu(1, 'kitabı'), Ipucu(2, 'kitap')];
    // 'kitabı' / 'kitap': kökler ve Levenshtein eşit değil, ortak ilk 4 harf → şüpheli
    final g = tkEle(c);
    expect(g.single.durum, 'suspect');
    final c2 = [Ipucu(1, 'karpuzcu'), Ipucu(2, 'karpuzda')];
    final g2 = tkEle(c2);
    expect(g2.first.durum, 'auto'); // kökler eşit
    final c3 = [Ipucu(1, 'kartal'), Ipucu(2, 'kartopu')];
    final g3 = tkEle(c3);
    expect(g3.single.durum, 'suspect');
    expect(c3.any((e) => e.silindi), isFalse);
    g3.single.aynidir = true;
    tkSupheliUygula(c3, g3);
    expect(c3.every((e) => e.silindi), isTrue);
  });

  test('kart akışı: yanlışta sonraki kart da atılır', () {
    final o = TekKelimeOyunu(oyuncuIdleri: [1, 2, 3], kartSayisi: 5);
    expect(o.tahminciId, 1);
    o.kartiBitir(KartSonucu.dogru);
    expect(o.tahminciId, 2);
    o.kartiBitir(KartSonucu.yanlis);
    expect(o.ilerleme, 3);
    o.kartiBitir(KartSonucu.pas);
    expect(o.pasKalan, 0);
    expect(() => o.kartiBitir(KartSonucu.pas), throwsStateError);
    o.kartiBitir(KartSonucu.pas, otomatikPas: true);
    expect(o.bitti, isTrue);
    expect(o.dogruSayisi, 1);
  });

  test('derece', () {
    expect(TekKelimeOyunu.derece(13, 13), 'Mükemmel!');
    expect(TekKelimeOyunu.derece(11, 13), 'Harika');
    expect(TekKelimeOyunu.derece(8, 13), 'İyi takım');
    expect(TekKelimeOyunu.derece(3, 13), 'Daha çok çalışın');
  });
}
