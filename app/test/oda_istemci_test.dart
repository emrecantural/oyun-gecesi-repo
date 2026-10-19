import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/room/oda_istemci.dart';
import 'package:oyungecesi/room/zarf.dart';

class SahteTasima implements OdaTasimasi {
  final gidenler = <String>[];
  late void Function(String) gelen;
  late void Function(int?, String?) kapandi;
  bool kapali = false;

  @override
  Future<void> baglan(
    Uri url, {
    required void Function(String ham) gelen,
    required void Function(int? kod, String? neden) kapandi,
  }) async {
    this.gelen = gelen;
    this.kapandi = kapandi;
  }

  @override
  void gonder(String ham) => gidenler.add(ham);

  @override
  Future<void> kapat() async => kapali = true;

  void sunucu(String t, Map<String, dynamic> p, {int seq = 1}) =>
      gelen(jsonEncode({'v': 1, 't': t, 'seq': seq, 'now': 1000, 'p': p}));
}

Map<String, dynamic> hosgeldin() => {
      'playerId': 'p1',
      'resumeToken': 'tok1',
      'hostId': 'p1',
      'role': 'player',
      'settings': {'a': 1},
      'snapshot': {
        'game': '07',
        'phase': 'LOBBY',
        'public': <String, dynamic>{},
        'roster': {
          'players': [
            {'id': 'p1', 'nickname': 'Ali', 'color': 2, 'connected': true, 'ready': false, 'host': true},
          ],
          'displays': 0,
        },
      },
    };

void main() {
  test('ULID 26 karakter ve zamana göre sıralanır', () {
    final r = Random(1);
    final a = yeniUlid(r, zamanMs: 1000);
    final b = yeniUlid(r, zamanMs: 2000);
    expect(a.length, 26);
    expect(a.compareTo(b) < 0, isTrue);
  });

  test('oda kodu normalleştirme ve doğrulama', () {
    expect(odaKoduNormalle(' ab-c d23 '), 'ABCD23');
    expect(odaKoduGecerli('ABCD23'), isTrue);
    expect(odaKoduGecerli('ABCD20'), isFalse);
    expect(odaKoduGecerli('ABC'), isFalse);
  });

  test('mesajCoz: pong ve bozuk girdi null', () {
    expect(mesajCoz('pong'), isNull);
    expect(mesajCoz('{bozuk'), isNull);
    expect(mesajCoz('{"t":"x","seq":3,"now":5,"p":{}}')?.seq, 3);
  });

  test('katılım join gönderir, welcome durumu doldurur', () async {
    final t = SahteTasima();
    final i = OdaIstemcisi(tasimaUret: () => t, rng: Random(1));
    await i.katil(
      wsUrl: Uri.parse('wss://x/v1/ws/ABCD23'),
      kod: 'ABCD23',
      takmaAd: 'Ali',
      installId: 'inst',
    );
    final join = jsonDecode(t.gidenler.first) as Map<String, dynamic>;
    expect(join['t'], 'join');
    expect((join['p'] as Map)['nickname'], 'Ali');
    t.sunucu('welcome', hosgeldin());
    expect(i.durum, BaglantiDurumu.bagli);
    expect(i.hostMu, isTrue);
    expect(i.resumeToken, 'tok1');
    expect(i.oyuncular.single.takmaAd, 'Ali');
    expect(i.oyunId, '07');
    i.dispose();
  });

  test('kopunca resume ile yeniden bağlanır', () async {
    final tasimalar = <SahteTasima>[];
    final i = OdaIstemcisi(
      tasimaUret: () {
        final t = SahteTasima();
        tasimalar.add(t);
        return t;
      },
      rng: Random(1),
      geriCekilmeler: const [0],
    );
    await i.katil(
      wsUrl: Uri.parse('wss://x'),
      kod: 'ABCD23',
      takmaAd: 'Ali',
      installId: 'inst',
    );
    tasimalar[0].sunucu('welcome', hosgeldin(), seq: 5);
    tasimalar[0].kapandi(1006, null);
    expect(i.durum, BaglantiDurumu.yenidenBaglaniyor);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(tasimalar.length, 2);
    final resume = jsonDecode(tasimalar[1].gidenler.first) as Map<String, dynamic>;
    expect(resume['t'], 'resume');
    expect((resume['p'] as Map)['resumeToken'], 'tok1');
    expect((resume['p'] as Map)['lastSeq'], 5);
    i.dispose();
  });

  test('PLAYER_KICKED hatası yeniden bağlanmayı durdurur', () async {
    final t = SahteTasima();
    final i = OdaIstemcisi(tasimaUret: () => t, rng: Random(1), geriCekilmeler: const [0]);
    await i.katil(wsUrl: Uri.parse('wss://x'), kod: 'ABCD23', takmaAd: 'Ali', installId: 'inst');
    t.sunucu('welcome', hosgeldin());
    t.sunucu('error', {'code': 'PLAYER_KICKED'}, seq: 2);
    expect(i.durum, BaglantiDurumu.kapali);
    expect(i.kapanisNedeni, 'PLAYER_KICKED');
    i.dispose();
  });

  test('gonder yalnız bağlıyken id döndürür', () async {
    final t = SahteTasima();
    final i = OdaIstemcisi(tasimaUret: () => t, rng: Random(1));
    await i.katil(wsUrl: Uri.parse('wss://x'), kod: 'ABCD23', takmaAd: 'Ali', installId: 'inst');
    expect(i.gonder('ready'), isNull);
    t.sunucu('welcome', hosgeldin());
    final id = i.gonder('ready', {'ready': true});
    expect(id, isNotNull);
    expect((jsonDecode(t.gidenler.last) as Map)['id'], id);
    i.dispose();
  });
}
