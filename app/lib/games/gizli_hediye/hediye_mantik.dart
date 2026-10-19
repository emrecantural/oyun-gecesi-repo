import 'dart:math';

class HediyeHata implements Exception {
  HediyeHata(this.kod);
  final String kod;
  @override
  String toString() => 'HediyeHata($kod)';
}

/// 24 Gizli Hediye Çekilişi — saf mantık. Tek halka kurar; kimse kendini
/// çekmez, hariç tutulan çiftler (simetrik) eşleşmez.
class HediyeCekilisi {
  HediyeCekilisi({Random? rastgele}) : _rng = rastgele ?? Random.secure();

  final Random _rng;
  final List<int> katilimcilar = [];
  final Set<String> _haric = {};
  bool kilitli = false;
  Map<int, int>? _atama; // giver → receiver
  final Map<int, int> goruntulenme = {};

  static String _anahtar(int a, int b) => a < b ? '$a-$b' : '$b-$a';

  List<(int, int)> get haricCiftler => [
        for (final k in _haric)
          (int.parse(k.split('-')[0]), int.parse(k.split('-')[1])),
      ];

  void katilimciEkle(int id) {
    if (kilitli) throw HediyeHata('E_LOCKED');
    if (katilimcilar.length >= 50) throw HediyeHata('E_MAX_PARTICIPANTS');
    katilimcilar.add(id);
  }

  void katilimciCikar(int id) {
    if (kilitli) throw HediyeHata('E_LOCKED');
    katilimcilar.remove(id);
    _haric.removeWhere((k) => k.split('-').contains('$id'));
  }

  void haricEkle(int a, int b) {
    if (kilitli) throw HediyeHata('E_LOCKED');
    if (a == b) throw HediyeHata('E_PAIR_SAME');
    _haric.add(_anahtar(a, b));
  }

  void haricKaldir(int a, int b) {
    if (kilitli) throw HediyeHata('E_LOCKED');
    _haric.remove(_anahtar(a, b));
  }

  bool yasak(int a, int b) => a == b || _haric.contains(_anahtar(a, b));

  bool get cekildi => _atama != null;

  /// Çekilişi yapar. Sonuç yoksa `E_UNSOLVABLE`.
  void cek({Duration sinir = const Duration(seconds: 2)}) {
    if (kilitli) throw HediyeHata('E_LOCKED');
    final n = katilimcilar.length;
    if (n < 3) throw HediyeHata('E_MIN_PARTICIPANTS');
    if (n > 50) throw HediyeHata('E_MAX_PARTICIPANTS');

    // 1) Sattolo ile tek halka, yasak kenar varsa yeniden dene.
    for (var deneme = 0; deneme < 1000; deneme++) {
      final sira = [...katilimcilar];
      for (var i = sira.length - 1; i > 0; i--) {
        final j = _rng.nextInt(i); // 0..i-1 → tek devirli permütasyon
        final t = sira[i];
        sira[i] = sira[j];
        sira[j] = t;
      }
      if (_gecerliHalka(sira)) {
        _kaydet(sira);
        return;
      }
    }
    // 2) Geri izleme (Hamilton halkası) zaman sınırıyla.
    final sw = Stopwatch()..start();
    final yol = <int>[katilimcilar.first];
    final kullanilan = <int>{katilimcilar.first};
    bool dfs() {
      if (sw.elapsed > sinir) return false;
      if (yol.length == n) return !yasak(yol.last, yol.first);
      final adaylar = katilimcilar
          .where((k) => !kullanilan.contains(k) && !yasak(yol.last, k))
          .toList()
        ..shuffle(_rng);
      for (final k in adaylar) {
        yol.add(k);
        kullanilan.add(k);
        if (dfs()) return true;
        yol.removeLast();
        kullanilan.remove(k);
      }
      return false;
    }

    if (dfs()) {
      _kaydet(yol);
      return;
    }
    throw HediyeHata('E_UNSOLVABLE');
  }

  bool _gecerliHalka(List<int> sira) {
    for (var i = 0; i < sira.length; i++) {
      if (yasak(sira[i], sira[(i + 1) % sira.length])) return false;
    }
    return true;
  }

  void _kaydet(List<int> sira) {
    _atama = {
      for (var i = 0; i < sira.length; i++) sira[i]: sira[(i + 1) % sira.length],
    };
    goruntulenme
      ..clear()
      ..addEntries(sira.map((id) => MapEntry(id, 0)));
  }

  /// Çekilişi iptal et: yalnız hiç görüntülenmediyse.
  void iptal() {
    if (kilitli) throw HediyeHata('E_LOCKED');
    _atama = null;
    goruntulenme.clear();
  }

  /// Yalnız o kişinin alıcısını döndürür; sayaç artar ve çekiliş kilitlenir.
  int goster(int vericiId) {
    final a = _atama;
    if (a == null) throw HediyeHata('NOT_DRAWN');
    final alici = a[vericiId];
    if (alici == null) throw HediyeHata('NO_SUCH_PARTICIPANT');
    kilitli = true;
    goruntulenme[vericiId] = (goruntulenme[vericiId] ?? 0) + 1;
    return alici;
  }

  int get bakanSayisi => goruntulenme.values.where((v) => v > 0).length;
  bool get herkesBakti =>
      _atama != null && bakanSayisi == katilimcilar.length;

  /// Bitir ve sil.
  void sil() {
    _atama = null;
    goruntulenme.clear();
    katilimcilar.clear();
    _haric.clear();
    kilitli = false;
  }

  /// Testler için: eşleşme tablosunun kopyası (arayüz kullanmaz).
  Map<int, int> testIcinAtama() => {...?_atama};
}
