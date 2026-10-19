import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/yeni_yil_kehaneti/kehanet_mantik.dart';

Kapsul yeni({int n = 2}) => Kapsul(
      uyeler: [Uye(id: 1, ad: 'Ayşe'), Uye(id: 2, ad: 'Bora')],
      tahminSayisi: n,
      acilis: DateTime(2027, 12, 31, 23),
      tohum: 42,
    );

void main() {
  test('puan formülü', () {
    expect(kehanetPuani(Karar.oldu, 100), 1.0 + 1.0);
    expect(kehanetPuani(Karar.oldu, 50), 1.75);
    expect(kehanetPuani(Karar.oldu, 10), 1.19);
    expect(kehanetPuani(Karar.kismen, 70), 0.5);
    expect(kehanetPuani(Karar.olmadi, 70), 0);
  });

  test('karar: eşitlikte kısmen', () {
    expect(kararVer(3, 1, 1), Karar.oldu);
    expect(kararVer(1, 1, 3), Karar.olmadi);
    expect(kararVer(2, 2, 1), Karar.kismen);
    expect(kararVer(0, 0, 0), Karar.kismen);
  });

  test('tohumlu karıştırma deterministik ve permütasyon', () {
    final l = List.generate(20, (i) => i);
    expect(karistir(l, 7), karistir(l, 7));
    expect(karistir(l, 7)..sort(), l);
    expect(karistir(l, 7), isNot(karistir(l, 8)));
  });

  test('yasak konu İ/ı ve aksan duyarsız', () {
    expect(tahminYasakliMi('Bu yıl biri HASTALIK geçirecek'), isTrue);
    expect(tahminYasakliMi('hastalik'), isTrue);
    expect(tahminYasakliMi('Bu yıl biri kazanacak'), isFalse);
    expect(tahminYasakliMi('Bir kaza olacak'), isTrue);
    expect(tahminYasakliMi('Bu yıl hangimiz kitap bitirecek?'), isFalse);
    expect(tahminDogrula(''), TahminHatasi.bos);
    expect(tahminDogrula('a' * 141), TahminHatasi.uzun);
  });

  test('varsayılan açılış', () {
    expect(varsayilanAcilis(DateTime(2026, 3, 1)), DateTime(2026, 12, 31, 23));
    expect(varsayilanAcilis(DateTime(2026, 12, 20)), DateTime(2027, 12, 31, 23));
    expect(varsayilanAcilis(DateTime(2026, 12, 31, 22, 30)), DateTime(2027, 12, 31, 23));
  });

  test('kapsül akışı', () {
    final k = yeni();
    k.ekle(1, 'Bu yıl biri kitap bitirecek', 70);
    expect(() => k.muhurle(1), throwsA(isA<KapsulHatasi>()));
    k.ekle(1, 'Biri yeni hobi edinecek', 50);
    expect(() => k.ekle(1, 'fazla', 50), throwsA(isA<KapsulHatasi>()));
    k.muhurle(1);
    expect(() => k.ekle(1, 'x y z', 50), throwsA(isA<KapsulHatasi>()));
    expect(() => k.kapat(), throwsA(isA<KapsulHatasi>()));
    k.ekle(2, 'Biri şehir değiştirecek', 30);
    k.ekle(2, 'Biri maraton koşacak', 20);
    k.muhurle(2);
    k.kapat();
    expect(k.acilabilir(DateTime(2027, 6, 1)), isFalse);
    expect(() => k.acilisSirasi(DateTime(2027, 6, 1)), throwsA(isA<KapsulHatasi>()));
    expect(k.acilisSirasi(DateTime(2027, 12, 31, 23)).length, 4);
  });

  test('çekilen üyenin tahminleri çıkar; json gidiş-dönüş', () {
    final k = yeni(n: 1);
    k.ekle(1, 'Biri kitap bitirecek', 70);
    k.ekle(2, 'Biri hobi edinecek', 60);
    k.muhurle(1);
    k.muhurle(2);
    k.cekil(2);
    k.kapat();
    final k2 = Kapsul.fromJson(k.toJson());
    final s = k2.acilisSirasi(DateTime(2028));
    expect(s.length, 1);
    expect(s.first.uyeId, 1);
  });
}
