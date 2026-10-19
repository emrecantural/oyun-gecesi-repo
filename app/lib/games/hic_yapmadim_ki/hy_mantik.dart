import '../../shell/ortak/oyuncular.dart';

enum HyMod { parmak, can, isimli }

enum HyAsama { kart, cevap, sayim, sonuc, canGuncelle, bitti }

enum HyIsaret { bos, yaptim, pas }

class HyAyar {
  const HyAyar({
    required this.mod,
    required this.can,
    required this.takasHakki,
    required this.turSayisi,
  });
  final HyMod mod;
  final int can;
  final int takasHakki;

  /// 0 = sınırsız (yalnız Bitir).
  final int turSayisi;
}

class HySonuc {
  const HySonuc({required this.yapan, required this.toplam, required this.yapanlar});
  final int yapan;
  final int toplam;
  final List<Oyuncu> yapanlar;

  int get yuzde => toplam == 0 ? 0 : (yapan * 100 / toplam).round();
  bool get herkesYapti => toplam > 0 && yapan == toplam;
  bool get kimseYapmadi => yapan == 0;
}

/// 05 Hiç Yapmadım Ki — saf oyun mantığı (arayüzden bağımsız, test edilebilir).
class HyOyunu {
  HyOyunu({required this.oyuncular, required this.ayar})
      : can = {for (final o in oyuncular) o.id: ayar.can},
        isaretler = {for (final o in oyuncular) o.id: HyIsaret.bos},
        takasKalan = ayar.takasHakki;

  final List<Oyuncu> oyuncular;
  final HyAyar ayar;
  final Map<int, int> can;
  final Map<int, HyIsaret> isaretler;
  final List<Oyuncu> elenenler = [];
  final List<HySonuc> turlar = [];
  final Set<int> hicYaptimDemeyenler = {};

  HyAsama asama = HyAsama.kart;
  int tur = 1;
  int takasKalan;
  HySonuc? sonuc;
  List<Oyuncu> kazananlar = const [];

  bool get canModu => ayar.mod == HyMod.can;
  bool get cipModu => ayar.mod != HyMod.parmak;

  List<Oyuncu> get hayattakiler => canModu
      ? oyuncular.where((o) => (can[o.id] ?? 0) > 0).toList()
      : oyuncular;

  bool elendi(int id) => canModu && (can[id] ?? 0) <= 0;

  // --- Olaylar ---

  void kartOkundu() {
    if (asama != HyAsama.kart) throw StateError('NOT_IN_PHASE');
    asama = HyAsama.cevap;
  }

  void kartDegistir() {
    if (asama != HyAsama.kart) throw StateError('NOT_IN_PHASE');
    if (takasKalan <= 0) throw StateError('NO_SWAPS_LEFT');
    takasKalan--;
  }

  /// boş → yaptım → pas → boş (yalnız çip modları, yalnız CEVAP fazı).
  void isaretDegistir(int id) {
    if (asama != HyAsama.cevap) throw StateError('NOT_IN_PHASE');
    if (!cipModu || elendi(id)) return;
    final simdi = isaretler[id] ?? HyIsaret.bos;
    isaretler[id] = switch (simdi) {
      HyIsaret.bos => HyIsaret.yaptim,
      HyIsaret.yaptim => HyIsaret.pas,
      HyIsaret.pas => HyIsaret.bos,
    };
  }

  /// Cevap süresi doldu.
  void cevapBitti() {
    if (asama != HyAsama.cevap) throw StateError('NOT_IN_PHASE');
    asama = cipModu ? HyAsama.sonuc : HyAsama.sayim;
    if (cipModu) _sonucuHesapla();
  }

  void sayimGir(int n) {
    if (asama != HyAsama.sayim) throw StateError('NOT_IN_PHASE');
    if (ayar.mod != HyMod.parmak) throw StateError('NOT_IN_PHASE');
    if (n < 0 || n > oyuncular.length) throw RangeError('OUT_OF_RANGE');
    sonuc = HySonuc(yapan: n, toplam: oyuncular.length, yapanlar: const []);
    turlar.add(sonuc!);
    asama = HyAsama.sonuc;
  }

  void _sonucuHesapla() {
    final katilan = canModu ? hayattakiler : oyuncular;
    final yapanlar = [
      for (final o in katilan)
        if (isaretler[o.id] == HyIsaret.yaptim) o,
    ];
    final pas = katilan.where((o) => isaretler[o.id] == HyIsaret.pas).length;
    sonuc = HySonuc(
      yapan: yapanlar.length,
      toplam: katilan.length - pas,
      yapanlar: yapanlar,
    );
    turlar.add(sonuc!);
  }

  /// SONUÇ süresi doldu: Can modunda can güncellenir, sonra sıradaki tur/final.
  void sonucGecildi() {
    if (asama != HyAsama.sonuc) throw StateError('NOT_IN_PHASE');
    if (canModu) {
      asama = HyAsama.canGuncelle;
      canGuncelle();
    } else {
      _siradaki();
    }
  }

  void canGuncelle() {
    if (asama != HyAsama.canGuncelle) throw StateError('NOT_IN_PHASE');
    final oncekiHayatta = hayattakiler;
    for (final o in sonuc!.yapanlar) {
      can[o.id] = (can[o.id] ?? 0) - 1;
    }
    for (final o in oncekiHayatta) {
      if ((can[o.id] ?? 0) <= 0 && !elenenler.contains(o)) elenenler.add(o);
    }
    final kalan = hayattakiler;
    if (kalan.isEmpty) {
      // Aynı turda kalan herkes elendi: o turdan önce hayatta olanlar ortak kazanan.
      kazananlar = oncekiHayatta;
      asama = HyAsama.bitti;
      return;
    }
    if (kalan.length == 1) {
      kazananlar = kalan;
      asama = HyAsama.bitti;
      return;
    }
    _siradaki();
  }

  void _siradaki() {
    if (ayar.turSayisi > 0 && tur >= ayar.turSayisi) {
      bitir();
      return;
    }
    tur++;
    for (final o in oyuncular) {
      isaretler[o.id] = HyIsaret.bos;
    }
    sonuc = null;
    asama = HyAsama.kart;
  }

  /// Oyunu bitir: Can modunda en çok canı olan(lar) kazanır.
  void bitir() {
    if (canModu && kazananlar.isEmpty) {
      final enCok = oyuncular.map((o) => can[o.id] ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
      kazananlar = oyuncular.where((o) => (can[o.id] ?? 0) == enCok).toList();
    }
    asama = HyAsama.bitti;
  }
}
