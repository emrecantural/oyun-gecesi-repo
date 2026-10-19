import 'dart:math';

/// 20 Hafıza Düellosu (Sırayla): saf oyun mantığı. Puanlar yarım birim (x2) tutulur.
enum HamleSonucu { reddedildi, acildi, eslesti, uyusmadi }

class HafizaKart {
  HafizaKart(this.sembol);
  final int sembol;
  bool acik = false;
  bool eslesti = false;
  int? sahip;
}

class HafizaOyuncu {
  HafizaOyuncu(this.id);
  final int id;
  int puan2 = 0; // 1 puan = 2
  int seri = 0;
  int enUzunSeri = 0;
  int hata = 0;
  int hamle = 0; // ikinci kart açılışı
  int cift = 0;
  bool ayrildi = false;
}

class HafizaSira {
  const HafizaSira(this.oyuncuId, this.sira, this.puan2, this.enUzunSeri);
  final int oyuncuId;
  final int sira;
  final int puan2;
  final int enUzunSeri;
}

/// "2,5" biçimi (ondalık virgül).
String puanYaz(int puan2) =>
    puan2.isEven ? '${puan2 ~/ 2}' : '${puan2 ~/ 2},5';

/// Seri bonuslu çift puanı (x2): 1. = 1, 2. = 1,5, 3.+ = 2.
int ciftPuani2(int seri, bool bonus) =>
    !bonus ? 2 : (seri <= 1 ? 2 : (seri == 2 ? 3 : 4));

/// [ciftSayisi] çift için karıştırılmış sembol dizilimi (Fisher–Yates).
List<int> dizilimUret(int ciftSayisi, List<int> semboller, Random rng) {
  final secilen = [...semboller]..shuffle(rng);
  final kartlar = <int>[
    for (final s in secilen.take(ciftSayisi)) ...[s, s],
  ];
  for (var i = kartlar.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = kartlar[i];
    kartlar[i] = kartlar[j];
    kartlar[j] = t;
  }
  return kartlar;
}

class HafizaOyunu {
  HafizaOyunu({
    required List<int> oyuncuIdleri,
    required List<int> dizilim,
    this.seriBonus = true,
  })  : kartlar = [for (final s in dizilim) HafizaKart(s)],
        oyuncular = [for (final id in oyuncuIdleri) HafizaOyuncu(id)];

  final List<HafizaKart> kartlar;
  final List<HafizaOyuncu> oyuncular;
  final bool seriBonus;
  int siraIdx = 0;
  final List<int> acik = [];

  HafizaOyuncu get siradaki => oyuncular[siraIdx];
  List<HafizaOyuncu> get aktif => [for (final o in oyuncular) if (!o.ayrildi) o];
  int get kalanKart => kartlar.where((k) => !k.eslesti).length;
  bool get bitti => kalanKart == 0;

  /// Ardışık açık uyuşmaz çift kapatılana kadar giriş kilitli.
  bool get kilitli => acik.length >= 2;

  HamleSonucu ac(int idx) {
    if (bitti || idx < 0 || idx >= kartlar.length || kilitli) {
      return HamleSonucu.reddedildi;
    }
    final k = kartlar[idx];
    if (k.eslesti || k.acik) return HamleSonucu.reddedildi;
    k.acik = true;
    acik.add(idx);
    if (acik.length == 1) return HamleSonucu.acildi;
    final o = siradaki;
    o.hamle++;
    final a = kartlar[acik[0]], b = kartlar[acik[1]];
    if (a.sembol == b.sembol) {
      _esle(o);
      return HamleSonucu.eslesti;
    }
    o.hata++;
    o.seri = 0;
    return HamleSonucu.uyusmadi;
  }

  void _esle(HafizaOyuncu o) {
    o.seri++;
    if (o.seri > o.enUzunSeri) o.enUzunSeri = o.seri;
    o.puan2 += ciftPuani2(o.seri, seriBonus);
    o.cift++;
    for (final i in acik) {
      kartlar[i]
        ..eslesti = true
        ..sahip = o.id;
    }
    acik.clear();
  }

  /// Uyuşmayan açık çifti kapatır ve sırayı geçirir.
  void kapat() {
    for (final i in acik) {
      kartlar[i].acik = false;
    }
    acik.clear();
    sonraki();
  }

  /// Süre doldu: açık tek kart kapanır (hata sayılır), seri biter, sıra geçer.
  void sureDoldu() {
    final o = siradaki;
    if (acik.length == 1) o.hata++;
    o.seri = 0;
    for (final i in acik) {
      kartlar[i].acik = false;
    }
    acik.clear();
    sonraki();
  }

  void sonraki() {
    if (aktif.isEmpty) return;
    do {
      siraIdx = (siraIdx + 1) % oyuncular.length;
    } while (oyuncular[siraIdx].ayrildi);
  }

  /// Son 2 kart: sırası olana otomatik yazılır (seri dahil). Uygulandıysa true.
  bool sonCiftiOtomatik() {
    final kalan = [
      for (var i = 0; i < kartlar.length; i++)
        if (!kartlar[i].eslesti) i
    ];
    if (kalan.length != 2 || acik.isNotEmpty) return false;
    if (kartlar[kalan[0]].sembol != kartlar[kalan[1]].sembol) return false;
    acik.addAll(kalan);
    for (final i in kalan) {
      kartlar[i].acik = true;
    }
    _esle(siradaki);
    return true;
  }

  /// Oyuncu ayrıldı; sırası ondaysa sıra geçer. Açık kart kapanır.
  void oyuncuCikar(int id) {
    final o = oyuncular.firstWhere((e) => e.id == id);
    if (o.ayrildi) return;
    final siradaydi = identical(o, siradaki);
    o.ayrildi = true;
    if (siradaydi) {
      for (final i in acik) {
        kartlar[i].acik = false;
      }
      acik.clear();
      if (aktif.isNotEmpty) sonraki();
    }
  }

  /// Puan, eşitte en uzun seri; yine eşitse aynı sıra.
  List<HafizaSira> siralama() {
    final l = [...oyuncular]..sort((a, b) {
        final c = b.puan2.compareTo(a.puan2);
        return c != 0 ? c : b.enUzunSeri.compareTo(a.enUzunSeri);
      });
    final sonuc = <HafizaSira>[];
    for (var i = 0; i < l.length; i++) {
      final o = l[i];
      var sira = i + 1;
      if (i > 0) {
        final p = l[i - 1];
        if (p.puan2 == o.puan2 && p.enUzunSeri == o.enUzunSeri) {
          sira = sonuc[i - 1].sira;
        }
      }
      sonuc.add(HafizaSira(o.id, sira, o.puan2, o.enUzunSeri));
    }
    return sonuc;
  }

  /// Fil Hafızası: en az 3 hamle yapanlar arasında en az hata (eşitlikte hepsi).
  List<int> filHafizasi() {
    final adaylar = [for (final o in oyuncular) if (o.hamle >= 3) o];
    if (adaylar.isEmpty) return const [];
    final en = adaylar.map((o) => o.hata).reduce(min);
    return [for (final o in adaylar) if (o.hata == en) o.id];
  }
}
