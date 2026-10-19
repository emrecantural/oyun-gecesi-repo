import 'hic_yapmadim_ki/hic_yapmadim_ki.dart';
import 'oyun_uygulamasi.dart';

/// Çalışan (uygulanmış) oyunlar; kayıt dışı olanlar "Yakında" görünür.
final Map<String, OyunUygulamasi> _uygulamalar = {
  hicYapmadimKi.id: hicYapmadimKi,
};

OyunUygulamasi? oyunUygulamasi(String id) => _uygulamalar[id];
