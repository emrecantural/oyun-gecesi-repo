import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../games/oyun_uygulamasi.dart';
import '../../monetization/reklam_servisi.dart';
import 'oyuncular.dart';

/// Masadaki oyuncular (oyunlar arasında korunur, yalnız bellekte).
class MasaNotifier extends Notifier<List<Oyuncu>> {
  @override
  List<Oyuncu> build() => const [];

  int _sonrakiStil() {
    final kullanilan = state.map((o) => o.stilNo).toSet();
    for (var i = 0; i < oyuncuStilleri.length; i++) {
      if (!kullanilan.contains(i)) return i;
    }
    return state.length;
  }

  void ekle(String ad) {
    final bos = ad.trim().isEmpty;
    final varsayilan = 'Oyuncu ${state.length + 1}';
    final yeniAd = benzersizAd(bos ? varsayilan : ad, state.map((o) => o.ad));
    state = [
      ...state,
      Oyuncu(id: _bosId(), ad: yeniAd, stilNo: _sonrakiStil()),
    ];
  }

  int _bosId() {
    final idler = state.map((o) => o.id).toSet();
    var n = 1;
    while (idler.contains(n)) {
      n++;
    }
    return n;
  }

  void adDegistir(int id, String ad) {
    final diger = state.where((o) => o.id != id).map((o) => o.ad);
    final temiz = ad.trim();
    if (temiz.isEmpty) return;
    final yeni = benzersizAd(temiz, diger);
    state = [for (final o in state) o.id == id ? o.adiDegistir(yeni) : o];
  }

  void sil(int id) => state = state.where((o) => o.id != id).toList();

  void karistir() => state = [...state]..shuffle();
}

final masaProvider =
    NotifierProvider<MasaNotifier, List<Oyuncu>>(MasaNotifier.new);

class OturumNotifier extends Notifier<OyunOturumu?> {
  @override
  OyunOturumu? build() => null;

  void baslat(OyunOturumu oturum) {
    state = oturum;
    ref.read(reklamProvider).oyunBasladi();
  }

  /// Oyundan vazgeçildi (reklam yok).
  void bitir() => state = null;

  /// Oyun sonuna kadar oynandı: sıklık sayacı işler, kural uygunsa geçiş reklamı gösterilir.
  void tamamlandi() {
    ref.read(reklamProvider).oyunTamamlandi();
    state = null;
  }
}

final oturumProvider =
    NotifierProvider<OturumNotifier, OyunOturumu?>(OturumNotifier.new);
