enum YkSonuc { dogru, pas, ihlal }

class YkKayit {
  YkKayit(this.kartId, this.hedef, this.sonuc);
  final String kartId;
  final String hedef;
  final YkSonuc sonuc;
}

class YkTur {
  YkTur({required this.takim, required this.anlaticiId, required this.hakemId});
  final int takim;
  final int anlaticiId;
  final int? hakemId; // null = Dürüstlük modu
  final List<YkKayit> kayitlar = [];

  int get dogru => kayitlar.where((k) => k.sonuc == YkSonuc.dogru).length;
  int get ihlal => kayitlar.where((k) => k.sonuc == YkSonuc.ihlal).length;
  int get pas => kayitlar.where((k) => k.sonuc == YkSonuc.pas).length;

  /// Puan: Doğru +1; ihlal ve pas 0 (A5 istisnası: ek ceza yok).
  int get puan => dogru;
}

const ihlalKilidiMs = 800;

/// Saf Dart oyun akışı: takımlar dönüşümlü, anlatıcı takım içinde döner,
/// hakem sıradaki rakip takımdan seçilir.
class YasakOyunu {
  YasakOyunu({
    required List<int> oyuncuIdleri,
    required int takimSayisi,
    required this.turPerTakim,
    this.pasHakki = 3, // 0 = sınırsız
  }) {
    var t = takimSayisi.clamp(2, 4);
    // Takım başına en az 2 kişi
    while (t > 2 && oyuncuIdleri.length < t * 2) {
      t--;
    }
    this.takimSayisi = t;
    takimlar = List.generate(t, (_) => <int>[]);
    for (var i = 0; i < oyuncuIdleri.length; i++) {
      takimlar[i % t].add(oyuncuIdleri[i]);
    }
    skor = List.filled(t, 0);
  }

  late final int takimSayisi;
  late final List<List<int>> takimlar;
  late final List<int> skor;
  final int turPerTakim;
  final int pasHakki;
  final List<YkTur> turlar = [];
  final Map<int, int> _anlaticiSayac = {};
  final Map<int, int> _hakemSayac = {};

  // Aktif tur durumu
  YkTur? aktif;
  int _pasKalan = 0;
  int? _sonKartDegisimMs;
  String? _sonKartId;
  _Geri? _geri;

  int get toplamTur => takimSayisi * turPerTakim;
  int get tamamlanan => turlar.length;
  bool get bitti => tamamlanan >= toplamTur;
  int get siradakiTakim => tamamlanan % takimSayisi;
  int get pasKalan => pasHakki == 0 ? 1 << 20 : _pasKalan;
  bool get pasVar => pasHakki == 0 || _pasKalan > 0;

  /// Sıradaki tur için anlatıcı/hakemi seçer (önizleme; sayaçları artırmaz).
  ({int anlatici, int? hakem}) siradakiRoller() {
    final t = siradakiTakim;
    final liste = takimlar[t];
    final a = liste[(_anlaticiSayac[t] ?? 0) % liste.length];
    int? h;
    for (var k = 1; k < takimSayisi; k++) {
      final rt = (t + k) % takimSayisi;
      final rl = takimlar[rt];
      if (rl.isNotEmpty) {
        h = rl[(_hakemSayac[rt] ?? 0) % rl.length];
        break;
      }
    }
    return (anlatici: a, hakem: h);
  }

  YkTur turBaslat() {
    final r = siradakiRoller();
    final t = siradakiTakim;
    _anlaticiSayac[t] = (_anlaticiSayac[t] ?? 0) + 1;
    if (r.hakem != null) {
      for (var k = 1; k < takimSayisi; k++) {
        final rt = (t + k) % takimSayisi;
        if (takimlar[rt].contains(r.hakem)) {
          _hakemSayac[rt] = (_hakemSayac[rt] ?? 0) + 1;
          break;
        }
      }
    }
    aktif = YkTur(takim: t, anlaticiId: r.anlatici, hakemId: r.hakem);
    _pasKalan = pasHakki;
    _geri = null;
    _sonKartDegisimMs = null;
    _sonKartId = null;
    return aktif!;
  }

  /// Yeni kartın ekrana geldiği an (ihlal kilidi için).
  void kartGoster(String kartId, int simdiMs) {
    _sonKartId = kartId;
    _sonKartDegisimMs = simdiMs;
  }

  /// true: kayıt işlendi, false: yok sayıldı.
  bool isaretle(YkSonuc s, String kartId, String hedef, int simdiMs) {
    final t = aktif;
    if (t == null) return false;
    if (kartId != _sonKartId && _sonKartId != null) return false;
    if (s == YkSonuc.ihlal &&
        _sonKartDegisimMs != null &&
        simdiMs - _sonKartDegisimMs! < ihlalKilidiMs) {
      return false;
    }
    if (s == YkSonuc.pas) {
      if (pasHakki != 0 && _pasKalan <= 0) throw StateError('PASS_EXHAUSTED');
      if (pasHakki != 0) _pasKalan--;
    }
    t.kayitlar.add(YkKayit(kartId, hedef, s));
    _geri = _Geri(s, s == YkSonuc.pas && pasHakki != 0);
    return true;
  }

  /// Tek seviye geri alma: son kaydı siler, pas hakkını geri verir.
  bool geriAl() {
    final t = aktif;
    final g = _geri;
    if (t == null || g == null || t.kayitlar.isEmpty) return false;
    t.kayitlar.removeLast();
    if (g.pasHakkiHarcandi) _pasKalan++;
    _geri = null;
    return true;
  }

  YkTur turuBitir() {
    final t = aktif!;
    skor[t.takim] += t.puan;
    turlar.add(t);
    aktif = null;
    return t;
  }

  /// Kazanan takımlar (eşitlikte birden fazla).
  List<int> kazananlar() {
    final en = skor.reduce((a, b) => a > b ? a : b);
    return [for (var i = 0; i < skor.length; i++) if (skor[i] == en) i];
  }
}

class _Geri {
  _Geri(this.sonuc, this.pasHakkiHarcandi);
  final YkSonuc sonuc;
  final bool pasHakkiHarcandi;
}
