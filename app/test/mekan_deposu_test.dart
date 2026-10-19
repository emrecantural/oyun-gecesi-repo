import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/content/icerik.dart';
import 'package:oyungecesi/games/kim_casus/mekan_deposu.dart';

IcerikOgesi _o(String id, String tur, String seviye, String metin, [String ek = '']) =>
    IcerikOgesi(
      id: id, oyun: '02', tur: tur, seviye: seviye, metin: metin, ek: ek,
      fiziksel: false, grup: false, risk: '', durum: 'onayli');

void main() {
  test('mekân kurulumu: ücretsiz 12, sabit ikisi dahil', () {
    final ogeler = <IcerikOgesi>[];
    final adlar = [for (var i = 0; i < 20; i++) 'M$i', 'Yılbaşı Sofrası', 'Havai Fişek Meydanı'];
    for (final ad in adlar) {
      ogeler.add(_o('m-$ad', 'mekan', 'ad', ad, 'kamu'));
      ogeler.add(_o('r-$ad', 'rol', ad, 'Rol'));
      ogeler.add(_o('i-$ad', 'ipucu', ad, 'İpucu'));
    }
    final m = mekanlariKur(ogeler);
    expect(m.length, 22);
    expect(m.where((e) => e.ucretsiz).length, 12);
    expect(m.firstWhere((e) => e.ad == 'Yılbaşı Sofrası').ucretsiz, isTrue);
    expect(m.firstWhere((e) => e.ad == 'Havai Fişek Meydanı').ucretsiz, isTrue);
    expect(m.first.roller, ['Rol']);
  });

  test('rolü olmayan mekân alınmaz', () {
    final m = mekanlariKur([_o('m', 'mekan', 'ad', 'X', 'kamu')]);
    expect(m, isEmpty);
  });
}
