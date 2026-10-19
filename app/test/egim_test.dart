import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/alnimdaki_kim/egim.dart';

/// Verilen eğimde (derece) ivmeölçer örneği: x=0, y=g·cos, z=g·sin.
EgimOlayi? besle(EgimTespitcisi e, double derece, int t) {
  final r = derece * pi / 180;
  return e.isle(0, 9.81 * cos(r), 9.81 * sin(r), t);
}

/// 0..süre ms boyunca 20 ms aralıkla örnek verir; ilk tetiği döner.
EgimOlayi? sur(EgimTespitcisi e, double derece, int bas, int sure) {
  EgimOlayi? ilk;
  for (var t = bas; t <= bas + sure; t += 20) {
    final o = besle(e, derece, t);
    ilk ??= o;
  }
  return ilk;
}

EgimTespitcisi kalibre() {
  final e = EgimTespitcisi();
  sur(e, 2, 0, 1100);
  expect(e.hazir, isTrue);
  return e;
}

void main() {
  test('kararlı 1 sn sonra θ0 alınır; oynak elde alınmaz', () {
    final e = EgimTespitcisi();
    sur(e, 2, 0, 1100);
    expect(e.teta0, closeTo(2, 0.5));
    final h = EgimTespitcisi();
    for (var t = 0; t <= 2000; t += 20) {
      besle(h, (t ~/ 20).isEven ? 0 : 20, t);
    }
    expect(h.hazir, isFalse);
  });

  test('öne eğim 650 ms → doğru, 500 ms → tetik yok', () {
    final e = kalibre();
    expect(sur(e, -40, 2000, 500), isNull);
    final e2 = kalibre();
    expect(sur(e2, -40, 2000, 650), EgimOlayi.dogru);
  });

  test('arkaya eğim → pas', () {
    final e = kalibre();
    expect(sur(e, 45, 2000, 700), EgimOlayi.pas);
  });

  test('tetikten sonra dönmeden ve 1 sn dolmadan ikinci tetik yok', () {
    final e = kalibre();
    expect(sur(e, -40, 2000, 700), EgimOlayi.dogru);
    // eğik tutmaya devam: kilitli
    expect(sur(e, -40, 2720, 2000), isNull);
    // geri dön, ≥300 ms bekle, tekrar eğ
    sur(e, 2, 4800, 400);
    expect(sur(e, -40, 5300, 700), EgimOlayi.dogru);
  });
}
