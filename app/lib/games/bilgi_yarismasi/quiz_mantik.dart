import 'dart:math';

class QuizSoru {
  QuizSoru(this.id, this.metin, this.siklar, this.dogru, this.kategori);
  final String id;
  final String metin;
  final List<String> siklar;
  final int dogru; // şık indeksi
  final String kategori;

  /// CSV ek alanı: `doğru|y1|y2|y3|kategori`. Şıklar karıştırılır.
  static QuizSoru? csvden(String id, String metin, String ek, Random r) {
    final p = ek.split('|');
    if (p.length < 4) return null;
    final dogruMetin = p[0];
    final siklar = p.sublist(0, 4)..shuffle(r);
    return QuizSoru(id, metin, siklar, siklar.indexOf(dogruMetin),
        p.length > 4 ? p[4] : '');
  }
}

class SayisalSoru {
  const SayisalSoru(this.id, this.metin, this.dogru, this.birim);
  final String id;
  final String metin;
  final int dogru;
  final String birim;

  static SayisalSoru? csvden(String id, String metin, String ek) {
    final p = ek.split('|');
    final d = int.tryParse(p.first.replaceAll('.', '').trim());
    if (d == null) return null;
    return SayisalSoru(id, metin, d, p.length > 1 ? p[1] : '');
  }
}

/// taban = 500 + round(500 × kalan/toplam); puan = round(taban × seri × son).
int quizPuani({
  required int kalanMs,
  required int toplamMs,
  required int seriSonrasi,
  required bool sonSoru,
  bool seriAcik = true,
  bool sonSoruCift = true,
}) {
  final k = kalanMs.clamp(0, toplamMs);
  final taban = 500 + (500 * k / toplamMs).round();
  final seri = !seriAcik ? 1.0 : (seriSonrasi >= 5 ? 1.2 : (seriSonrasi >= 3 ? 1.1 : 1.0));
  final son = sonSoru && sonSoruCift ? 2 : 1;
  return (taban * seri * son).round();
}

class QuizOyuncu {
  QuizOyuncu(this.id);
  final int id;
  int puan = 0;
  int seri = 0;
  bool jokerKullandi = false;
  int dogruSayisi = 0;
  int enHizliMs = 1 << 30;
  int sansliIsabet = 0;
  bool ayrildi = false;
}

class Cevap {
  Cevap(this.secim, this.kalanMs, this.jokerli);
  final int secim;
  final int kalanMs;
  final bool jokerli;
}

class SoruSonucu {
  SoruSonucu(this.dagilim, this.puanlar);
  final List<List<int>> dagilim; // şık → oyuncu id'leri
  final Map<int, int> puanlar;
}

class QuizMotoru {
  QuizMotoru({
    required List<int> oyuncuIdleri,
    required this.soruSayisi,
    required this.toplamMs,
    this.joker = true,
    this.seriAcik = true,
    this.sonSoruCift = true,
  }) : oyuncular = {for (final id in oyuncuIdleri) id: QuizOyuncu(id)};

  final Map<int, QuizOyuncu> oyuncular;
  final int soruSayisi;
  final int toplamMs;
  final bool joker;
  final bool seriAcik;
  final bool sonSoruCift;
  int soruNo = 0; // 0 tabanlı, işlenmekte olan
  final Map<int, Cevap> _cevaplar = {};

  bool get sonSoru => soruNo == soruSayisi - 1;

  /// 50-50: iki yanlış şıkkı kaldırır (oyuncu başı 1). Kaldırılan indeksleri döner.
  List<int> jokerKullan(int oyuncuId, QuizSoru s, Random r) {
    final o = oyuncular[oyuncuId]!;
    if (!joker) throw StateError('JOKER_DISABLED');
    if (o.jokerKullandi) throw StateError('JOKER_USED');
    o.jokerKullandi = true;
    final yanlis = [for (var i = 0; i < 4; i++) if (i != s.dogru) i]..shuffle(r);
    return yanlis.take(2).toList();
  }

  void cevapla(int oyuncuId, int secim, int kalanMs, {bool jokerli = false}) {
    if (_cevaplar.containsKey(oyuncuId)) throw StateError('ANSWER_LOCKED');
    if (kalanMs < 0) throw StateError('ANSWER_LATE');
    _cevaplar[oyuncuId] = Cevap(secim, kalanMs, jokerli);
  }

  bool yanitladi(int id) => _cevaplar.containsKey(id);

  SoruSonucu soruyuBitir(QuizSoru s) {
    final dagilim = List.generate(4, (_) => <int>[]);
    final puanlar = <int, int>{};
    for (final o in oyuncular.values.where((o) => !o.ayrildi)) {
      final c = _cevaplar[o.id];
      if (c == null) {
        o.seri = 0;
        puanlar[o.id] = 0;
        continue;
      }
      dagilim[c.secim].add(o.id);
      if (c.secim == s.dogru) {
        o.seri++;
        final p = quizPuani(
          kalanMs: c.kalanMs,
          toplamMs: toplamMs,
          seriSonrasi: o.seri,
          sonSoru: sonSoru,
          seriAcik: seriAcik,
          sonSoruCift: sonSoruCift,
        );
        o.puan += p;
        o.dogruSayisi++;
        final gecen = toplamMs - c.kalanMs;
        if (gecen < o.enHizliMs) o.enHizliMs = gecen;
        if (c.jokerli) o.sansliIsabet++;
        puanlar[o.id] = p;
      } else {
        o.seri = 0;
        puanlar[o.id] = 0;
      }
    }
    _cevaplar.clear();
    return SoruSonucu(dagilim, puanlar);
  }

  void sonraki() => soruNo++;

  List<QuizOyuncu> sira() {
    final l = oyuncular.values.toList()..sort((a, b) => b.puan.compareTo(a.puan));
    return l;
  }

  /// 1. sıradaki eşit oyuncular (en az 2 ise eşitlik var).
  List<int> esitlik() {
    final s = sira();
    if (s.isEmpty) return const [];
    final top = s.first.puan;
    final l = s.where((o) => o.puan == top).map((o) => o.id).toList();
    return l.length >= 2 ? l : const [];
  }

  /// Tahminlere göre en yakın kazanır; hepsi eşitse hepsi.
  static List<int> yakinKazananlar(Map<int, int> tahminler, int dogru) {
    if (tahminler.isEmpty) return const [];
    var enAz = 1 << 62;
    for (final v in tahminler.values) {
      enAz = min(enAz, (v - dogru).abs());
    }
    return [for (final e in tahminler.entries) if ((e.value - dogru).abs() == enAz) e.key];
  }

  int? enHizli() {
    QuizOyuncu? b;
    for (final o in oyuncular.values) {
      if (o.dogruSayisi == 0) continue;
      if (b == null || o.enHizliMs < b.enHizliMs) b = o;
    }
    return b?.id;
  }

  int? bilgin() {
    QuizOyuncu? b;
    for (final o in oyuncular.values) {
      if (o.dogruSayisi == 0) continue;
      if (b == null || o.dogruSayisi > b.dogruSayisi) b = o;
    }
    return b?.id;
  }

  int? sansli() {
    QuizOyuncu? b;
    for (final o in oyuncular.values) {
      if (o.sansliIsabet == 0) continue;
      if (b == null || o.sansliIsabet > b.sansliIsabet) b = o;
    }
    return b?.id;
  }
}
