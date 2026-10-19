enum DurumOge { dogru, pas, yarim }

class OgeKaydi {
  OgeKaydi(this.id, this.metin, this.durum);
  final String id;
  final String metin;
  DurumOge durum;
  bool ihlal = false;
}

class DilsizTur {
  DilsizTur(this.takim, this.anlaticiId);
  final int takim;
  final int anlaticiId;
  final List<OgeKaydi> ogeler = [];

  int dogru() => ogeler.where((o) => o.durum == DurumOge.dogru && !o.ihlal).length;
  int ihlal() => ogeler.where((o) => o.durum == DurumOge.dogru && o.ihlal).length;
  int pas() => ogeler.where((o) => o.durum == DurumOge.pas).length;

  /// Doğru +1; ihlalli öğe −1 (doğru yerine); pas ceza ayarına göre; yarım kalan sayılmaz.
  int puan({bool pasCezali = false}) =>
      dogru() - ihlal() - (pasCezali ? pas() : 0);
}

class DilsizOyunu {
  DilsizOyunu({
    required List<int> oyuncuIdleri,
    required int takimSayisi,
    required this.turPerTakim,
    this.pasHakki = 3, // 0 = pas yok; -1 = sınırsız
    this.pasCezali = false,
  }) {
    var t = takimSayisi.clamp(2, 4);
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
  final bool pasCezali;
  final List<DilsizTur> turlar = [];
  final Map<int, int> _anlaticiSayac = {};
  DilsizTur? aktif;
  int _pasKullanilan = 0;
  OgeKaydi? _son;

  int get toplamTur => takimSayisi * turPerTakim;
  int get tamamlanan => turlar.length;
  bool get bitti => tamamlanan >= toplamTur;
  int get siradakiTakim => tamamlanan % takimSayisi;
  bool get pasVar => pasHakki < 0 || _pasKullanilan < pasHakki;
  int get pasKalan => pasHakki < 0 ? 1 << 20 : pasHakki - _pasKullanilan;

  int siradakiAnlatici() {
    final l = takimlar[siradakiTakim];
    return l[(_anlaticiSayac[siradakiTakim] ?? 0) % l.length];
  }

  DilsizTur turBaslat() {
    final a = siradakiAnlatici();
    _anlaticiSayac[siradakiTakim] = (_anlaticiSayac[siradakiTakim] ?? 0) + 1;
    aktif = DilsizTur(siradakiTakim, a);
    _pasKullanilan = 0;
    _son = null;
    return aktif!;
  }

  void dogru(String id, String metin) {
    final k = OgeKaydi(id, metin, DurumOge.dogru);
    aktif!.ogeler.add(k);
    _son = k;
  }

  void pas(String id, String metin) {
    if (!pasVar) throw StateError('PASS_EXHAUSTED');
    _pasKullanilan++;
    final k = OgeKaydi(id, metin, DurumOge.pas);
    aktif!.ogeler.add(k);
    _son = k;
  }

  /// Süre dolduğunda ekrandaki yarım kalan öğe (sayılmaz).
  void yarimKalan(String id, String metin) {
    aktif!.ogeler.add(OgeKaydi(id, metin, DurumOge.yarim));
  }

  /// Son Doğru/Pas işlemini geri alır (UI 3 sn'de sınırlar).
  OgeKaydi? geriAl() {
    final s = _son;
    final t = aktif;
    if (s == null || t == null || !t.ogeler.contains(s)) return null;
    t.ogeler.remove(s);
    if (s.durum == DurumOge.pas) _pasKullanilan--;
    _son = null;
    return s;
  }

  /// Tur sonu düzeltme: doğru ↔ pas. İhlalli öğe pas'a çevrilirse ihlal silinir.
  void duzelt(OgeKaydi o) {
    if (o.durum == DurumOge.yarim) return;
    if (o.durum == DurumOge.dogru) {
      o.durum = DurumOge.pas;
      o.ihlal = false;
    } else {
      o.durum = DurumOge.dogru;
    }
  }

  /// İhlal yalnız Doğru durumundaki öğede işaretlenebilir.
  bool ihlalIsaretle(OgeKaydi o, bool acik) {
    if (o.durum != DurumOge.dogru) return false;
    o.ihlal = acik;
    return true;
  }

  DilsizTur turuBitir() {
    final t = aktif!;
    skor[t.takim] += t.puan(pasCezali: pasCezali);
    turlar.add(t);
    aktif = null;
    return t;
  }

  List<int> kazananlar() {
    final en = skor.reduce((a, b) => a > b ? a : b);
    return [for (var i = 0; i < skor.length; i++) if (skor[i] == en) i];
  }

  /// En çok doğru bildiren anlatıcı (Mimik Ustası).
  int? mimikUstasi() {
    final m = <int, int>{};
    for (final t in turlar) {
      m[t.anlaticiId] = (m[t.anlaticiId] ?? 0) + t.dogru();
    }
    if (m.isEmpty) return null;
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.first.value > 0 ? e.first.key : null;
  }
}
