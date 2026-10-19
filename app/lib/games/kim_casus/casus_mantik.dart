import 'dart:math';

/// 02 Kim Casus? — saf oyun mantığı (CasusEngine).

class Mekan {
  const Mekan({
    required this.id,
    required this.ad,
    required this.kategori,
    required this.roller,
    required this.ipuclari,
    this.ucretsiz = false,
  });
  final String id;
  final String ad;
  final String kategori;
  final List<String> roller;
  final List<String> ipuclari;
  final bool ucretsiz;
}

enum CasusAsama { rolDagit, soruCevap, suclama, aciKOylama, tahmin, reveal, bitti }

enum TahminBaglami { yakalandi, iddia }

enum TurSonucu {
  casusYakalanmadi, // süre bitti / yanlış suçlama → casus +2
  yakalandiMekanDogru, // casus +1
  yakalandiMekanYanlis, // masumlar +1, suçlayan +1 ekstra (oybirliği)
  iddiaDogru, // casus +2
  iddiaYanlis, // masumlar +1
}

class CasusHata implements Exception {
  CasusHata(this.kod);
  final String kod;
  @override
  String toString() => 'CasusHata($kod)';
}

class CasusAyar {
  const CasusAyar({
    required this.sureMs,
    required this.turSayisi,
    required this.rolKartlari,
    required this.kategoriIpucu,
    required this.kura,
  });
  final int sureMs;
  final int turSayisi;
  final bool rolKartlari;
  final bool kategoriIpucu;
  final bool kura;
}

class CasusOyunu {
  CasusOyunu({
    required this.oyuncuSayisi,
    required this.mekanlar,
    required this.ayar,
    Random? rastgele,
  })  : assert(oyuncuSayisi >= 3 && oyuncuSayisi <= 12),
        _rng = rastgele ?? Random.secure(),
        puanlar = List.filled(oyuncuSayisi, 0),
        yakalayan = List.filled(oyuncuSayisi, 0),
        casusKazanma = List.filled(oyuncuSayisi, 0) {
    if (mekanlar.isEmpty) throw CasusHata('ERR_POOL_EMPTY');
  }

  final int oyuncuSayisi;
  final List<Mekan> mekanlar;
  final CasusAyar ayar;
  final Random _rng;

  final List<int> puanlar;
  final List<int> yakalayan;
  final List<int> casusKazanma;

  CasusAsama asama = CasusAsama.rolDagit;
  int tur = 0;
  late Mekan mekan;
  late int casusIdx;
  late List<String> _roller; // oyuncu → rol (casus için boş)
  late String _ipucu;
  final Set<String> _sonMekanlar = {};

  int soranIdx = 0;
  int? oncekiSoranIdx; // şu anki soranı soran kişi
  final Set<int> suclamaKullanan = {};

  // Suçlama durumu
  int? suclananIdx;
  int? suclayanIdx;
  final Map<int, bool> suclamaOylari = {};
  final Map<int, int> aciOylar = {};

  TahminBaglami? tahminBaglami;
  TurSonucu? sonuc;
  int? tahminEdilenMekanIdx;
  List<int> sonPuanArtisi = const [];

  // --- Tur ---

  void turBaslat() {
    tur++;
    asama = CasusAsama.rolDagit;
    sonuc = null;
    suclananIdx = null;
    suclayanIdx = null;
    suclamaOylari.clear();
    aciOylar.clear();
    suclamaKullanan.clear();
    tahminBaglami = null;
    tahminEdilenMekanIdx = null;
    sonPuanArtisi = const [];

    // Aynı mekân art arda gelmez; havuz bitince karıştırılır.
    var adaylar = mekanlar.where((m) => !_sonMekanlar.contains(m.id)).toList();
    if (adaylar.isEmpty) {
      _sonMekanlar.clear();
      adaylar = [...mekanlar];
    }
    mekan = adaylar[_rng.nextInt(adaylar.length)];
    _sonMekanlar.add(mekan.id);
    if (mekanlar.length > 1 && _sonMekanlar.length > mekanlar.length - 1) {
      _sonMekanlar
        ..clear()
        ..add(mekan.id);
    }

    casusIdx = _rng.nextInt(oyuncuSayisi);
    final roller = [...mekan.roller]..shuffle(_rng);
    _roller = List.filled(oyuncuSayisi, '');
    var k = 0;
    for (var i = 0; i < oyuncuSayisi; i++) {
      if (i == casusIdx) continue;
      _roller[i] = roller.isEmpty ? '' : roller[k % roller.length];
      k++;
    }
    _ipucu = mekan.ipuclari.isEmpty
        ? ''
        : mekan.ipuclari[_rng.nextInt(mekan.ipuclari.length)];
    soranIdx = _rng.nextInt(oyuncuSayisi);
    oncekiSoranIdx = null;
  }

  /// Kart yüzü: basılı tutulurken okunur. Casus için mekân bilgisi YOK.
  KartYuzu kartiGor(int oyuncuIdx) {
    if (oyuncuIdx == casusIdx) {
      return KartYuzu.casus(
        kategori: (ayar.kategoriIpucu || oyuncuSayisi == 3)
            ? mekan.kategori
            : null,
      );
    }
    return KartYuzu.masum(
      mekan: mekan.ad,
      rol: ayar.rolKartlari ? _roller[oyuncuIdx] : null,
      ipucu: _ipucu.isEmpty ? null : _ipucu,
    );
  }

  void rolDagitimiBitti() {
    if (asama != CasusAsama.rolDagit) throw CasusHata('NOT_IN_PHASE');
    asama = CasusAsama.soruCevap;
  }

  // --- Soru-cevap ---

  bool soruSorulabilir(int from, int to) =>
      to != from && to != oncekiSoranIdx;

  void sor(int to) {
    if (asama != CasusAsama.soruCevap) throw CasusHata('NOT_IN_PHASE');
    if (!soruSorulabilir(soranIdx, to)) throw CasusHata('ERR_REVERSE_ASK');
    oncekiSoranIdx = soranIdx;
    soranIdx = to;
  }

  /// Kura modu: sıradaki soran rastgele (önceki soranı soran hariç).
  int kuraSoran() {
    if (asama != CasusAsama.soruCevap) throw CasusHata('NOT_IN_PHASE');
    final adaylar = [
      for (var i = 0; i < oyuncuSayisi; i++)
        if (soruSorulabilir(soranIdx, i)) i,
    ];
    final secilen = adaylar[_rng.nextInt(adaylar.length)];
    sor(secilen);
    return secilen;
  }

  // --- Suçlama ---

  void suclaBaslat(int by, int suspect) {
    if (asama != CasusAsama.soruCevap) throw CasusHata('NOT_IN_PHASE');
    if (suclamaKullanan.contains(by)) throw CasusHata('ERR_ACCUSE_USED');
    if (by == suspect) throw CasusHata('ERR_SELF');
    suclamaKullanan.add(by);
    suclayanIdx = by;
    suclananIdx = suspect;
    suclamaOylari.clear();
    asama = CasusAsama.suclama;
  }

  /// Oy verecekler: suçlanan hariç herkes.
  List<int> get oyVerecekler => [
        for (var i = 0; i < oyuncuSayisi; i++)
          if (i != suclananIdx) i,
      ];

  /// Gizli oy; hepsi verince sonuç işlenir. Oybirliği yoksa SORU_CEVAP'a döner.
  void suclamaOyu(int voter, bool evet) {
    if (asama != CasusAsama.suclama) throw CasusHata('NOT_IN_PHASE');
    if (voter == suclananIdx) throw CasusHata('ERR_SUSPECT_VOTES');
    suclamaOylari[voter] = evet;
    if (suclamaOylari.length < oyVerecekler.length) return;
    final oybirligi = suclamaOylari.values.every((v) => v);
    if (!oybirligi) {
      asama = CasusAsama.soruCevap;
      return;
    }
    if (suclananIdx == casusIdx) {
      tahminBaglami = TahminBaglami.yakalandi;
      asama = CasusAsama.tahmin;
    } else {
      _bitir(TurSonucu.casusYakalanmadi);
    }
  }

  // --- Casus iddiası ---

  /// "Mekânı biliyorum": casus değilse gizli yanıt döner (false), oyun etkilenmez.
  bool casusIddiasi(int idx) {
    if (asama != CasusAsama.soruCevap && asama != CasusAsama.suclama) {
      throw CasusHata('NOT_IN_PHASE');
    }
    if (idx != casusIdx) return false;
    tahminBaglami = TahminBaglami.iddia;
    asama = CasusAsama.tahmin;
    return true;
  }

  // --- Süre bitti: açık oylama ---

  void sureBitti() {
    if (asama != CasusAsama.soruCevap) throw CasusHata('NOT_IN_PHASE');
    aciOylar.clear();
    asama = CasusAsama.aciKOylama;
  }

  void aciOy(int voter, int suspect) {
    if (asama != CasusAsama.aciKOylama) throw CasusHata('NOT_IN_PHASE');
    if (voter == suspect) throw CasusHata('ERR_SELF');
    aciOylar[voter] = suspect;
    if (aciOylar.length < oyuncuSayisi) return;
    final sayim = <int, int>{};
    for (final s in aciOylar.values) {
      sayim[s] = (sayim[s] ?? 0) + 1;
    }
    final enCok = sayim.values.reduce(max);
    final liderler = [
      for (final e in sayim.entries)
        if (e.value == enCok) e.key,
    ];
    if (liderler.length == 1 && liderler.first == casusIdx) {
      suclananIdx = casusIdx;
      suclayanIdx = null;
      tahminBaglami = TahminBaglami.yakalandi;
      asama = CasusAsama.tahmin;
    } else {
      // Masum çoğunluk ya da eşitlik: casus kazanır.
      _bitir(TurSonucu.casusYakalanmadi);
    }
  }

  // --- Tahmin ---

  void tahminEt(int mekanIdx) {
    if (asama != CasusAsama.tahmin) throw CasusHata('NOT_IN_PHASE');
    tahminEdilenMekanIdx = mekanIdx;
    final dogru = mekanlar[mekanIdx].id == mekan.id;
    final yakalandi = tahminBaglami == TahminBaglami.yakalandi;
    _bitir(yakalandi
        ? (dogru ? TurSonucu.yakalandiMekanDogru : TurSonucu.yakalandiMekanYanlis)
        : (dogru ? TurSonucu.iddiaDogru : TurSonucu.iddiaYanlis));
  }

  /// Casus tahmin süresi (30 sn) doldu: yanlış sayılır.
  void tahminSuresiBitti() {
    if (asama != CasusAsama.tahmin) throw CasusHata('NOT_IN_PHASE');
    final yakalandi = tahminBaglami == TahminBaglami.yakalandi;
    _bitir(yakalandi ? TurSonucu.yakalandiMekanYanlis : TurSonucu.iddiaYanlis);
  }

  void _bitir(TurSonucu s) {
    sonuc = s;
    final artis = List.filled(oyuncuSayisi, 0);
    void masumlaraBir() {
      for (var i = 0; i < oyuncuSayisi; i++) {
        if (i != casusIdx) artis[i] += 1;
      }
    }

    switch (s) {
      case TurSonucu.casusYakalanmadi:
        artis[casusIdx] += 2;
        casusKazanma[casusIdx]++;
      case TurSonucu.yakalandiMekanDogru:
        artis[casusIdx] += 1;
        casusKazanma[casusIdx]++;
      case TurSonucu.yakalandiMekanYanlis:
        masumlaraBir();
        if (suclayanIdx != null) artis[suclayanIdx!] += 1;
        if (suclayanIdx != null) yakalayan[suclayanIdx!]++;
      case TurSonucu.iddiaDogru:
        artis[casusIdx] += 2;
        casusKazanma[casusIdx]++;
      case TurSonucu.iddiaYanlis:
        masumlaraBir();
    }
    for (var i = 0; i < oyuncuSayisi; i++) {
      puanlar[i] += artis[i];
    }
    sonPuanArtisi = artis;
    asama = CasusAsama.reveal;
  }

  bool get sonTurMu => tur >= ayar.turSayisi;

  void turuBitirPuansiz() {
    sonuc = null;
    sonPuanArtisi = List.filled(oyuncuSayisi, 0);
    asama = CasusAsama.reveal;
  }

  void sonrakiTurVeyaFinal() {
    if (sonTurMu) {
      asama = CasusAsama.bitti;
    } else {
      turBaslat();
    }
  }

  int? get enIyiDedektif => _enCok(yakalayan);
  int? get enIyiYalanci => _enCok(casusKazanma);

  int? _enCok(List<int> l) {
    final m = l.reduce(max);
    if (m == 0) return null;
    return l.indexOf(m);
  }
}

class KartYuzu {
  const KartYuzu._({
    required this.casus,
    this.mekan,
    this.rol,
    this.ipucu,
    this.kategori,
  });
  factory KartYuzu.casus({String? kategori}) =>
      KartYuzu._(casus: true, kategori: kategori);
  factory KartYuzu.masum({required String mekan, String? rol, String? ipucu}) =>
      KartYuzu._(casus: false, mekan: mekan, rol: rol, ipucu: ipucu);

  final bool casus;
  final String? mekan;
  final String? rol;
  final String? ipucu;
  final String? kategori;
}
