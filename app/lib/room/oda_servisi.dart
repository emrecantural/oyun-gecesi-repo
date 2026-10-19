import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'oda_istemci.dart';

/// Sunucu adresi derleme zamanında verilir: `--dart-define=SUNUCU_URL=https://...`.
/// Boşsa oda özellikleri kapalıdır ("sunucu ayarlı değil").
const sunucuUrl = String.fromEnvironment('SUNUCU_URL');
bool get sunucuAyarli => sunucuUrl.isNotEmpty;

class OdaHatasi implements Exception {
  const OdaHatasi(this.kod);
  final String kod;
  @override
  String toString() => 'OdaHatasi($kod)';
}

/// Hata kodlarının kullanıcıya gösterilen Türkçe karşılıkları.
String hataMetni(String? kod) => switch (kod) {
      'NO_ROOM_RIGHT' => 'Oda kurmak için oda hakkı gerekiyor. Bir arkadaşının kurduğu odaya katılabilirsin.',
      'NO_SERVER' => 'Sunucu ayarlı değil. Bu sürümde çevrimiçi oda kapalı.',
      'ROOM_NOT_FOUND' => 'Oda bulunamadı. Kodu kontrol et.',
      'ROOM_FULL' => 'Oda dolu.',
      'LATE_JOIN_CLOSED' => 'Oyun başladı, bu odaya artık katılamazsın.',
      'NICKNAME_REJECTED' => 'Bu takma ad kullanılamıyor. 2–16 karakter, uygun bir ad dene.',
      'PLAYER_KICKED' => 'Odadan çıkarıldın.',
      'SUPERSEDED' => 'Başka bir cihazdan bağlandın.',
      'UPGRADE_REQUIRED' => 'Uygulamayı güncellemen gerekiyor.',
      'GAME_NOT_ONLINE' => 'Bu oyun henüz çevrimiçi oynanamıyor.',
      'RATE_LIMITED' => 'Çok hızlı gidiyorsun, biraz bekle.',
      'baglanamadi' => 'Sunucuya bağlanılamadı. İnternetini kontrol et.',
      _ => 'Bir sorun oluştu. Tekrar dene.',
    };

class OdaGirisi {
  const OdaGirisi({
    required this.kod,
    required this.wsUrl,
    required this.takmaAd,
    required this.installId,
    this.rol = 'player',
    this.resumeToken,
  });
  final String kod;
  final Uri wsUrl;
  final String takmaAd;
  final String installId;
  final String rol;
  final String? resumeToken;
}

/// Uygulama kurulumuna özgü rastgele kimlik (hesap yok). Silinirse yenisi üretilir.
Future<String> installIdAl() async {
  const anahtar = 'install_id';
  try {
    final prefs = SharedPreferencesAsync();
    final mevcut = await prefs.getString(anahtar);
    if (mevcut != null && mevcut.length >= 8) return mevcut;
    final r = Random.secure();
    final yeni = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
    await prefs.setString(anahtar, yeni);
    return yeni;
  } catch (_) {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}

Uri _taban() {
  if (!sunucuAyarli) throw const OdaHatasi('NO_SERVER');
  return Uri.parse(sunucuUrl);
}

Uri wsAdresi(String kod) {
  final t = _taban();
  return Uri(
    scheme: t.scheme == 'http' ? 'ws' : 'wss',
    host: t.host,
    port: t.hasPort ? t.port : null,
    path: '/v1/ws/$kod',
  );
}

Future<Map<String, dynamic>> _istek(String metod, String yol, [Object? govde]) async {
  final taban = _taban();
  final istemci = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final uri = taban.replace(path: yol);
    final r = await (metod == 'POST' ? istemci.postUrl(uri) : istemci.getUrl(uri)).timeout(const Duration(seconds: 8));
    if (govde != null) {
      r.headers.contentType = ContentType.json;
      r.write(jsonEncode(govde));
    }
    final y = await r.close().timeout(const Duration(seconds: 10));
    final metin = await y.transform(utf8.decoder).join();
    Map<String, dynamic> j;
    try {
      j = jsonDecode(metin) as Map<String, dynamic>;
    } catch (_) {
      j = const {};
    }
    if (y.statusCode >= 400) throw OdaHatasi(j['error'] as String? ?? 'INTERNAL');
    return j;
  } on OdaHatasi {
    rethrow;
  } catch (_) {
    throw const OdaHatasi('baglanamadi');
  } finally {
    istemci.close(force: true);
  }
}

/// Oda kurar; kurucu zaten odaya "host" olarak eklenmiştir, ilk resume belirteci döner.
Future<OdaGirisi> odaKur({
  required String oyunId,
  required String takmaAd,
  required String installId,
  Map<String, dynamic>? ayarlar,
}) async {
  final j = await _istek('POST', '/v1/rooms', {
    'game': oyunId,
    'nickname': takmaAd,
    'installId': installId,
    if (ayarlar != null) 'settings': ayarlar,
  });
  final kod = j['code'] as String;
  return OdaGirisi(
    kod: kod,
    wsUrl: wsAdresi(kod),
    takmaAd: takmaAd,
    installId: installId,
    resumeToken: j['joinToken'] as String?,
  );
}

/// Katılmadan önce oda özeti (var mı, dolu mu).
Future<Map<String, dynamic>> odaOzeti(String kod) => _istek('GET', '/v1/rooms/$kod');

/// `dart:io` WebSocket taşıması.
class WebSocketTasima implements OdaTasimasi {
  WebSocket? _ws;
  StreamSubscription<dynamic>? _abone;

  @override
  Future<void> baglan(
    Uri url, {
    required void Function(String ham) gelen,
    required void Function(int? kod, String? neden) kapandi,
  }) async {
    final ws = await WebSocket.connect(url.toString()).timeout(const Duration(seconds: 10));
    _ws = ws;
    _abone = ws.listen(
      (d) {
        if (d is String) gelen(d);
      },
      onDone: () => kapandi(ws.closeCode, ws.closeReason),
      onError: (_) => kapandi(null, 'hata'),
      cancelOnError: true,
    );
  }

  @override
  void gonder(String ham) {
    try {
      _ws?.add(ham);
    } catch (_) {}
  }

  @override
  Future<void> kapat() async {
    await _abone?.cancel();
    _abone = null;
    try {
      await _ws?.close(1000);
    } catch (_) {}
    _ws = null;
  }
}
