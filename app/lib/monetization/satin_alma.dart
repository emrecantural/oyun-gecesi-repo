import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/premium.dart';

/// Play Console'da tanımlanacak tek seferlik (tüketilmez) ürün kimliği.
const premiumUrunKimligi = 'premium';
const _kHak = 'premium_hak';

enum SatinAlmaDurumu { bosta, mesgul, bekliyor, hata }

/// Premium satın alma (non-consumable). Hak kaynağı Play kaydıdır; yerelde son bilinen hak saklanır.
/// Bilinen sınır: iade edilen satın alma için iptal sorgusu henüz yok (yalnız geri yükleme).
class SatinAlmaServisi extends ChangeNotifier {
  SatinAlmaServisi(this._ref);
  final Ref _ref;

  StreamSubscription<List<PurchaseDetails>>? _abone;
  ProductDetails? _urun;
  SatinAlmaDurumu durum = SatinAlmaDurumu.bosta;
  String? mesaj;
  bool mevcut = false;

  /// Mağazadan gelen yerelleştirilmiş fiyat (ürün tanımlıysa).
  String? get fiyat => _urun?.price;
  bool get satinAlinabilir => mevcut && _urun != null;

  Future<void> baslat() async {
    try {
      if (await SharedPreferencesAsync().getBool(_kHak) == true) {
        _ref.read(premiumProvider.notifier).ayarla(true);
      }
    } catch (_) {}
    try {
      final iap = InAppPurchase.instance;
      _abone = iap.purchaseStream.listen(_guncelle, onError: (_) {
        durum = SatinAlmaDurumu.hata;
        mesaj = 'Satın alma durumu okunamadı.';
        notifyListeners();
      });
      mevcut = await iap.isAvailable();
      if (mevcut) {
        final r = await iap.queryProductDetails({premiumUrunKimligi});
        if (r.productDetails.isNotEmpty) _urun = r.productDetails.first;
        await iap.restorePurchases();
      }
    } catch (_) {
      mevcut = false;
    }
    notifyListeners();
  }

  Future<void> satinAl() async {
    final u = _urun;
    if (u == null) {
      mesaj = 'Premium şu an satın alınamıyor.';
      durum = SatinAlmaDurumu.hata;
      notifyListeners();
      return;
    }
    durum = SatinAlmaDurumu.mesgul;
    mesaj = null;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: u));
    } catch (_) {
      durum = SatinAlmaDurumu.hata;
      mesaj = 'Satın alma başlatılamadı.';
      notifyListeners();
    }
  }

  Future<void> geriYukle() async {
    durum = SatinAlmaDurumu.mesgul;
    mesaj = null;
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
      // Sonuç purchaseStream'den gelir; gelmezse kısa süre sonra boşta.
      Timer(const Duration(seconds: 8), () {
        if (durum == SatinAlmaDurumu.mesgul) {
          durum = SatinAlmaDurumu.bosta;
          mesaj = 'Geri yüklenecek bir satın alma bulunamadı.';
          notifyListeners();
        }
      });
    } catch (_) {
      durum = SatinAlmaDurumu.hata;
      mesaj = 'Geri yükleme başarısız.';
      notifyListeners();
    }
  }

  Future<void> _guncelle(List<PurchaseDetails> liste) async {
    for (final p in liste) {
      if (p.productID != premiumUrunKimligi) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          durum = SatinAlmaDurumu.bekliyor;
          mesaj = 'Ödeme onay bekliyor.';
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _ref.read(premiumProvider.notifier).ayarla(true);
          durum = SatinAlmaDurumu.bosta;
          mesaj = 'Premium açık. Teşekkürler!';
          try {
            await SharedPreferencesAsync().setBool(_kHak, true);
          } catch (_) {}
        case PurchaseStatus.error:
          durum = SatinAlmaDurumu.hata;
          mesaj = 'Satın alma tamamlanamadı.';
        case PurchaseStatus.canceled:
          durum = SatinAlmaDurumu.bosta;
          mesaj = null;
      }
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_abone?.cancel());
    super.dispose();
  }
}

final satinAlmaProvider = Provider<SatinAlmaServisi>((ref) {
  final s = SatinAlmaServisi(ref);
  ref.onDispose(s.dispose);
  return s;
});
