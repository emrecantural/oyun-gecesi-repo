enum Sonuc { dogru, pas, iptal, ihlal }

class KelimeSatiri {
  KelimeSatiri(this.kelimeId, this.metin, this.sonuc, this.ms);
  final String kelimeId;
  final String metin;
  Sonuc sonuc;
  final int ms;
}

/// Tur puanı: Doğru +1; pas 0 (ayar: −1); ihlal −1; iptal 0.
int turPuani(List<KelimeSatiri> satirlar, {bool pasCezali = false}) {
  var p = 0;
  for (final s in satirlar) {
    switch (s.sonuc) {
      case Sonuc.dogru:
        p += 1;
      case Sonuc.pas:
        if (pasCezali) p -= 1;
      case Sonuc.ihlal:
        p -= 1;
      case Sonuc.iptal:
        break;
    }
  }
  return p;
}

class AlnimTuru {
  AlnimTuru(this.tutanId, this.takim);
  final int tutanId;
  final int? takim;
  final List<KelimeSatiri> satirlar = [];
}

/// Oyun akışı ve puan: saf Dart.
class AlnimdakiOyunu {
  AlnimdakiOyunu({
    required this.oyuncuIdleri,
    required this.turPerOyuncu,
    this.takimSayisi = 0,
    this.pasHakki = 3, // 0 = sınırsız
    this.pasCezali = false,
  }) : assert(oyuncuIdleri.length >= 2) {
    _sira = _siraKur();
  }

  final List<int> oyuncuIdleri;
  final int turPerOyuncu;
  final int takimSayisi;
  final int pasHakki;
  final bool pasCezali;
  late final List<int> _sira;
  final List<AlnimTuru> turlar = [];

  int? takimiOf(int id) =>
      takimSayisi < 2 ? null : oyuncuIdleri.indexOf(id) % takimSayisi;

  /// Takımlıda sıra takımlar arası dönüşümlü, bireyselde liste sırası.
  List<int> _siraKur() {
    final tur = <int>[];
    for (var t = 0; t < turPerOyuncu; t++) {
      if (takimSayisi < 2) {
        tur.addAll(oyuncuIdleri);
      } else {
        final gruplar = List.generate(
            takimSayisi,
            (k) => [
                  for (var i = 0; i < oyuncuIdleri.length; i++)
                    if (i % takimSayisi == k) oyuncuIdleri[i]
                ]);
        final enUzun = gruplar.map((g) => g.length).reduce((a, b) => a > b ? a : b);
        for (var i = 0; i < enUzun; i++) {
          for (final g in gruplar) {
            if (i < g.length) tur.add(g[i]);
          }
        }
      }
    }
    return tur;
  }

  int get toplamTur => _sira.length;
  int get tamamlanan => turlar.length;
  bool get bitti => tamamlanan >= toplamTur;
  int? get siradaki => bitti ? null : _sira[tamamlanan];

  /// Tur sonucunu kaydeder.
  AlnimTuru turuBitir(List<KelimeSatiri> satirlar) {
    final id = siradaki!;
    final t = AlnimTuru(id, takimiOf(id))..satirlar.addAll(satirlar);
    turlar.add(t);
    return t;
  }

  int pasKalan(List<KelimeSatiri> satirlar) {
    if (pasHakki == 0) return 1 << 20;
    final kullanilan = satirlar.where((s) => s.sonuc == Sonuc.pas).length;
    return (pasHakki - kullanilan).clamp(0, pasHakki);
  }

  Map<int, int> bireyselPuan() {
    final m = {for (final id in oyuncuIdleri) id: 0};
    for (final t in turlar) {
      m[t.tutanId] = m[t.tutanId]! + turPuani(t.satirlar, pasCezali: pasCezali);
    }
    return m;
  }

  Map<int, int> takimPuani() {
    final m = <int, int>{};
    for (final t in turlar) {
      final k = t.takim;
      if (k == null) continue;
      m[k] = (m[k] ?? 0) + turPuani(t.satirlar, pasCezali: pasCezali);
    }
    return m;
  }

  /// Rozetler: Dil Bilmez (hiç pas etmeyen, ≥1 doğru), Telepati (<5 sn'de bilinen doğru).
  List<int> dilBilmez() => [
        for (final id in oyuncuIdleri)
          if (turlar.any((t) => t.tutanId == id) &&
              turlar
                  .where((t) => t.tutanId == id)
                  .every((t) => t.satirlar.every((s) => s.sonuc != Sonuc.pas)) &&
              turlar
                  .where((t) => t.tutanId == id)
                  .any((t) => t.satirlar.any((s) => s.sonuc == Sonuc.dogru)))
            id
      ];

  List<int> telepati() {
    final ids = <int>{};
    for (final t in turlar) {
      if (t.satirlar.any((s) => s.sonuc == Sonuc.dogru && s.ms < 5000)) {
        ids.add(t.tutanId);
      }
    }
    return ids.toList();
  }
}
