import 'dart:math';

enum Rol { kurt, kahin, doktor, cadi, avci, asik, koylu }

const rolAdi = {
  Rol.kurt: 'Kurt',
  Rol.kahin: 'Kâhin',
  Rol.doktor: 'Doktor',
  Rol.cadi: 'Cadı',
  Rol.avci: 'Avcı',
  Rol.asik: 'Âşık',
  Rol.koylu: 'Köylü',
};

enum Taraf { koy, kurtlar }

/// Rol paketi tablosu (03-koy-ve-kurtlar.md): n = 6..20.
Map<Rol, int> varsayilanRolPaketi(int n) {
  assert(n >= 6 && n <= 20);
  final kurt = n <= 11 ? 2 : (n <= 15 ? 3 : (n <= 19 ? 4 : 5));
  final avci = n >= 8 ? 1 : 0;
  final asik = n >= 10 ? 2 : 0;
  final cadi = n >= 12 ? 1 : 0;
  final koylu = n - kurt - 1 - 1 - avci - asik - cadi;
  return {
    Rol.kurt: kurt,
    Rol.kahin: 1,
    Rol.doktor: 1,
    Rol.cadi: cadi,
    Rol.avci: avci,
    Rol.asik: asik,
    Rol.koylu: koylu,
  };
}

class KoyAyarlar {
  const KoyAyarlar({
    this.acikOylama = true,
    this.oluncRoluAc = true,
    this.esitOyYenidenOy = false,
    this.doktorKendiniKorur = true,
  });
  final bool acikOylama;
  final bool oluncRoluAc;
  final bool esitOyYenidenOy;
  final bool doktorKendiniKorur;
}

enum OlumNedeni { kurt, zehir, askZinciri, oylama, avci }

class Olum {
  Olum(this.id, this.neden);
  final int id;
  final OlumNedeni neden;
}

class GeceSonucu {
  GeceSonucu(this.olumler, this.avciBekliyor);
  final List<Olum> olumler;
  final int? avciBekliyor;
}

class KoyHatasi implements Exception {
  KoyHatasi(this.kod);
  final String kod;
  @override
  String toString() => kod;
}

/// Saf Dart oyun motoru. Aynı kural kümesi ROOM sunucusunda (TypeScript) uygulanır;
/// `test/koy_mantik_test.dart` altın vektörleri iki tarafı bağlar.
class KoyOyunu {
  KoyOyunu({
    required List<int> oyuncuIdleri,
    Map<Rol, int>? rolPaketi,
    this.ayar = const KoyAyarlar(),
    int? tohum,
  }) : oyuncular = List.of(oyuncuIdleri) {
    final n = oyuncuIdleri.length;
    final paket = rolPaketi ?? varsayilanRolPaketi(n);
    if (paket.values.fold<int>(0, (a, b) => a + b) != n) {
      throw KoyHatasi('ROLEPACK_MISMATCH');
    }
    final havuz = <Rol>[
      for (final e in paket.entries)
        for (var i = 0; i < e.value; i++) e.key
    ];
    final rng = Random(tohum);
    // Fisher–Yates
    for (var i = havuz.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = havuz[i];
      havuz[i] = havuz[j];
      havuz[j] = t;
    }
    for (var i = 0; i < n; i++) {
      roller[oyuncuIdleri[i]] = havuz[i];
    }
    final asiklar = [for (final id in oyuncuIdleri) if (roller[id] == Rol.asik) id];
    if (asiklar.length == 2) {
      ask[asiklar[0]] = asiklar[1];
      ask[asiklar[1]] = asiklar[0];
    }
  }

  final KoyAyarlar ayar;
  final List<int> oyuncular; // koltuk sırası
  final Map<int, Rol> roller = {};
  final Map<int, int> ask = {}; // âşık → eşi
  final Set<int> olu = {};
  final List<Olum> tumOlumler = [];
  int gece = 0;

  // Cadı iksirleri
  bool iyilestirmeVar = true;
  bool zehirVar = true;

  // Gece durumu
  final Map<int, int> _kurtOylari = {};
  int? _korunan;
  int? _sonKorunan;
  int? _zehirHedef;
  bool _iyilestirildi = false;
  final Set<int> _kahinSorgu = {};

  // Oy durumu
  final Map<int, int?> _oylar = {};
  final Map<int, int> suphecilik = {}; // kurda doğru oy sayısı

  bool canli(int id) => !olu.contains(id);
  List<int> get canlilar => [for (final id in oyuncular) if (canli(id)) id];
  List<int> get kurtlar => [for (final id in oyuncular) if (roller[id] == Rol.kurt) id];
  List<int> get canliKurtlar => [for (final id in kurtlar) if (canli(id)) id];

  void geceBasla() {
    gece++;
    _kurtOylari.clear();
    _korunan = null;
    _zehirHedef = null;
    _iyilestirildi = false;
    _kahinSorgu.clear();
  }

  // ---- gece eylemleri ----
  /// Kâhin: kurt mu? (gece başına bir sorgu; ilk kilitlenir)
  bool kahinSorgula(int actor, int hedef) {
    if (roller[actor] != Rol.kahin || !canli(actor)) throw KoyHatasi('NOT_YOUR_ROLE');
    if (!canli(hedef) || hedef == actor) throw KoyHatasi('INVALID_TARGET');
    if (_kahinSorgu.contains(actor)) throw KoyHatasi('ALREADY_ACTED');
    _kahinSorgu.add(actor);
    return roller[hedef] == Rol.kurt;
  }

  void kurtOyu(int actor, int hedef) {
    if (roller[actor] != Rol.kurt || !canli(actor)) throw KoyHatasi('NOT_YOUR_ROLE');
    if (!canli(hedef) || roller[hedef] == Rol.kurt) throw KoyHatasi('INVALID_TARGET');
    _kurtOylari[actor] = hedef;
  }

  Map<int, int> get kurtOylari => Map.unmodifiable(_kurtOylari);

  void koru(int actor, int hedef) {
    if (roller[actor] != Rol.doktor || !canli(actor)) throw KoyHatasi('NOT_YOUR_ROLE');
    if (!canli(hedef)) throw KoyHatasi('INVALID_TARGET');
    if (hedef == actor && !ayar.doktorKendiniKorur) throw KoyHatasi('DOCTOR_SELF_OFF');
    if (hedef == _sonKorunan) throw KoyHatasi('DOCTOR_REPEAT');
    _korunan = hedef;
  }

  /// Kurtların hedefi: en çok oy; eşitlikte kurban yok.
  int? get kurbanHedefi {
    if (_kurtOylari.isEmpty) return null;
    final sayim = <int, int>{};
    for (final h in _kurtOylari.values) {
      sayim[h] = (sayim[h] ?? 0) + 1;
    }
    final en = sayim.values.reduce(max);
    final adaylar = [for (final e in sayim.entries) if (e.value == en) e.key];
    return adaylar.length == 1 ? adaylar.first : null;
  }

  void cadiIyilestir(int actor) {
    if (roller[actor] != Rol.cadi || !canli(actor)) throw KoyHatasi('NOT_YOUR_ROLE');
    if (!iyilestirmeVar) throw KoyHatasi('POTION_USED');
    if (kurbanHedefi == null) throw KoyHatasi('INVALID_TARGET');
    iyilestirmeVar = false;
    _iyilestirildi = true;
  }

  void cadiZehirle(int actor, int hedef) {
    if (roller[actor] != Rol.cadi || !canli(actor)) throw KoyHatasi('NOT_YOUR_ROLE');
    if (!zehirVar) throw KoyHatasi('POTION_USED');
    if (!canli(hedef) || hedef == actor) throw KoyHatasi('INVALID_TARGET');
    zehirVar = false;
    _zehirHedef = hedef;
  }

  /// Gece çözümü: kurt hedefi (koruma / iyileştirme) → zehir → âşık zinciri → avcı.
  GeceSonucu geceyiCoz() {
    final olumler = <Olum>[];
    final kurban = kurbanHedefi;
    if (kurban != null && kurban != _korunan && !_iyilestirildi) {
      olumler.add(Olum(kurban, OlumNedeni.kurt));
    }
    final z = _zehirHedef;
    if (z != null && !olumler.any((o) => o.id == z)) {
      olumler.add(Olum(z, OlumNedeni.zehir));
    }
    final zincir = _askZinciri(olumler);
    olumler.addAll(zincir);
    for (final o in olumler) {
      olu.add(o.id);
      tumOlumler.add(o);
    }
    _sonKorunan = _korunan;
    final avci = olumler.map((o) => o.id).where((id) => roller[id] == Rol.avci).firstOrNull;
    return GeceSonucu(olumler, avci);
  }

  List<Olum> _askZinciri(List<Olum> olumler) {
    final yeni = <Olum>[];
    for (final o in olumler) {
      final es = ask[o.id];
      if (es != null && canli(es) && !olumler.any((x) => x.id == es) && !yeni.any((x) => x.id == es)) {
        yeni.add(Olum(es, OlumNedeni.askZinciri));
      }
    }
    return yeni;
  }

  // ---- gündüz ----
  void oyBaslat() {
    _oylar.clear();
  }

  void oyVer(int voter, int? hedef) {
    if (!canli(voter)) throw KoyHatasi('NOT_ALIVE');
    if (hedef != null) {
      if (!canli(hedef)) throw KoyHatasi('INVALID_TARGET');
      if (hedef == voter) throw KoyHatasi('SELF_TARGET_FORBIDDEN');
    }
    _oylar[voter] = hedef;
  }

  Map<int, int> oySayilari() {
    final m = <int, int>{};
    for (final h in _oylar.values) {
      if (h != null) m[h] = (m[h] ?? 0) + 1;
    }
    return m;
  }

  Map<int, int?> get oylar => Map.unmodifiable(_oylar);

  /// En çok oy alan; eşitlikte null. Eleneni ve zincir ölümlerini işler.
  /// [eşit] listesi yeniden oy için döner.
  ({List<Olum> olumler, int? avci, List<int> esitAdaylar}) oylamayiBitir() {
    final sayim = oySayilari();
    if (sayim.isEmpty) return (olumler: <Olum>[], avci: null, esitAdaylar: <int>[]);
    final en = sayim.values.reduce(max);
    final adaylar = [for (final e in sayim.entries) if (e.value == en) e.key];
    if (adaylar.length > 1) {
      return (olumler: <Olum>[], avci: null, esitAdaylar: adaylar);
    }
    final elenen = adaylar.first;
    // Şüpheci: kurda doğru oy verenler
    if (roller[elenen] == Rol.kurt) {
      for (final e in _oylar.entries) {
        if (e.value == elenen) suphecilik[e.key] = (suphecilik[e.key] ?? 0) + 1;
      }
    }
    final olumler = [Olum(elenen, OlumNedeni.oylama)];
    olumler.addAll(_askZinciri(olumler));
    for (final o in olumler) {
      olu.add(o.id);
      tumOlumler.add(o);
    }
    final avci = olumler.map((o) => o.id).where((id) => roller[id] == Rol.avci).firstOrNull;
    return (olumler: olumler, avci: avci, esitAdaylar: <int>[]);
  }

  /// Avcının son atışı. Âşık zinciri işler.
  List<Olum> avciVur(int avci, int? hedef) {
    if (roller[avci] != Rol.avci) throw KoyHatasi('NOT_YOUR_ROLE');
    if (hedef == null) return const [];
    if (!canli(hedef)) throw KoyHatasi('INVALID_TARGET');
    final olumler = [Olum(hedef, OlumNedeni.avci)];
    olumler.addAll(_askZinciri(olumler));
    for (final o in olumler) {
      olu.add(o.id);
      tumOlumler.add(o);
    }
    return olumler;
  }

  /// Kazanma: tüm kurtlar elendi → köy; kurt sayısı ≥ diğer canlılar → kurtlar.
  Taraf? kazanan() {
    final k = canliKurtlar.length;
    final diger = canlilar.length - k;
    if (k == 0) return Taraf.koy;
    if (k >= diger) return Taraf.kurtlar;
    return null;
  }

  int? enIyiYalanci() {
    final hayatta = canliKurtlar;
    return hayatta.isEmpty ? null : hayatta.first;
  }

  int? supheci() {
    if (suphecilik.isEmpty) return null;
    final e = suphecilik.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.first.key;
  }
}
