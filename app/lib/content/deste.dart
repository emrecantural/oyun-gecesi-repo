import 'dart:math';

/// Tekrarsız kart destesi (A2): havuz tükenene kadar tekrar yok; tükenince
/// karıştırılıp son 10 kart dışında yeniden başlar.
class Deste<T> {
  Deste(
    Iterable<T> havuz, {
    required String Function(T) idOf,
    Set<String> gorulmus = const {},
    Random? rastgele,
    this.sonHaric = 10,
  })  : _havuz = List<T>.of(havuz),
        _idOf = idOf,
        _rng = rastgele ?? Random(),
        _gorulen = {...gorulmus} {
    _yenidenKar();
  }

  final List<T> _havuz;
  final String Function(T) _idOf;
  final Random _rng;
  final int sonHaric;
  final Set<String> _gorulen;
  final List<String> _sonCekilenler = [];
  final List<T> _kuyruk = [];
  int _yenilenme = 0;

  /// Havuz en az bir kez tükenip yeniden karıldı mı?
  int get yenilenme => _yenilenme;
  Set<String> get gorulen => Set.unmodifiable(_gorulen);
  int get havuzBoyu => _havuz.length;
  int get kalan => _kuyruk.length;

  void _yenidenKar() {
    final aday = _havuz.where((o) => !_gorulen.contains(_idOf(o))).toList()
      ..shuffle(_rng);
    _kuyruk
      ..clear()
      ..addAll(aday);
  }

  /// Sıradaki kart; havuz boşsa null.
  T? cek() {
    if (_havuz.isEmpty) return null;
    if (_kuyruk.isEmpty) {
      _yenilenme++;
      _gorulen.clear();
      // Son [sonHaric] kartı hariç tut; havuz buna yetmiyorsa hepsini al.
      final haric = _sonCekilenler.length > sonHaric
          ? _sonCekilenler.sublist(_sonCekilenler.length - sonHaric)
          : List<String>.of(_sonCekilenler);
      final aday =
          _havuz.where((o) => !haric.contains(_idOf(o))).toList();
      final kullan = aday.isEmpty ? List<T>.of(_havuz) : aday;
      kullan.shuffle(_rng);
      _kuyruk.addAll(kullan);
    }
    final kart = _kuyruk.removeAt(0);
    final id = _idOf(kart);
    _gorulen.add(id);
    _sonCekilenler.add(id);
    return kart;
  }

  /// Çekilen ama oynanmış sayılmayan kartı (değiştirme) görülmüşten çıkarır.
  void gorulmemisSay(T kart) => _gorulen.remove(_idOf(kart));
}
