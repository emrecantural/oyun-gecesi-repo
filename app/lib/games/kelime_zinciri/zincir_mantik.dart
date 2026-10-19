import '../../core/tr_text.dart';

const zincirHarfleri = [
  'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H', 'I', 'İ', 'J', 'K', 'L',
  'M', 'N', 'O', 'Ö', 'P', 'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
];

/// â, î, û → düz harf; diğerleri büyük harfe (tr).
String zincirHarfNorm(String ch) {
  const map = {'â': 'a', 'Â': 'A', 'î': 'i', 'Î': 'İ', 'û': 'u', 'Û': 'U'};
  final d = map[ch] ?? ch;
  return trUpper(d);
}

class Elenen {
  Elenen(this.id, this.kelimeNo);
  final int id;
  final int kelimeNo;
}

class ZincirOyunu {
  ZincirOyunu({
    required List<int> oyuncuIdleri,
    required this.baslangicMs,
    required this.azalmaMs,
    required this.minMs,
    this.can = 1, // 1 = tek hata, 3 = can
    this.ilkHarf,
  })  : assert(oyuncuIdleri.length >= 2),
        _canlar = {for (final id in oyuncuIdleri) id: can},
        sira = List.of(oyuncuIdleri),
        need = ilkHarf;

  final int baslangicMs;
  final int azalmaMs;
  final int minMs;
  final int can;
  final String? ilkHarf;

  /// Hayatta olanlar, oyun sırasıyla.
  final List<int> sira;
  final Map<int, int> _canlar;
  int idx = 0;
  int cevrim = 0;

  /// Gereken harf; null = serbest.
  String? need;
  int kelimeSayisi = 0;
  final List<Elenen> elenenler = [];
  final List<({int id, String ch})> zincir = [];
  final Map<int, int> gecerliKelime = {};
  final Map<int, int> sonNefes = {};

  int get aktifId => sira[idx];
  bool get bitti => sira.length <= 1;
  int? get kazanan => bitti ? sira.first : null;
  int canOf(int id) => _canlar[id] ?? 0;

  /// limit = max(min, başlangıç − azalma × çevrim)
  int get limitMs {
    final v = baslangicMs - azalmaMs * cevrim;
    return v < minMs ? minMs : v;
  }

  void _ilerle({required bool elendi}) {
    if (elendi) {
      sira.removeAt(idx);
      if (sira.isEmpty) return;
      if (idx >= sira.length) {
        idx = 0;
        cevrim++;
      }
    } else {
      idx++;
      if (idx >= sira.length) {
        idx = 0;
        cevrim++;
      }
    }
  }

  /// Geçerli kelime: son harf girilir; süre kalan ms ile (Son Nefes için).
  void kabul(String sonHarf, {required int kalanMs}) {
    final ch = zincirHarfNorm(sonHarf);
    if (!zincirHarfleri.contains(ch)) throw ArgumentError('LETTER_INVALID');
    final id = aktifId;
    kelimeSayisi++;
    zincir.add((id: id, ch: ch));
    gecerliKelime[id] = (gecerliKelime[id] ?? 0) + 1;
    if (kalanMs < 3000) sonNefes[id] = (sonNefes[id] ?? 0) + 1;
    need = ch == 'Ğ' ? null : ch;
    _ilerle(elendi: false);
  }

  /// Hata (süre doldu / geçersiz): can düşer ya da elenir; gereken harf korunur.
  /// true dönerse oyuncu elendi.
  bool hata() {
    final id = aktifId;
    final kalan = (_canlar[id] ?? 1) - 1;
    _canlar[id] = kalan;
    if (kalan <= 0) {
      elenenler.add(Elenen(id, kelimeSayisi + 1));
      _ilerle(elendi: true);
      return true;
    }
    _ilerle(elendi: false);
    return false;
  }

  /// Oylama: ✕ > ✓ ise geçersiz; eşitlik ve oy yoksa geçerli.
  static bool oyGecerli(int gecerli, int gecersiz) => gecersiz <= gecerli;

  int? kelimeHazinesi() => _enCok(gecerliKelime);
  int? sonNefesRozeti() => _enCok(sonNefes);

  int? _enCok(Map<int, int> m) {
    if (m.isEmpty) return null;
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.first.value > 0 ? e.first.key : null;
  }

  /// İlk harf: kategori listesindeki ilk harf sıklığına göre ağırlıklı; Ğ asla.
  static String ilkHarfSec(List<String> kelimeler, int rnd) {
    final sayim = <String, int>{};
    for (final k in kelimeler) {
      final n = trUpper(k.trim());
      if (n.isEmpty) continue;
      final ch = zincirHarfNorm(n[0]);
      if (ch == 'Ğ' || !zincirHarfleri.contains(ch)) continue;
      sayim[ch] = (sayim[ch] ?? 0) + 1;
    }
    final uygun = sayim.entries.where((e) => e.value >= 3).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (uygun.isEmpty) return 'A';
    final toplam = uygun.fold<int>(0, (t, e) => t + e.value);
    var x = rnd.abs() % toplam;
    for (final e in uygun) {
      if (x < e.value) return e.key;
      x -= e.value;
    }
    return uygun.last.key;
  }
}
