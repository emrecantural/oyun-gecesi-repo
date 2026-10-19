import 'package:flutter/material.dart';

enum OyunKategori { parti, konusma, kelime, bilgi, cekilis }

extension OyunKategoriAd on OyunKategori {
  String get ad => switch (this) {
        OyunKategori.parti => 'Parti',
        OyunKategori.konusma => 'Sohbet',
        OyunKategori.kelime => 'Kelime',
        OyunKategori.bilgi => 'Bilgi',
        OyunKategori.cekilis => 'Çekiliş',
      };
}

/// Çıkış kümesindeki bir oyunun katalog kaydı (Tablo A).
@immutable
class OyunBilgisi {
  const OyunBilgisi({
    required this.id,
    required this.ad,
    required this.kisa,
    required this.kategori,
    required this.min,
    required this.max,
    required this.ikon,
    this.sadeceOda = false,
  });

  final String id;
  final String ad;
  final String kisa;
  final OyunKategori kategori;
  final int min;
  final int max;
  final IconData ikon;

  /// Yalnız çevrimiçi odada oynanır (ör. Tombala).
  final bool sadeceOda;

  String get kisiAraligi => min == max ? '$min kişi' : '$min–$max kişi';
}

const oyunlar = <OyunBilgisi>[
  OyunBilgisi(id: '01', ad: 'Tombala', kisa: 'Sayılar çekilir, kartını doldur.', kategori: OyunKategori.cekilis, min: 2, max: 30, ikon: Icons.grid_view_rounded, sadeceOda: true),
  OyunBilgisi(id: '02', ad: 'Kim Casus?', kisa: 'Mekânı bilmeyen casusu bul.', kategori: OyunKategori.parti, min: 3, max: 12, ikon: Icons.person_search_rounded),
  OyunBilgisi(id: '03', ad: 'Köy ve Kurtlar', kisa: 'Gece kurtlar, gündüz köylüler.', kategori: OyunKategori.parti, min: 6, max: 20, ikon: Icons.nights_stay_rounded),
  OyunBilgisi(id: '05', ad: 'Hiç Yapmadım Ki', kisa: 'Yaptıysan parmağını indir.', kategori: OyunKategori.konusma, min: 3, max: 20, ikon: Icons.back_hand_rounded),
  OyunBilgisi(id: '06', ad: 'Doğruluk mu Cesaret mi?', kisa: 'Seç, yap ya da söyle.', kategori: OyunKategori.konusma, min: 2, max: 12, ikon: Icons.help_center_rounded),
  OyunBilgisi(id: '07', ad: 'En Olası Kim?', kisa: 'Masadan birini seç, oyları gör.', kategori: OyunKategori.konusma, min: 3, max: 20, ikon: Icons.how_to_vote_rounded),
  OyunBilgisi(id: '09', ad: 'Dilsiz Sinema', kisa: 'Konuşmadan anlat.', kategori: OyunKategori.parti, min: 4, max: 16, ikon: Icons.theater_comedy_rounded),
  OyunBilgisi(id: '10', ad: 'Yasak Kelime', kisa: 'Yasaklı sözcükleri söyleme.', kategori: OyunKategori.kelime, min: 4, max: 14, ikon: Icons.block_rounded),
  OyunBilgisi(id: '11', ad: 'Tek Kelime', kisa: 'Tek sözcükle ipucu ver.', kategori: OyunKategori.kelime, min: 3, max: 8, ikon: Icons.spellcheck_rounded),
  OyunBilgisi(id: '13', ad: 'Kelime Zinciri', kisa: 'Son harfle yeni kelime.', kategori: OyunKategori.kelime, min: 2, max: 15, ikon: Icons.link_rounded),
  OyunBilgisi(id: '14', ad: 'Birbirimizi Tanıyoruz', kisa: 'Arkadaşını ne kadar tanıyorsun?', kategori: OyunKategori.konusma, min: 2, max: 12, ikon: Icons.people_alt_rounded),
  OyunBilgisi(id: '15', ad: 'Bilgi Yarışması', kisa: 'Hızlı sorular, hızlı cevaplar.', kategori: OyunKategori.bilgi, min: 2, max: 30, ikon: Icons.quiz_rounded),
  OyunBilgisi(id: '18', ad: 'Geri Sayımı Yakala', kisa: 'Tam zamanında bas.', kategori: OyunKategori.parti, min: 2, max: 30, ikon: Icons.timer_rounded),
  OyunBilgisi(id: '23', ad: 'Yeni Yıl Kehaneti', kisa: 'Yeni yılın falına bak.', kategori: OyunKategori.cekilis, min: 1, max: 30, ikon: Icons.auto_awesome_rounded),
  OyunBilgisi(id: '24', ad: 'Gizli Hediye Çekilişi', kisa: 'Kim kime hediye alacak?', kategori: OyunKategori.cekilis, min: 3, max: 50, ikon: Icons.card_giftcard_rounded),
  OyunBilgisi(id: '25', ad: 'Şarkı Mırıldan', kisa: 'Mırılda, bulsunlar.', kategori: OyunKategori.parti, min: 4, max: 12, ikon: Icons.music_note_rounded),
  OyunBilgisi(id: '27', ad: 'Gece Yarısı Sorgusu', kisa: 'İki kişilik gizemli sorgu.', kategori: OyunKategori.konusma, min: 2, max: 2, ikon: Icons.nightlight_round),
  OyunBilgisi(id: '29', ad: 'Alnımdaki Kim?', kisa: 'Alnındaki kişiyi tahmin et.', kategori: OyunKategori.parti, min: 3, max: 14, ikon: Icons.face_rounded),
];

OyunBilgisi? oyunBul(String id) {
  for (final o in oyunlar) {
    if (o.id == id) return o;
  }
  return null;
}
