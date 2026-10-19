import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/premium.dart';
import 'icerik.dart';

/// `--dart-define=ICERIK_TASLAK=true` ile taslak (editör onaysız) satırlar
/// pakete alınır. Varsayılan false: yalnız `durum=onayli`.
const bool icerikTaslakDahil =
    bool.fromEnvironment('ICERIK_TASLAK', defaultValue: false);

/// Paket filtresiz, ham içerik (özel bölme kuralı olan oyunlar için).
final icerikHamProvider =
    FutureProvider.family<List<IcerikOgesi>, String>((ref, dosya) async {
  final csv = await rootBundle.loadString('assets/icerik/$dosya.csv');
  return icerikAyristir(csv, taslakDahil: icerikTaslakDahil);
});

/// Tüm içeriği ([premium] false ise ücretsiz havuzu) yükler.
final icerikProvider =
    FutureProvider.family<List<IcerikOgesi>, String>((ref, dosya) async {
  final premium = ref.watch(premiumProvider);
  final csv = await rootBundle.loadString('assets/icerik/$dosya.csv');
  final hepsi = icerikAyristir(
    csv,
    taslakDahil: icerikTaslakDahil,
    grupAnahtari: grupAnahtariIcin(dosya),
  );
  final hepsiAcik = premium || tamamenUcretsiz(dosya);
  return hepsiAcik ? hepsi : hepsi.where((o) => o.ucretsiz).toList();
});

/// Çekirdek mekaniği tamamen ücretsiz oyunlar (paket-plani.md): 01, 03, 24.
bool tamamenUcretsiz(String dosya) =>
    dosya.startsWith('01-') || dosya.startsWith('03-') || dosya.startsWith('24-');

/// Paket planındaki bölme birimi dosyaya göre değişir (varsayılan: seviye).
String Function(IcerikOgesi)? grupAnahtariIcin(String dosya) {
  return null;
}
