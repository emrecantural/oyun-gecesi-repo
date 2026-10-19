import 'dogruluk_cesaret/dogruluk_cesaret.dart';
import 'en_olasi_kim/en_olasi_kim.dart';
import 'geri_sayimi_yakala/geri_sayimi_yakala.dart';
import 'gizli_hediye/gizli_hediye.dart';
import 'hic_yapmadim_ki/hic_yapmadim_ki.dart';
import 'oyun_uygulamasi.dart';

/// Çalışan (uygulanmış) oyunlar; kayıt dışı olanlar "Yakında" görünür.
final Map<String, OyunUygulamasi> _uygulamalar = {
  hicYapmadimKi.id: hicYapmadimKi,
  dogrulukCesaret.id: dogrulukCesaret,
  enOlasiKim.id: enOlasiKim,
  geriSayimiYakala.id: geriSayimiYakala,
  gizliHediye.id: gizliHediye,
};

OyunUygulamasi? oyunUygulamasi(String id) => _uygulamalar[id];
