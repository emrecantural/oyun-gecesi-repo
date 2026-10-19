import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../room/oda_servisi.dart';

/// Play Console'da tanımlanacak tüketilebilir ürün (sunucu doğrular ve tüketir).
const odaGecisiUrunKimligi = 'oda_gecisi_4s';
const _kGecis = 'oda_gecisi_id';

/// 4 saatlik oda geçişi (mobil-yayin §4.3). Hak sunucudadır; yerelde yalnız geçiş kimliği saklanır.
class OdaGecisiServisi extends ChangeNotifier {
  StreamSubscription<List<PurchaseDetails>>? _abone;
  ProductDetails? _urun;
  bool mevcut = false;
  bool mesgul = false;
  String? mesaj;

  /// Sunucunun verdiği geçiş kimliği (oda kurarken `passToken` olarak gönderilir).
  String? gecisId;

  String? get fiyat => _urun?.price;
  bool get satinAlinabilir => mevcut && _urun != null && sunucuAyarli;

  Future<void> baslat() async {
    if (!sunucuAyarli) return;
    try {
      gecisId = await SharedPreferencesAsync().getString(_kGecis);
    } catch (_) {}
    try {
      final iap = InAppPurchase.instance;
      _abone = iap.purchaseStream.listen(_guncelle, onError: (_) {});
      mevcut = await iap.isAvailable();
      if (mevcut) {
        final r = await iap.queryProductDetails({odaGecisiUrunKimligi});
        if (r.productDetails.isNotEmpty) _urun = r.productDetails.first;
      }
    } catch (_) {
      mevcut = false;
    }
    notifyListeners();
  }

  Future<void> satinAl() async {
    final u = _urun;
    if (u == null) {
      mesaj = 'Oda geçişi şu an satın alınamıyor.';
      notifyListeners();
      return;
    }
    mesgul = true;
    mesaj = null;
    notifyListeners();
    try {
      final id = await installIdAl();
      await InAppPurchase.instance.buyConsumable(
        // Sunucu tüketir (tasarım §4.3); obfuscatedAccountId = kurulum kimliği özeti.
        purchaseParam: PurchaseParam(productDetails: u, applicationUserName: kimlikOzeti(id)),
        autoConsume: false,
      );
    } catch (_) {
      mesgul = false;
      mesaj = 'Satın alma başlatılamadı.';
      notifyListeners();
    }
  }

  Future<void> _guncelle(List<PurchaseDetails> liste) async {
    for (final p in liste) {
      if (p.productID != odaGecisiUrunKimligi) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          mesgul = true;
          mesaj = 'Ödeme onay bekliyor.';
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _dogrula(p);
        case PurchaseStatus.error:
          mesgul = false;
          mesaj = 'Satın alma tamamlanamadı.';
        case PurchaseStatus.canceled:
          mesgul = false;
          mesaj = null;
      }
    }
    notifyListeners();
  }

  /// Sunucuda doğrulanana dek satın alma tamamlanmaz; Play bir sonraki açılışta yeniden bildirir (kayıp yok).
  Future<void> _dogrula(PurchaseDetails p) async {
    mesgul = true;
    mesaj = 'Satın alman doğrulanıyor…';
    notifyListeners();
    try {
      final id = await gecisBozdur(
        purchaseToken: p.verificationData.serverVerificationData,
        installId: await installIdAl(),
      );
      gecisId = id;
      try {
        await SharedPreferencesAsync().setString(_kGecis, id);
      } catch (_) {}
      mesaj = 'Oda geçişin hazır. Odayı kurabilirsin.';
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    } on OdaHatasi catch (e) {
      mesaj = hataMetni(e.kod);
    } catch (_) {
      mesaj = 'Doğrulama tamamlanamadı. Daha sonra tekrar dene; ücret iade edilir.';
    }
    mesgul = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_abone?.cancel());
    super.dispose();
  }
}

final odaGecisiProvider = Provider<OdaGecisiServisi>((ref) {
  final s = OdaGecisiServisi();
  ref.onDispose(s.dispose);
  return s;
});
