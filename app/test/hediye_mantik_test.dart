import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/gizli_hediye/hediye_mantik.dart';

HediyeCekilisi _k(int n, {int seed = 1}) {
  final c = HediyeCekilisi(rastgele: Random(seed));
  for (var i = 1; i <= n; i++) {
    c.katilimciEkle(i);
  }
  return c;
}

bool _tekHalka(Map<int, int> a) {
  var simdi = a.keys.first;
  var adim = 0;
  do {
    simdi = a[simdi]!;
    adim++;
  } while (simdi != a.keys.first && adim <= a.length);
  return adim == a.length;
}

void main() {
  test('tek halka, kimse kendini çekmez (n=3..50)', () {
    for (final n in [3, 4, 8, 20, 50]) {
      for (var seed = 0; seed < 20; seed++) {
        final c = _k(n, seed: seed)..cek();
        final a = c.testIcinAtama();
        expect(a.length, n);
        expect(a.values.toSet().length, n);
        expect(a.entries.every((e) => e.key != e.value), isTrue);
        expect(_tekHalka(a), isTrue);
      }
    }
  });

  test('hariç tutulan çiftler eşleşmez (iki yönde)', () {
    for (var seed = 0; seed < 50; seed++) {
      final c = _k(8, seed: seed);
      c.haricEkle(1, 2);
      c.haricEkle(3, 4);
      c.cek();
      final a = c.testIcinAtama();
      expect(a[1] != 2 && a[2] != 1 && a[3] != 4 && a[4] != 3, isTrue);
    }
  });

  test('3 kişide bir çift bile ayrılırsa çözümsüz', () {
    final c = _k(3)..haricEkle(1, 2);
    expect(() => c.cek(), throwsA(isA<HediyeHata>()));
  });

  test('zor ama çözülebilir: geri izleme bulur', () {
    // 6 kişi, yıldız dışı kenarlar: 1 yalnız 2 ve 3 ile eşleşebilir.
    final c = _k(6)
      ..haricEkle(1, 4)
      ..haricEkle(1, 5)
      ..haricEkle(1, 6);
    c.cek();
    final a = c.testIcinAtama();
    expect(_tekHalka(a), isTrue);
    expect({a[1], _tersi(a, 1)}.difference({2, 3}), isEmpty);
  });

  test('en az 3, en çok 50', () {
    final c = _k(2);
    expect(() => c.cek(), throwsA(isA<HediyeHata>()));
    final d = _k(50);
    expect(() => d.katilimciEkle(51), throwsA(isA<HediyeHata>()));
  });

  test('ilk görüntülemeden sonra kilit: çek/iptal/ekle/çıkar yok', () {
    final c = _k(4)..cek();
    c.goster(1);
    expect(() => c.iptal(), throwsA(isA<HediyeHata>()));
    expect(() => c.katilimciEkle(9), throwsA(isA<HediyeHata>()));
    expect(() => c.katilimciCikar(2), throwsA(isA<HediyeHata>()));
    expect(() => c.cek(), throwsA(isA<HediyeHata>()));
    expect(c.goruntulenme[1], 1);
    c.goster(1);
    expect(c.goruntulenme[1], 2);
  });

  test('iptal: görüntülenmediyse serbest', () {
    final c = _k(4)..cek();
    c.iptal();
    expect(c.cekildi, isFalse);
    c.cek();
    expect(c.cekildi, isTrue);
  });

  test('herkes baktı ve sil', () {
    final c = _k(3)..cek();
    expect(c.herkesBakti, isFalse);
    for (var i = 1; i <= 3; i++) {
      c.goster(i);
    }
    expect(c.herkesBakti, isTrue);
    c.sil();
    expect(c.katilimcilar, isEmpty);
    expect(c.kilitli, isFalse);
  });

  test('katılımcı çıkınca çiftleri de silinir', () {
    final c = _k(5)..haricEkle(1, 2);
    c.katilimciCikar(1);
    expect(c.haricCiftler, isEmpty);
  });
}

int? _tersi(Map<int, int> a, int hedef) {
  for (final e in a.entries) {
    if (e.value == hedef) return e.key;
  }
  return null;
}
