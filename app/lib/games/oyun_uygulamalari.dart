import 'alnimdaki_kim/alnimdaki_kim.dart';
import 'bilgi_yarismasi/bilgi_yarismasi.dart';
import 'birbirimizi_taniyoruz/birbirimizi_taniyoruz.dart';
import 'dilsiz_sinema/dilsiz_sinema.dart';
import 'dogruluk_cesaret/dogruluk_cesaret.dart';
import 'en_olasi_kim/en_olasi_kim.dart';
import 'gece_yarisi_sorgusu/gece_yarisi_sorgusu.dart';
import 'geri_sayimi_yakala/geri_sayimi_yakala.dart';
import 'gizli_hediye/gizli_hediye.dart';
import 'hic_yapmadim_ki/hic_yapmadim_ki.dart';
import 'kelime_zinciri/kelime_zinciri.dart';
import 'kim_casus/kim_casus.dart';
import 'oyun_uygulamasi.dart';
import 'tek_kelime/tek_kelime.dart';
import 'yasak_kelime/yasak_kelime.dart';
import 'yeni_yil_kehaneti/yeni_yil_kehaneti.dart';

/// Çalışan (uygulanmış) oyunlar; kayıt dışı olanlar "Yakında" görünür.
final Map<String, OyunUygulamasi> _uygulamalar = {
  hicYapmadimKi.id: hicYapmadimKi,
  dogrulukCesaret.id: dogrulukCesaret,
  enOlasiKim.id: enOlasiKim,
  geriSayimiYakala.id: geriSayimiYakala,
  gizliHediye.id: gizliHediye,
  kimCasus.id: kimCasus,
  geceYarisiSorgusu.id: geceYarisiSorgusu,
  yeniYilKehaneti.id: yeniYilKehaneti,
  alnimdakiKim.id: alnimdakiKim,
  birbirimiziTaniyoruz.id: birbirimiziTaniyoruz,
  bilgiYarismasi.id: bilgiYarismasi,
  tekKelime.id: tekKelime,
  yasakKelime.id: yasakKelime,
  dilsizSinema.id: dilsizSinema,
  kelimeZinciri.id: kelimeZinciri,
};

OyunUygulamasi? oyunUygulamasi(String id) => _uygulamalar[id];
