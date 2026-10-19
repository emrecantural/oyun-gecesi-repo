import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/monetization/reklam_kurallari.dart';

void main() {
  test('yılbaşı penceresi 31 Ara 20:00 – 1 Oca 02:00', () {
    expect(yilbasiPenceresi(DateTime(2026, 12, 31, 19, 59)), isFalse);
    expect(yilbasiPenceresi(DateTime(2026, 12, 31, 20)), isTrue);
    expect(yilbasiPenceresi(DateTime(2027, 1, 1, 1, 59)), isTrue);
    expect(yilbasiPenceresi(DateTime(2027, 1, 1, 2)), isFalse);
    expect(yilbasiPenceresi(DateTime(2026, 12, 30, 23)), isFalse);
  });

  test('ilk oyun reklamsız, ikinci tamamlanan oyundan sonra gösterilir', () {
    final s = GecisSikligi();
    final t = DateTime(2026, 11, 1, 12);
    s.oyunTamamlandi(const Duration(minutes: 10));
    expect(s.gosterilebilir(t), isFalse);
    s.oyunTamamlandi(const Duration(minutes: 10));
    expect(s.gosterilebilir(t), isTrue);
  });

  test('iki reklam arası 4 dakika', () {
    final s = GecisSikligi();
    final t = DateTime(2026, 11, 1, 12);
    s
      ..oyunTamamlandi(const Duration(minutes: 5))
      ..oyunTamamlandi(const Duration(minutes: 5))
      ..gosterildi(t);
    expect(s.gosterilebilir(t.add(const Duration(minutes: 3))), isFalse);
    expect(s.gosterilebilir(t.add(const Duration(minutes: 4))), isTrue);
  });

  test('günlük sınır 12 ve ertesi gün sıfırlanır', () {
    final s = GecisSikligi(enAzAralik: Duration.zero)
      ..oyunTamamlandi(const Duration(minutes: 5))
      ..oyunTamamlandi(const Duration(minutes: 5));
    final t = DateTime(2026, 11, 1, 10);
    for (var i = 0; i < 12; i++) {
      expect(s.gosterilebilir(t), isTrue);
      s.gosterildi(t);
    }
    expect(s.gosterilebilir(t), isFalse);
    expect(s.gosterilebilir(DateTime(2026, 11, 2, 10)), isTrue);
  });

  test('3 dakikadan kısa oyun yarım sayılır', () {
    final s = GecisSikligi()
      ..oyunTamamlandi(const Duration(minutes: 2))
      ..oyunTamamlandi(const Duration(minutes: 2));
    expect(s.oyunSayaci, 1);
    expect(s.gosterilebilir(DateTime(2026, 11, 1, 12)), isFalse);
  });
}
