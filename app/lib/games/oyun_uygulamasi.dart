import 'package:flutter/widgets.dart';

import '../shell/ortak/oyuncular.dart';
import 'registry.dart';

/// G4 ayar satırı: `secenekler` sırayla gösterilir, [varsayilan] işaretli.
class AyarSatiri {
  const AyarSatiri({
    required this.anahtar,
    required this.baslik,
    required this.secenekler,
    required this.varsayilan,
    this.gelismis = false,
  });

  final String anahtar;
  final String baslik;

  /// değer → etiket
  final Map<String, String> secenekler;
  final String varsayilan;
  final bool gelismis;
}

/// Bir oyunun oturumu: katalog kaydı + oyuncular + seçilen ayarlar.
class OyunOturumu {
  const OyunOturumu({
    required this.oyun,
    required this.oyuncular,
    required this.ayarlar,
  });

  final OyunBilgisi oyun;
  final List<Oyuncu> oyuncular;
  final Map<String, String> ayarlar;

  String ayar(String anahtar) => ayarlar[anahtar] ?? '';
  int ayarInt(String anahtar) => int.tryParse(ayar(anahtar)) ?? 0;
}

typedef OyunEkraniYap = Widget Function(
    BuildContext context, OyunOturumu oturum);

/// Çalışan bir oyunun uygulaması.
class OyunUygulamasi {
  const OyunUygulamasi({
    required this.id,
    required this.ayarlar,
    required this.ekran,
  });

  final String id;
  final List<AyarSatiri> ayarlar;
  final OyunEkraniYap ekran;
}
