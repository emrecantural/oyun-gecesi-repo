import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/premium.dart';
import 'icerik.dart';

/// `--dart-define=ICERIK_TASLAK=true` ile taslak (editör onaysız) satırlar
/// pakete alınır. Varsayılan false: yalnız `durum=onayli`.
const bool icerikTaslakDahil =
    bool.fromEnvironment('ICERIK_TASLAK', defaultValue: false);

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
  return premium ? hepsi : hepsi.where((o) => o.ucretsiz).toList();
});

/// Paket planındaki bölme birimi dosyaya göre değişir (varsayılan: seviye).
String Function(IcerikOgesi)? grupAnahtariIcin(String dosya) {
  if (dosya.startsWith('02-')) return (o) => o.seviye; // mekân (düzeltilecek)
  return null;
}
