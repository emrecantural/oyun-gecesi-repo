import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../app/premium.dart';
import 'reklam_kurallari.dart';

/// Reklam birimi kimlikleri derleme ayarından gelir; varsayılan Google TEST kimlikleridir (D-039).
/// Üretim kimlikleri yalnız kullanıcının açık yetkisiyle `--dart-define` ile verilir.
const _bannerKimligi = String.fromEnvironment(
  'ADMOB_BANNER_ID',
  defaultValue: 'ca-app-pub-3940256099942544/9214589741',
);
const _gecisKimligi = String.fromEnvironment(
  'ADMOB_INTERSTITIAL_ID',
  defaultValue: 'ca-app-pub-3940256099942544/1033173712',
);

/// Rıza (UMP) + reklam yaşam döngüsü. Reklam yoksa/hata varsa uygulama sessizce akar.
class ReklamServisi extends ChangeNotifier {
  ReklamServisi(this._premium, {DateTime Function()? simdi}) : _simdi = simdi ?? DateTime.now;

  final bool Function() _premium;
  final DateTime Function() _simdi;
  final GecisSikligi _siklik = GecisSikligi();

  bool _hazir = false;
  bool _gizlilikSecenegi = false;
  InterstitialAd? _gecis;
  int _gecisDeneme = 0;
  DateTime? _oyunBasi;

  /// Rıza alındı ve SDK başlatıldı.
  bool get hazir => _hazir;
  bool get gizlilikSecenekleriGerekli => _gizlilikSecenegi;

  /// Premium değilse ve yılbaşı penceresinde değilse reklam istenebilir.
  bool get reklamIstenebilir => _hazir && !_premium() && !yilbasiPenceresi(_simdi());

  Future<void> baslat() async {
    if (_hazir) return;
    final tamamla = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
            final durum = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
            _gizlilikSecenegi = durum == PrivacyOptionsRequirementStatus.required;
            if (await ConsentInformation.instance.canRequestAds()) {
              await MobileAds.instance.initialize();
              _hazir = true;
              notifyListeners();
              unawaited(_gecisYukle());
            }
          } catch (_) {
            // Rıza/başlatma hatası: reklam yok, oyun akar.
          }
          if (!tamamla.isCompleted) tamamla.complete();
        },
        (_) {
          if (!tamamla.isCompleted) tamamla.complete();
        },
      );
      await tamamla.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    } catch (_) {
      // Eklenti yok (test) veya platform hatası.
    }
  }

  Future<void> gizlilikSecenekleriniAc() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {}
  }

  /// Bir oyun başladı (süre ölçümü için).
  void oyunBasladi() => _oyunBasi = _simdi();

  /// Oyun sonuna kadar oynandı. Kural uygunsa geçiş reklamı gösterilir.
  void oyunTamamlandi() {
    final basi = _oyunBasi;
    _oyunBasi = null;
    _siklik.oyunTamamlandi(basi == null ? const Duration(minutes: 5) : _simdi().difference(basi));
    if (!reklamIstenebilir || !_siklik.gosterilebilir(_simdi())) return;
    final reklam = _gecis;
    if (reklam == null) {
      unawaited(_gecisYukle());
      return;
    }
    _gecis = null;
    reklam.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (ad) {
        _siklik.gosterildi(_simdi());
        unawaited(ad.dispose());
        unawaited(_gecisYukle());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(ad.dispose());
      },
    );
    unawaited(reklam.show());
  }

  Future<void> _gecisYukle() async {
    if (!reklamIstenebilir || _gecis != null) return;
    try {
      await InterstitialAd.load(
        adUnitId: _gecisKimligi,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _gecis = ad;
            _gecisDeneme = 0;
          },
          onAdFailedToLoad: (_) {
            // En çok 2 yeniden deneme, üstel geri çekilme.
            if (_gecisDeneme < 2) {
              final bekle = Duration(seconds: 5 << _gecisDeneme);
              _gecisDeneme++;
              Timer(bekle, () => unawaited(_gecisYukle()));
            }
          },
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_gecis?.dispose());
    super.dispose();
  }
}

final reklamProvider = Provider<ReklamServisi>((ref) {
  final s = ReklamServisi(() => ref.read(premiumProvider));
  ref.onDispose(s.dispose);
  return s;
});

/// Alt banner (yalnız ana sayfa, oyun detayı, ayarlar). Yüklenmezse alan kapanır.
class ReklamBandi extends ConsumerStatefulWidget {
  const ReklamBandi({super.key});

  @override
  ConsumerState<ReklamBandi> createState() => _ReklamBandiDurum();
}

class _ReklamBandiDurum extends ConsumerState<ReklamBandi> {
  BannerAd? _banner;
  bool _yuklendi = false;
  bool _istendi = false;

  Future<void> _yukle(int genislik) async {
    _istendi = true;
    try {
      final boyut = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(genislik);
      if (boyut == null || !mounted) return;
      final b = BannerAd(
        adUnitId: _bannerKimligi,
        size: boyut,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _yuklendi = true);
          },
          onAdFailedToLoad: (ad, _) {
            unawaited(ad.dispose());
            if (mounted) setState(() => _banner = null);
          },
        ),
      );
      _banner = b;
      await b.load();
    } catch (_) {
      _banner = null;
    }
  }

  @override
  void dispose() {
    unawaited(_banner?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servis = ref.watch(reklamProvider);
    final premium = ref.watch(premiumProvider);
    return ListenableBuilder(
      listenable: servis,
      builder: (context, _) {
        if (premium || !servis.reklamIstenebilir) return const SizedBox.shrink();
        if (!_istendi) {
          final w = MediaQuery.of(context).size.width.truncate();
          unawaited(_yukle(w));
        }
        final b = _banner;
        if (b == null || !_yuklendi) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: Container(
            alignment: Alignment.center,
            width: b.size.width.toDouble(),
            height: b.size.height.toDouble(),
            child: AdWidget(ad: b),
          ),
        );
      },
    );
  }
}
