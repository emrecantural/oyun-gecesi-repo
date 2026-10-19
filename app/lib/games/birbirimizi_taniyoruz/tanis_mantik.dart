class TanisSoru {
  const TanisSoru(this.id, this.metin, this.siklar);
  final String id;
  final String metin;
  final List<String> siklar;
}

class TahminKaydi {
  TahminKaydi(this.secim, this.ms);
  final int? secim; // null = süre doldu
  final int ms;
}

/// Bir odak bloğu: odak k soruyu cevaplar, sonra her tahminci aynı sorulara tahmin yapar.
class OdakBlogu {
  OdakBlogu(this.odakId, this.sorular);
  final int odakId;
  final List<TanisSoru> sorular;
  final Map<int, int?> odakCevap = {}; // qIdx → şık (null: cevapsız)
  final Map<int, Map<int, TahminKaydi>> tahmin = {}; // guesserId → qIdx → kayıt

  /// Odağın cevapladığı soruların indeksleri.
  List<int> get cevaplananlar => [
        for (var i = 0; i < sorular.length; i++)
          if (odakCevap[i] != null) i
      ];
}

class RevealSonucu {
  RevealSonucu(this.qIdx, this.dogruSik, this.bilen, this.bilemeyen);
  final int qIdx;
  final int dogruSik;
  final List<int> bilen;
  final List<int> bilemeyen;
  bool get acikKitap => bilemeyen.isEmpty && bilen.isNotEmpty;
  bool get gizemli => bilen.isEmpty && bilemeyen.isNotEmpty;
}

const hizliSinirMs = 5000;

class TanisOyunu {
  TanisOyunu({required this.oyuncuIdleri, required this.odakTur})
      : assert(oyuncuIdleri.length >= 2) {
    odakSirasi = [for (var t = 0; t < odakTur; t++) ...oyuncuIdleri];
  }

  final List<int> oyuncuIdleri;
  final int odakTur;
  late final List<int> odakSirasi;
  final List<OdakBlogu> bloklar = [];
  final Set<int> ayrilan = {};
  final Map<int, double> puan = {};
  int acikKitap = 0;
  int gizemli = 0;
  final Map<int, int> acikKitapOdak = {};
  final Map<int, int> gizemliOdak = {};

  List<int> tahminciler(int odakId) =>
      [for (final id in oyuncuIdleri) if (id != odakId && !ayrilan.contains(id)) id];

  OdakBlogu blokAc(int odakId, List<TanisSoru> sorular) {
    final b = OdakBlogu(odakId, sorular);
    bloklar.add(b);
    return b;
  }

  void odakCevapla(OdakBlogu b, int qIdx, int? secim) => b.odakCevap[qIdx] = secim;

  void tahminEt(OdakBlogu b, int guesserId, int qIdx, int? secim, int ms) {
    if (guesserId == b.odakId) throw StateError('NOT_YOUR_TURN');
    final m = b.tahmin.putIfAbsent(guesserId, () => {});
    if (m.containsKey(qIdx)) throw StateError('ALREADY_ANSWERED');
    m[qIdx] = TahminKaydi(secim, ms);
  }

  static double tahminPuani(bool dogru, int ms) =>
      !dogru ? 0 : (ms <= hizliSinirMs ? 1.5 : 1.0);

  /// Reveal hesapla ve puanları işle (blok başına bir kez çağır).
  List<RevealSonucu> revealHesapla(OdakBlogu b) {
    final sonuc = <RevealSonucu>[];
    for (final q in b.cevaplananlar) {
      final dogru = b.odakCevap[q]!;
      final bilen = <int>[];
      final bilemeyen = <int>[];
      for (final g in b.tahmin.keys) {
        final k = b.tahmin[g]![q];
        if (k == null) continue;
        if (k.secim == dogru) {
          bilen.add(g);
          puan[g] = (puan[g] ?? 0) + tahminPuani(true, k.ms);
        } else {
          bilemeyen.add(g);
        }
      }
      final r = RevealSonucu(q, dogru, bilen, bilemeyen);
      if (r.acikKitap) {
        acikKitap++;
        acikKitapOdak[b.odakId] = (acikKitapOdak[b.odakId] ?? 0) + 1;
      }
      if (r.gizemli) {
        gizemli++;
        gizemliOdak[b.odakId] = (gizemliOdak[b.odakId] ?? 0) + 1;
      }
      sonuc.add(r);
    }
    return sonuc;
  }

  int? enCokAcikKitap() => _enCok(acikKitapOdak);
  int? enCokGizemli() => _enCok(gizemliOdak);

  int? _enCok(Map<int, int> m) {
    if (m.isEmpty) return null;
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.first.key;
  }
}
