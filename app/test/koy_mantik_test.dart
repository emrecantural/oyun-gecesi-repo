import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/games/koy_kurtlar/koy_mantik.dart';

KoyOyunu oyun(Map<Rol, int> paket, {KoyAyarlar ayar = const KoyAyarlar(), int tohum = 1}) {
  final n = paket.values.fold<int>(0, (a, b) => a + b);
  return KoyOyunu(
    oyuncuIdleri: List.generate(n, (i) => i + 1),
    rolPaketi: paket,
    ayar: ayar,
    tohum: tohum,
  );
}

int kimde(KoyOyunu o, Rol r, [int sira = 0]) =>
    o.roller.entries.where((e) => e.value == r).map((e) => e.key).toList()[sira];

void main() {
  test('rol paketi tablosu', () {
    int t(Map<Rol, int> m) => m.values.fold(0, (a, b) => a + b);
    for (var n = 6; n <= 20; n++) {
      expect(t(varsayilanRolPaketi(n)), n);
    }
    expect(varsayilanRolPaketi(6)[Rol.kurt], 2);
    expect(varsayilanRolPaketi(8)[Rol.avci], 1);
    expect(varsayilanRolPaketi(10)[Rol.asik], 2);
    expect(varsayilanRolPaketi(12)[Rol.cadi], 1);
    expect(varsayilanRolPaketi(12)[Rol.kurt], 3);
    expect(varsayilanRolPaketi(16)[Rol.koylu], 6);
    expect(varsayilanRolPaketi(20)[Rol.koylu], 9);
  });

  test('rol paketi uyuşmazlığı', () {
    expect(
      () => KoyOyunu(oyuncuIdleri: [1, 2, 3], rolPaketi: {Rol.kurt: 1, Rol.koylu: 1}),
      throwsA(isA<KoyHatasi>()),
    );
  });

  test('rol dağıtımı paketi korur; aynı tohum aynı dağıtım', () {
    final a = KoyOyunu(oyuncuIdleri: List.generate(8, (i) => i + 1), tohum: 5);
    final b = KoyOyunu(oyuncuIdleri: List.generate(8, (i) => i + 1), tohum: 5);
    expect(a.roller, b.roller);
    expect(a.roller.values.where((r) => r == Rol.kurt).length, 2);
  });

  test('koruma kurbanı kurtarır', () {
    final o = oyun({Rol.kurt: 1, Rol.doktor: 1, Rol.koylu: 4});
    final kurt = kimde(o, Rol.kurt), dok = kimde(o, Rol.doktor), koy = kimde(o, Rol.koylu);
    o.geceBasla();
    o.kurtOyu(kurt, koy);
    o.koru(dok, koy);
    final s = o.geceyiCoz();
    expect(s.olumler, isEmpty);
    expect(o.canli(koy), isTrue);
  });

  test('doktor art arda aynı kişiyi koruyamaz; kendini koruma ayarı', () {
    final o = oyun({Rol.kurt: 1, Rol.doktor: 1, Rol.koylu: 4},
        ayar: const KoyAyarlar(doktorKendiniKorur: false));
    final dok = kimde(o, Rol.doktor), koy = kimde(o, Rol.koylu);
    o.geceBasla();
    expect(() => o.koru(dok, dok), throwsA(isA<KoyHatasi>()));
    o.koru(dok, koy);
    o.geceyiCoz();
    o.geceBasla();
    expect(() => o.koru(dok, koy), throwsA(isA<KoyHatasi>()));
  });

  test('cadı iyileştirme ölümü geri alır; zehir öldürür; iksir bir kez', () {
    final o = oyun({Rol.kurt: 1, Rol.cadi: 1, Rol.koylu: 4});
    final kurt = kimde(o, Rol.kurt), cadi = kimde(o, Rol.cadi);
    final k1 = kimde(o, Rol.koylu, 0), k2 = kimde(o, Rol.koylu, 1);
    o.geceBasla();
    o.kurtOyu(kurt, k1);
    o.cadiIyilestir(cadi);
    o.cadiZehirle(cadi, k2);
    final s = o.geceyiCoz();
    expect(s.olumler.map((e) => e.id), [k2]);
    expect(s.olumler.single.neden, OlumNedeni.zehir);
    o.geceBasla();
    expect(() => o.cadiIyilestir(cadi), throwsA(isA<KoyHatasi>()));
    expect(() => o.cadiZehirle(cadi, k1), throwsA(isA<KoyHatasi>()));
  });

  test('kurt hedefi + zehir aynı gece iki ölüm; sonra âşık zinciri ve avcı', () {
    final o = oyun({Rol.kurt: 1, Rol.cadi: 1, Rol.asik: 2, Rol.avci: 1, Rol.koylu: 2});
    final kurt = kimde(o, Rol.kurt), cadi = kimde(o, Rol.cadi);
    final a1 = kimde(o, Rol.asik, 0), a2 = kimde(o, Rol.asik, 1), av = kimde(o, Rol.avci);
    o.geceBasla();
    o.kurtOyu(kurt, a1);
    o.cadiZehirle(cadi, av);
    final s = o.geceyiCoz();
    final idler = s.olumler.map((e) => e.id).toSet();
    expect(idler, {a1, av, a2});
    expect(s.olumler.firstWhere((e) => e.id == a2).neden, OlumNedeni.askZinciri);
    expect(s.avciBekliyor, av);
  });

  test('kurtlar eşit oy: kurban yok', () {
    final o = oyun({Rol.kurt: 2, Rol.koylu: 4});
    final kurtlar = o.kurtlar;
    o.geceBasla();
    o.kurtOyu(kurtlar[0], kimde(o, Rol.koylu, 0));
    o.kurtOyu(kurtlar[1], kimde(o, Rol.koylu, 1));
    expect(o.kurbanHedefi, isNull);
    expect(o.geceyiCoz().olumler, isEmpty);
  });

  test('kâhin sorgusu ve kilit', () {
    final o = oyun({Rol.kurt: 1, Rol.kahin: 1, Rol.koylu: 3});
    final k = kimde(o, Rol.kahin);
    o.geceBasla();
    expect(o.kahinSorgula(k, kimde(o, Rol.kurt)), isTrue);
    expect(() => o.kahinSorgula(k, kimde(o, Rol.koylu)), throwsA(isA<KoyHatasi>()));
    o.geceBasla();
    expect(o.kahinSorgula(k, kimde(o, Rol.koylu)), isFalse);
  });

  test('oylama: en çok oy elenir, eşitlikte kimse; şüpheci', () {
    final o = oyun({Rol.kurt: 1, Rol.koylu: 4});
    final kurt = kimde(o, Rol.kurt);
    final k = o.oyuncular.where((i) => i != kurt).toList();
    o.oyBaslat();
    for (final v in k.take(3)) {
      o.oyVer(v, kurt);
    }
    o.oyVer(k[3], k[0]);
    o.oyVer(kurt, k[1]);
    final r = o.oylamayiBitir();
    expect(r.olumler.single.id, kurt);
    expect(o.supheci(), isNotNull);
    expect(o.kazanan(), Taraf.koy);

    final p = oyun({Rol.kurt: 1, Rol.koylu: 4});
    final pk = p.oyuncular.where((i) => p.roller[i] != Rol.kurt).toList();
    p.oyBaslat();
    p.oyVer(pk[0], pk[1]);
    p.oyVer(pk[1], pk[0]);
    final e = p.oylamayiBitir();
    expect(e.olumler, isEmpty);
    expect(e.esitAdaylar.toSet(), {pk[0], pk[1]});
    expect(() => p.oyVer(pk[0], pk[0]), throwsA(isA<KoyHatasi>()));
  });

  test('avcı oylamada elenirse vurur; zincir', () {
    final o = oyun({Rol.kurt: 1, Rol.avci: 1, Rol.asik: 2, Rol.koylu: 2});
    final av = kimde(o, Rol.avci);
    final a1 = kimde(o, Rol.asik, 0), a2 = kimde(o, Rol.asik, 1);
    o.oyBaslat();
    for (final i in o.oyuncular.where((i) => i != av)) {
      o.oyVer(i, av);
    }
    final r = o.oylamayiBitir();
    expect(r.avci, av);
    final vur = o.avciVur(av, a1);
    expect(vur.map((e) => e.id).toSet(), {a1, a2});
  });

  test('kazanma koşulları', () {
    final o = oyun({Rol.kurt: 2, Rol.koylu: 3});
    expect(o.kazanan(), isNull);
    o.olu.add(o.oyuncular.firstWhere((i) => o.roller[i] == Rol.koylu));
    expect(o.kazanan(), Taraf.kurtlar); // 2 kurt, 2 köylü → kurt >= diğer
  });
}
