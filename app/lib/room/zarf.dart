import 'dart:convert';
import 'dart:math';

/// Sunucudan gelen zarf (api-sozlesmesi.md §2).
class SunucuMesaji {
  const SunucuMesaji(this.t, this.seq, this.now, this.p);
  final String t;
  final int seq;
  final int now;
  final Map<String, dynamic> p;

  @override
  String toString() => 'SunucuMesaji($t, seq: $seq)';
}

/// Ham metni çözer; JSON olmayan ("pong") veya biçimi bozuk ise null.
SunucuMesaji? mesajCoz(String ham) {
  if (ham.isEmpty || ham[0] != '{') return null;
  try {
    final m = jsonDecode(ham);
    if (m is! Map<String, dynamic>) return null;
    final t = m['t'];
    if (t is! String) return null;
    final p = m['p'];
    return SunucuMesaji(
      t,
      (m['seq'] as num?)?.toInt() ?? 0,
      (m['now'] as num?)?.toInt() ?? 0,
      p is Map<String, dynamic> ? p : const <String, dynamic>{},
    );
  } catch (_) {
    return null;
  }
}

String istemciMesaji(String t, Map<String, dynamic> p, String id) =>
    jsonEncode({'v': 1, 't': t, 'id': id, 'p': p});

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// ULID benzeri: 10 zaman + 16 rastgele Crockford base32 karakteri (sıralanabilir, tekil).
String yeniUlid(Random rng, {int? zamanMs}) {
  var t = zamanMs ?? DateTime.now().millisecondsSinceEpoch;
  final zaman = List<String>.filled(10, '0');
  for (var i = 9; i >= 0; i--) {
    zaman[i] = _crockford[t % 32];
    t ~/= 32;
  }
  final rastgele = List.generate(16, (_) => _crockford[rng.nextInt(32)]);
  return zaman.join() + rastgele.join();
}

/// Oda kodu girdisini normalleştirir: boşluk/tire atılır, büyük harf; karışan 0/O ve 1/I/L
/// kodda kullanılmadığı için O→0 değil, kullanıcı hatası olarak olduğu gibi bırakılır.
String odaKoduNormalle(String girdi) =>
    girdi.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool odaKoduGecerli(String kod) => RegExp(r'^[2-9A-HJKMNP-Z]{6}$').hasMatch(kod);
