import '../dilsiz_sinema/dilsiz_sinema.dart';
import '../oyun_uygulamasi.dart';

/// 25 Şarkı Mırıldan: 09 ile aynı tur motoru; yalnız ifade türü ve içerik farklı.
/// Uygulama mikrofon açmaz, ses kaydetmez; yalnız şarkı adı metni gösterilir.
final sarkiMirildan = OyunUygulamasi(
  id: '25',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'takim',
      baslik: 'Takım',
      secenekler: {'2': '2', '3': '3', '4': '4'},
      varsayilan: '2',
    ),
    AyarSatiri(
      anahtar: 'sure',
      baslik: 'Tur süresi',
      secenekler: {'45': '45 sn', '60': '60 sn', '90': '90 sn'},
      varsayilan: '60',
    ),
    AyarSatiri(
      anahtar: 'tur',
      baslik: 'Tur / takım',
      secenekler: {'2': '2', '3': '3', '4': '4', '5': '5'},
      varsayilan: '3',
    ),
    AyarSatiri(
      anahtar: 'kategori',
      baslik: 'Kategori',
      secenekler: {
        'karisik': 'Karışık',
        'cocuk': 'Çocuk şarkıları',
        'turku': 'Türkü',
        'yilbasi': 'Yılbaşı',
      },
      varsayilan: 'karisik',
    ),
    AyarSatiri(
      anahtar: 'ifade',
      baslik: 'İfade',
      secenekler: {
        'karisik': 'Karışık',
        'mirildan': 'Mırıldan',
        'islik': 'Islık',
        'tempo': 'Tempo',
      },
      varsayilan: 'karisik',
    ),
    AyarSatiri(
      anahtar: 'pas',
      baslik: 'Pas',
      secenekler: {'3': '3 hak', '-1': 'Sınırsız', '0': 'Yok'},
      varsayilan: '3',
    ),
    AyarSatiri(
      anahtar: 'ceza',
      baslik: 'Pas cezası',
      secenekler: {'0': '0', '1': '−1'},
      varsayilan: '0',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => DilsizSinemaEkrani(
    oturum: oturum,
    yap: const DilsizYapilandirma(
      oyunKodu: '25',
      dosya: '25-sarki-mirildan',
      ogeTur: 'eser',
      rozet: 'Müzik Kulağı',
      ifadeli: true,
      hazirIpucu: 'Söz yok, sadece ses!',
    ),
  ),
);
