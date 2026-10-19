import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/hic_yapmadim_ki/hy_mantik.dart';
import 'package:oyungecesi/shell/ortak/oyuncular.dart';

List<Oyuncu> _oyuncular(int n) =>
    [for (var i = 1; i <= n; i++) Oyuncu(id: i, ad: 'O$i', stilNo: i - 1)];

HyOyunu _oyun(int n, HyMod mod, {int can = 5, int tur = 20, int takas = 2}) =>
    HyOyunu(
      oyuncular: _oyuncular(n),
      ayar: HyAyar(mod: mod, can: can, takasHakki: takas, turSayisi: tur),
    );

void _turOyna(HyOyunu o, List<int> yapanlar, {List<int> pas = const []}) {
  o.kartOkundu();
  for (final id in yapanlar) {
    o.isaretDegistir(id);
  }
  for (final id in pas) {
    o.isaretDegistir(id);
    o.isaretDegistir(id);
  }
  o.cevapBitti();
  o.sonucGecildi();
}

void main() {
  test('parmak: sayım aralığı doğrulanır', () {
    final o = _oyun(5, HyMod.parmak);
    o.kartOkundu();
    o.cevapBitti();
    expect(o.asama, HyAsama.sayim);
    expect(() => o.sayimGir(6), throwsRangeError);
    o.sayimGir(3);
    expect(o.sonuc!.yapan, 3);
    expect(o.sonuc!.toplam, 5);
    expect(o.sonuc!.yuzde, 60);
  });

  test('parmak: cihaz kimlik tutmaz', () {
    final o = _oyun(5, HyMod.parmak);
    o.kartOkundu();
    o.isaretDegistir(1); // çip modu değil: yok sayılır
    expect(o.isaretler[1], HyIsaret.bos);
  });

  test('can: 3 kişi yapınca 5→4', () {
    final o = _oyun(5, HyMod.can);
    _turOyna(o, [1, 2, 3]);
    expect(o.can[1], 4);
    expect(o.can[4], 5);
    expect(o.asama, HyAsama.kart);
    expect(o.tur, 2);
  });

  test('pas diyen paydadan düşer: 5 oyuncu, 1 pas, 2 yaptım → 2/4', () {
    final o = _oyun(5, HyMod.isimli);
    o.kartOkundu();
    o.isaretDegistir(1);
    o.isaretDegistir(2);
    o.isaretDegistir(3);
    o.isaretDegistir(3); // yaptım → pas
    o.cevapBitti();
    expect(o.sonuc!.yapan, 2);
    expect(o.sonuc!.toplam, 4);
  });

  test('can 0 olan elenir ve işaretleyemez', () {
    final o = _oyun(3, HyMod.can, can: 1);
    _turOyna(o, [1]);
    expect(o.elendi(1), isTrue);
    expect(o.asama, HyAsama.kart);
    o.kartOkundu();
    o.isaretDegistir(1);
    expect(o.isaretler[1], HyIsaret.bos);
  });

  test('tek oyuncu kalınca biter, o kazanır', () {
    final o = _oyun(3, HyMod.can, can: 1);
    _turOyna(o, [1]);
    _turOyna(o, [2]);
    expect(o.asama, HyAsama.bitti);
    expect(o.kazananlar.map((e) => e.id), [3]);
  });

  test('aynı turda kalan herkes elenirse önceki hayattakiler ortak kazanan', () {
    final o = _oyun(2, HyMod.can, can: 1);
    _turOyna(o, [1, 2]);
    expect(o.asama, HyAsama.bitti);
    expect(o.kazananlar.map((e) => e.id).toSet(), {1, 2});
  });

  test('tur dolunca en çok canı olan kazanır; eşitlik ortak', () {
    final o = _oyun(3, HyMod.can, can: 3, tur: 2);
    _turOyna(o, [1]);
    _turOyna(o, [2]);
    expect(o.asama, HyAsama.bitti);
    expect(o.kazananlar.map((e) => e.id), [3]);
  });

  test('kart değiştirme hakkı biter', () {
    final o = _oyun(3, HyMod.parmak, takas: 2);
    o.kartDegistir();
    o.kartDegistir();
    expect(o.takasKalan, 0);
    expect(() => o.kartDegistir(), throwsStateError);
  });

  test('yanlış fazda işlem reddedilir', () {
    final o = _oyun(3, HyMod.can);
    expect(() => o.isaretDegistir(1), throwsStateError);
    expect(() => o.sayimGir(1), throwsStateError);
  });

  test('sınırsız tur: yalnız bitir ile biter', () {
    final o = _oyun(3, HyMod.isimli, tur: 0);
    for (var i = 0; i < 30; i++) {
      _turOyna(o, []);
    }
    expect(o.asama, HyAsama.kart);
    o.bitir();
    expect(o.asama, HyAsama.bitti);
  });
}
