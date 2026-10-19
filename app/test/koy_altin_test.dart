import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/koy_kurtlar/koy_mantik.dart';

/// Altın vektörler: golden/koy_vektorler.json. Aynı dosya sunucu tarafında
/// (server/test/golden.test.ts) TypeScript motoruna karşı çalıştırılır.
void main() {
  final dosya = File('../golden/koy_vektorler.json');
  final veri = jsonDecode(dosya.readAsStringSync()) as Map<String, dynamic>;
  final roller = {for (final r in Rol.values) r.name: r};

  List<List<Object?>> olumler(List<Olum> o) => [for (final x in o) [x.id, x.neden.name]];

  for (final v in (veri['vektorler'] as List).cast<Map<String, dynamic>>()) {
    test('altın vektör: ${v['ad']}', () {
      final n = v['n'] as int;
      final ids = List.generate(n, (i) => i + 1);
      final a = (v['ayar'] as Map<String, dynamic>);
      final ayar = KoyAyarlar(
        acikOylama: a['acikOylama'] as bool? ?? true,
        oluncRoluAc: a['oluncRoluAc'] as bool? ?? true,
        esitOyYenidenOy: a['esitOyYenidenOy'] as bool? ?? false,
        doktorKendiniKorur: a['doktorKendiniKorur'] as bool? ?? true,
      );
      final dagitim = [for (final r in v['roller'] as List) roller[r]!];
      if (v['bekleHata'] != null) {
        expect(
          () => KoyOyunu(oyuncuIdleri: ids, ayar: ayar, rolDagitimi: dagitim),
          throwsA(isA<KoyHatasi>().having((e) => e.kod, 'kod', v['bekleHata'])),
        );
        return;
      }
      final m = KoyOyunu(oyuncuIdleri: ids, ayar: ayar, rolDagitimi: dagitim);
      for (final adim in (v['adimlar'] as List).cast<Map<String, dynamic>>()) {
        Object? calis() {
          switch (adim['op']) {
            case 'gece':
              m.geceBasla();
              return null;
            case 'kurtOyu':
              m.kurtOyu(adim['actor'] as int, adim['hedef'] as int);
              return null;
            case 'koru':
              m.koru(adim['actor'] as int, adim['hedef'] as int);
              return null;
            case 'kahin':
              return m.kahinSorgula(adim['actor'] as int, adim['hedef'] as int);
            case 'iyilestir':
              m.cadiIyilestir(adim['actor'] as int);
              return null;
            case 'zehirle':
              m.cadiZehirle(adim['actor'] as int, adim['hedef'] as int);
              return null;
            case 'coz':
              return m.geceyiCoz();
            case 'oyBaslat':
              m.oyBaslat();
              return null;
            case 'oyVer':
              m.oyVer(adim['voter'] as int, adim['hedef'] as int?);
              return null;
            case 'oyBitir':
              return m.oylamayiBitir();
            case 'avciVur':
              return m.avciVur(adim['actor'] as int, adim['hedef'] as int?);
            case 'kazanan':
              return m.kazanan();
          }
          throw StateError('bilinmeyen op ${adim['op']}');
        }

        if (adim['hata'] != null) {
          expect(
            calis,
            throwsA(isA<KoyHatasi>().having((e) => e.kod, 'kod', adim['hata'])),
            reason: '${adim['op']} → ${adim['hata']}',
          );
          continue;
        }
        final sonuc = calis();
        final bekle = adim['bekle'];
        switch (adim['op']) {
          case 'coz':
            {
              final g = sonuc! as GeceSonucu;
              expect(olumler(g.olumler), bekle['olumler']);
              expect(g.avciBekliyor, bekle['avci']);
            }
          case 'oyBitir':
            {
              final o = sonuc! as ({List<Olum> olumler, int? avci, List<int> esitAdaylar});
              expect(olumler(o.olumler), bekle['olumler']);
              expect(o.avci, bekle['avci']);
              expect([...o.esitAdaylar]..sort(), (bekle['esit'] as List).cast<int>());
            }
          case 'avciVur':
            expect(olumler(sonuc! as List<Olum>), bekle);
          case 'kazanan':
            expect((sonuc as Taraf?)?.name, bekle);
          case 'kahin':
            expect(sonuc, bekle);
        }
      }
    });
  }
}
