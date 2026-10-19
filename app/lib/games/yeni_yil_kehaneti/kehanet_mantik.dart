import '../../core/tr_text.dart';

/// Platformdan bağımsız, sürümler arası kaymayan basit PRNG (xorshift32).
class TohumluUretec {
  TohumluUretec(int tohum) : _s = (tohum & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : (tohum & 0xFFFFFFFF);
  int _s;

  int sonraki() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s;
  }

  int aralik(int n) => sonraki() % n;
}

/// FNV-1a 32 bit: tohum + etiket -> uint32.
int tohumKarma(int tohum, String etiket) {
  var h = 0x811C9DC5 ^ (tohum & 0xFFFFFFFF);
  for (final b in etiket.codeUnits) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Fisher–Yates, tohumlu.
List<T> karistir<T>(List<T> liste, int tohum) {
  final r = TohumluUretec(tohum);
  final l = [...liste];
  for (var i = l.length - 1; i > 0; i--) {
    final j = r.aralik(i + 1);
    final t = l[i];
    l[i] = l[j];
    l[j] = t;
  }
  return l;
}

enum Karar { oldu, kismen, olmadi }

/// Oldu = 1 + (1 − (p − 1)²); Kısmen = 0,5; Olmadı = 0. İki ondalık.
double kehanetPuani(Karar k, int yuzde) {
  switch (k) {
    case Karar.olmadi:
      return 0;
    case Karar.kismen:
      return 0.5;
    case Karar.oldu:
      final p = yuzde / 100;
      final v = 1 + (1 - (p - 1) * (p - 1));
      return (v * 100).round() / 100;
  }
}

/// En çok oy; eşitlikte "Kısmen".
Karar kararVer(int oldu, int kismen, int olmadi) {
  if (oldu > kismen && oldu > olmadi) return Karar.oldu;
  if (olmadi > oldu && olmadi > kismen) return Karar.olmadi;
  if (kismen > oldu && kismen > olmadi) return Karar.kismen;
  return Karar.kismen;
}

/// Kelime BAŞI eşleşmesi (ör. "kazanacak" "kaza" ile eşleşmez: "kaza" tam kelime listesindedir).
const _yasakOnekler = [
  'hastalik', 'hastane', 'olum', 'olecek', 'oldur', 'kanser', 'ameliyat',
  'intihar', 'cenaze', 'tedavi', 'yatirim', 'borsa', 'bitcoin', 'kripto',
  'hisse sen', 'kredi', 'borc', 'bosan', 'ayril', 'aldat', 'hamile',
  'siktir', 'orospu', 'amk',
];
const _yasakTamKelime = {'kaza', 'hasta', 'doktor', 'dolar', 'altin', 'aptal', 'salak'};

/// Yasak konu / küfür denetimi: İ/ı ve aksan duyarsız.
bool tahminYasakliMi(String metin) {
  final f = foldTr(metin).replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  final kelimeler = f.split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
  final duz = ' ${kelimeler.join(' ')}';
  for (final k in kelimeler) {
    if (_yasakTamKelime.contains(k)) return true;
  }
  for (final o in _yasakOnekler) {
    if (duz.contains(' $o')) return true;
  }
  return false;
}

enum TahminHatasi { bos, uzun, yasakli }

TahminHatasi? tahminDogrula(String metin) {
  final t = metin.trim();
  if (t.isEmpty) return TahminHatasi.bos;
  if (t.length > 140) return TahminHatasi.uzun;
  if (tahminYasakliMi(t)) return TahminHatasi.yasakli;
  return null;
}

/// Varsayılan açılış: yılbaşı haftasındaysa (20 Ara–2 Oca) bir sonraki yılın,
/// aksi halde en yakın 31 Aralık 23:00 (yerel).
DateTime varsayilanAcilis(DateTime simdi) {
  DateTime yil(int y) => DateTime(y, 12, 31, 23);
  final yilbasiHaftasi =
      (simdi.month == 12 && simdi.day >= 20) || (simdi.month == 1 && simdi.day <= 2);
  if (yilbasiHaftasi) {
    // 20 Ara–31 Ara: sonraki yıl. 1–2 Oca: o yılın sonu değil, sonraki yılın değil;
    // tasarım gereği "bir sonraki yılın 31 Aralığı".
    final y = simdi.month == 12 ? simdi.year + 1 : simdi.year + 1;
    return yil(y);
  }
  final bu = yil(simdi.year);
  return bu.isAfter(simdi.add(const Duration(hours: 1))) ? bu : yil(simdi.year + 1);
}

class Tahmin {
  Tahmin({
    required this.id,
    required this.uyeId,
    required this.metin,
    required this.yuzde,
    this.kategori,
  });
  final int id;
  final int uyeId;
  final String metin;
  final int yuzde;
  final String? kategori;

  Map<String, Object?> toJson() => {
        'id': id,
        'u': uyeId,
        'm': metin,
        'y': yuzde,
        'k': kategori,
      };
  factory Tahmin.fromJson(Map<String, dynamic> j) => Tahmin(
        id: j['id'] as int,
        uyeId: j['u'] as int,
        metin: j['m'] as String,
        yuzde: j['y'] as int,
        kategori: j['k'] as String?,
      );
}

class Uye {
  Uye({required this.id, required this.ad, this.muhurlu = false, this.cekildi = false});
  final int id;
  final String ad;
  bool muhurlu;
  bool cekildi;
}

class KapsulHatasi implements Exception {
  KapsulHatasi(this.kod);
  final String kod;
  @override
  String toString() => kod;
}

class SonucSatiri {
  SonucSatiri(this.uyeId, this.puan);
  final int uyeId;
  final double puan;
}

/// Saf Dart kapsül modeli (ağ yok).
class Kapsul {
  Kapsul({
    required this.uyeler,
    required this.tahminSayisi,
    required this.acilis,
    required this.tohum,
  });

  final List<Uye> uyeler;
  final int tahminSayisi;
  final DateTime acilis;
  final int tohum;
  final List<Tahmin> _tahminler = [];
  bool kapandi = false;
  int _sonId = 0;

  List<Tahmin> taslak(int uyeId) =>
      _tahminler.where((t) => t.uyeId == uyeId).toList();

  Tahmin ekle(int uyeId, String metin, int yuzde, {String? kategori}) {
    final u = uyeler.firstWhere((u) => u.id == uyeId);
    if (u.muhurlu) throw KapsulHatasi('E_ALREADY_SEALED');
    final h = tahminDogrula(metin);
    if (h == TahminHatasi.bos) throw KapsulHatasi('E_TEXT_EMPTY');
    if (h == TahminHatasi.uzun) throw KapsulHatasi('E_TEXT_LONG');
    if (h == TahminHatasi.yasakli) throw KapsulHatasi('E_TEXT_BLOCKED');
    if (taslak(uyeId).length >= tahminSayisi) throw KapsulHatasi('E_COUNT_MISMATCH');
    final y = yuzde.clamp(10, 100);
    final t = Tahmin(
        id: ++_sonId, uyeId: uyeId, metin: metin.trim(), yuzde: y, kategori: kategori);
    _tahminler.add(t);
    return t;
  }

  void sil(int tahminId) => _tahminler.removeWhere(
      (t) => t.id == tahminId && !uyeler.firstWhere((u) => u.id == t.uyeId).muhurlu);

  void muhurle(int uyeId) {
    final u = uyeler.firstWhere((u) => u.id == uyeId);
    if (u.muhurlu) throw KapsulHatasi('E_ALREADY_SEALED');
    if (taslak(uyeId).length != tahminSayisi) throw KapsulHatasi('E_COUNT_MISMATCH');
    u.muhurlu = true;
  }

  bool get hepsiMuhurlu => uyeler.every((u) => u.muhurlu || u.cekildi);

  /// Üyenin tüm tahminlerini açılıştan çıkarır.
  void cekil(int uyeId) {
    uyeler.firstWhere((u) => u.id == uyeId).cekildi = true;
  }

  void kapat() {
    if (!hepsiMuhurlu) throw KapsulHatasi('E_COUNT_MISMATCH');
    kapandi = true;
  }

  bool acilabilir(DateTime simdi) => kapandi && !simdi.isBefore(acilis);

  /// Açılış sırası (tohumlu). Çekilenlerin tahminleri çıkar.
  List<Tahmin> acilisSirasi(DateTime simdi) {
    if (!acilabilir(simdi)) throw KapsulHatasi('E_NOT_YET');
    final cekilen = uyeler.where((u) => u.cekildi).map((u) => u.id).toSet();
    final liste = _tahminler.where((t) => !cekilen.contains(t.uyeId)).toList();
    return karistir(liste, tohumKarma(tohum, 'acilis'));
  }

  Map<String, Object?> toJson() => {
        'uyeler': [
          for (final u in uyeler)
            {'id': u.id, 'ad': u.ad, 'm': u.muhurlu, 'c': u.cekildi}
        ],
        'n': tahminSayisi,
        'a': acilis.toUtc().toIso8601String(),
        't': tohum,
        'k': kapandi,
        'tahminler': [for (final t in _tahminler) t.toJson()],
      };

  factory Kapsul.fromJson(Map<String, dynamic> j) {
    final k = Kapsul(
      uyeler: [
        for (final u in (j['uyeler'] as List))
          Uye(
            id: (u as Map)['id'] as int,
            ad: u['ad'] as String,
            muhurlu: u['m'] as bool,
            cekildi: u['c'] as bool,
          )
      ],
      tahminSayisi: j['n'] as int,
      acilis: DateTime.parse(j['a'] as String).toLocal(),
      tohum: j['t'] as int,
    );
    k.kapandi = j['k'] as bool;
    for (final t in (j['tahminler'] as List)) {
      final tt = Tahmin.fromJson(Map<String, dynamic>.from(t as Map));
      k._tahminler.add(tt);
      if (tt.id > k._sonId) k._sonId = tt.id;
    }
    return k;
  }
}
