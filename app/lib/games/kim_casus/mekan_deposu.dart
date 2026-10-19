import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/premium.dart';
import '../../content/icerik.dart';
import '../../content/icerik_deposu.dart';
import 'casus_mantik.dart';

/// Ücretsiz pakette sabit (sezon vitrini) mekânlar; paket-plani.md 02.
const sabitUcretsizMekanlar = ['Yılbaşı Sofrası', 'Havai Fişek Meydanı'];
const ucretsizMekanSayisi = 12;

/// CSV öğelerinden mekânları kurar. `rol` ve `ipucu` satırlarında `seviye`
/// alanı mekân adıdır. Ücretsiz: sabit iki mekân + sıradaki ilk 10.
List<Mekan> mekanlariKur(List<IcerikOgesi> ogeler) {
  final mekanSatirlari = ogeler.where((o) => o.tur == 'mekan').toList();
  final roller = <String, List<String>>{};
  final ipuclari = <String, List<String>>{};
  for (final o in ogeler) {
    if (o.tur == 'rol') roller.putIfAbsent(o.seviye, () => []).add(o.metin);
    if (o.tur == 'ipucu') ipuclari.putIfAbsent(o.seviye, () => []).add(o.metin);
  }
  final ucretsiz = <String>{...sabitUcretsizMekanlar};
  for (final m in mekanSatirlari) {
    if (ucretsiz.length >= ucretsizMekanSayisi) break;
    ucretsiz.add(m.metin);
  }
  return [
    for (final m in mekanSatirlari)
      if ((roller[m.metin] ?? const []).isNotEmpty)
        Mekan(
          id: m.id,
          ad: m.metin,
          kategori: m.ek,
          roller: roller[m.metin]!,
          ipuclari: ipuclari[m.metin] ?? const [],
          ucretsiz: ucretsiz.contains(m.metin),
        ),
  ];
}

/// Premium sahibi tüm mekânları, diğerleri ücretsiz paketi alır.
final mekanlarProvider = FutureProvider<List<Mekan>>((ref) async {
  final premium = ref.watch(premiumProvider);
  final ham = await ref.watch(icerikHamProvider('02-kim-casus').future);
  final hepsi = mekanlariKur(ham);
  return premium ? hepsi : hepsi.where((m) => m.ucretsiz).toList();
});

String kategoriAdi(String kod) => switch (kod) {
      'kamu' => 'Kamu',
      'ulasim' => 'Ulaşım',
      'eglence' => 'Eğlence',
      'yeme' => 'Yeme-içme',
      'dis' => 'Açık hava',
      'alisveris' => 'Alışveriş',
      'hizmet' => 'Hizmet',
      _ => kod.isEmpty ? '' : kod[0].toUpperCase() + kod.substring(1),
    };
