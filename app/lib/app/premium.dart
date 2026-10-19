import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium sahipliği. Satın alma entegrasyonu gelene kadar (monetization/)
/// yalnız geliştirme anahtarıyla değişir; varsayılan ücretsiz.
class PremiumNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void ayarla(bool deger) => state = deger;
}

final premiumProvider =
    NotifierProvider<PremiumNotifier, bool>(PremiumNotifier.new);
