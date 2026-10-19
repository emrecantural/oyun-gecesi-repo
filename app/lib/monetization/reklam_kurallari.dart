/// Reklam sıklık kuralları (mobil-yayin-ve-para-kazanma.md §3.2). Saf mantık; plugin yok.

/// Yılbaşı gecesi penceresi: 31 Ara 20:00 – 01 Oca 02:00 (cihaz yerel saati). D-040.
bool yilbasiPenceresi(DateTime t) {
  if (t.month == 12 && t.day == 31 && t.hour >= 20) return true;
  if (t.month == 1 && t.day == 1 && t.hour < 2) return true;
  return false;
}

/// Geçiş reklamı sıklık sınırlayıcısı.
/// - İlk oyun reklamsız: ilk geçiş reklamı ikinci tamamlanan oyundan sonra.
/// - İki reklam arası en az 4 dakika.
/// - Günde en çok 12 geçiş reklamı.
/// - 3 dakikadan kısa oyunlar sayaca 0,5 yazar.
class GecisSikligi {
  GecisSikligi({
    this.enAzAralik = const Duration(minutes: 4),
    this.gunlukSinir = 12,
    this.ilkReklamOyunSayisi = 2,
  });

  final Duration enAzAralik;
  final int gunlukSinir;
  final int ilkReklamOyunSayisi;

  double _oyunSayaci = 0;
  DateTime? _sonReklam;
  int _gunlukSayi = 0;
  DateTime? _gun;

  double get oyunSayaci => _oyunSayaci;

  /// Tamamlanan bir oyunu yazar. [sure] oyunun süresi (3 dk altı yarım sayılır).
  void oyunTamamlandi(Duration sure) {
    _oyunSayaci += sure < const Duration(minutes: 3) ? 0.5 : 1;
  }

  bool gosterilebilir(DateTime simdi) {
    _gunuYenile(simdi);
    if (_oyunSayaci < ilkReklamOyunSayisi) return false;
    if (_gunlukSayi >= gunlukSinir) return false;
    final son = _sonReklam;
    if (son != null && simdi.difference(son) < enAzAralik) return false;
    return true;
  }

  /// Reklam gösterildi: aralık sayacı reklam kapandıktan sonra başlar.
  void gosterildi(DateTime kapanisZamani) {
    _gunuYenile(kapanisZamani);
    _gunlukSayi++;
    _sonReklam = kapanisZamani;
  }

  void _gunuYenile(DateTime t) {
    final g = DateTime(t.year, t.month, t.day);
    if (_gun != g) {
      _gun = g;
      _gunlukSayi = 0;
    }
  }
}
