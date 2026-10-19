import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/bilgi_yarismasi/quiz_mantik.dart';

QuizSoru soru() => QuizSoru('q', 'Soru', ['a', 'b', 'c', 'd'], 2, 'genel');

void main() {
  test('puan sınırları', () {
    expect(quizPuani(kalanMs: 0, toplamMs: 15000, seriSonrasi: 1, sonSoru: false), 500);
    expect(quizPuani(kalanMs: 15000, toplamMs: 15000, seriSonrasi: 1, sonSoru: false), 1000);
    expect(quizPuani(kalanMs: 11000, toplamMs: 15000, seriSonrasi: 1, sonSoru: false), 867);
    expect(quizPuani(kalanMs: 15000, toplamMs: 15000, seriSonrasi: 5, sonSoru: true), 2400);
    expect(quizPuani(kalanMs: 15000, toplamMs: 15000, seriSonrasi: 3, sonSoru: false), 1100);
    expect(quizPuani(kalanMs: 99999, toplamMs: 15000, seriSonrasi: 1, sonSoru: false), 1000);
    expect(quizPuani(kalanMs: -5, toplamMs: 15000, seriSonrasi: 1, sonSoru: false), 500);
  });

  test('csv ayrıştırma: doğru şık karıştırmadan sonra bulunur', () {
    final q = QuizSoru.csvden('x', 'Başkent?', 'Ankara|İstanbul|İzmir|Bursa|cografya', Random(1))!;
    expect(q.siklar[q.dogru], 'Ankara');
    expect(q.kategori, 'cografya');
    final n = SayisalSoru.csvden('n', 'Kaç?', '1453|yıl')!;
    expect(n.dogru, 1453);
  });

  test('seri, yanlış ve yanıtsız', () {
    final m = QuizMotoru(oyuncuIdleri: [1, 2], soruSayisi: 10, toplamMs: 10000);
    final s = soru();
    for (var i = 0; i < 3; i++) {
      m.cevapla(1, 2, 10000);
      m.cevapla(2, 0, 10000);
      m.soruyuBitir(s);
      m.sonraki();
    }
    expect(m.oyuncular[1]!.seri, 3);
    expect(m.oyuncular[2]!.seri, 0);
    expect(m.oyuncular[1]!.puan, 1000 + 1000 + 1100);
    m.soruyuBitir(s); // kimse yanıtlamadı
    expect(m.oyuncular[1]!.seri, 0);
  });

  test('kilit ve geç cevap', () {
    final m = QuizMotoru(oyuncuIdleri: [1, 2], soruSayisi: 5, toplamMs: 10000);
    m.cevapla(1, 0, 5000);
    expect(() => m.cevapla(1, 1, 4000), throwsStateError);
    expect(() => m.cevapla(2, 1, -1), throwsStateError);
  });

  test('joker: iki yanlış şık, bir kez', () {
    final m = QuizMotoru(oyuncuIdleri: [1], soruSayisi: 5, toplamMs: 10000);
    final k = m.jokerKullan(1, soru(), Random(3));
    expect(k.length, 2);
    expect(k.contains(2), isFalse);
    expect(() => m.jokerKullan(1, soru(), Random(3)), throwsStateError);
  });

  test('eşitlik ve en yakın tahmin', () {
    final m = QuizMotoru(oyuncuIdleri: [1, 2, 3], soruSayisi: 1, toplamMs: 10000);
    m.cevapla(1, 2, 10000);
    m.cevapla(2, 2, 10000);
    m.cevapla(3, 0, 10000);
    m.soruyuBitir(soru());
    expect(m.esitlik(), [1, 2]);
    expect(QuizMotoru.yakinKazananlar({1: 90, 2: 110}, 100), [1, 2]);
    expect(QuizMotoru.yakinKazananlar({1: 95, 2: 140}, 100), [1]);
  });

  test('kesinti: cevaplariSil puanlamadan atar', () {
    final m = QuizMotoru(oyuncuIdleri: [1, 2], soruSayisi: 3, toplamMs: 10000);
    m.cevapla(1, soru().dogru, 8000);
    m.cevaplariSil();
    expect(m.yanitladi(1), isFalse);
    final r = m.soruyuBitir(soru());
    expect(r.puanlar.values.every((p) => p == 0), isTrue);
    expect(m.oyuncular[1]!.puan, 0);
  });
}
