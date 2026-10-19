import 'dogruluk_cesaret/dogruluk_cesaret.dart';
import 'en_olasi_kim/en_olasi_kim.dart';
import 'hic_yapmadim_ki/hic_yapmadim_ki.dart';
import 'oyun_uygulamasi.dart';

/// Çalışan (uygulanmış) oyunlar; kayıt dışı olanlar "Yakında" görünür.
final Map<String, OyunUygulamasi> _uygulamalar = {
  hicYapmadimKi.id: hicYapmadimKi,
  dogrulukCesaret.id: dogrulukCesaret,
  enOlasiKim.id: enOlasiKim,
};

OyunUygulamasi? oyunUygulamasi(String id) => _uygulamalar[id];
