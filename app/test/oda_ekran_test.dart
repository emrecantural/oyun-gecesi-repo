import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/app/theme.dart';
import 'package:oyungecesi/room/oda_ekranlari.dart';
import 'package:oyungecesi/room/oda_istemci.dart';
import 'package:oyungecesi/room/oda_servisi.dart';

class _Tasima implements OdaTasimasi {
  final gidenler = <String>[];
  late void Function(String) gelen;

  @override
  Future<void> baglan(
    Uri url, {
    required void Function(String ham) gelen,
    required void Function(int? kod, String? neden) kapandi,
  }) async {
    this.gelen = gelen;
  }

  @override
  void gonder(String ham) => gidenler.add(ham);

  @override
  Future<void> kapat() async {}

  void sunucu(String t, Map<String, dynamic> p, {int seq = 1}) =>
      gelen(jsonEncode({'v': 1, 't': t, 'seq': seq, 'now': 1000, 'p': p}));
}

Map<String, dynamic> _oyuncu(String id, String ad, {bool host = false}) =>
    {'id': id, 'nickname': ad, 'role': 'player', 'color': 1, 'connected': true, 'ready': false, 'host': host};

Map<String, dynamic> _welcome({String phase = 'LOBBY', Map<String, dynamic>? acik}) => {
      'playerId': 'p1',
      'resumeToken': 'tok',
      'hostId': 'p1',
      'role': 'player',
      'settings': {'kendineOy': 'yasak'},
      'snapshot': {
        'game': '07',
        'phase': phase,
        'public': acik ?? <String, dynamic>{},
        'roster': {
          'players': [_oyuncu('p1', 'Ali', host: true), _oyuncu('p2', 'Bora')],
          'displays': 0,
        },
      },
    };

Future<_Tasima> _ac(WidgetTester tester) async {
  final t = _Tasima();
  await tester.pumpWidget(MaterialApp(
    theme: acikTema(),
    home: OdaEkrani(
      giris: OdaGirisi(
        kod: 'ABCD23',
        wsUrl: Uri.parse('wss://x/v1/ws/ABCD23'),
        takmaAd: 'Ali',
        installId: 'install-1234',
        resumeToken: 'tok',
      ),
      tasimaUret: () => t,
    ),
  ));
  await tester.pump();
  return t;
}

void main() {
  testWidgets('lobi: kod, oyuncular ve başlat koşulu görünür', (tester) async {
    final t = await _ac(tester);
    t.sunucu('welcome', _welcome());
    await tester.pump();
    expect(find.text('ABCD23'), findsOneWidget);
    expect(find.textContaining('Ali'), findsWidgets);
    expect(find.text('Bora'), findsOneWidget);
    expect(find.text('En az 3 oyuncu gerek'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('07 oylama: soru görünür, seçim vote gönderir', (tester) async {
    final t = await _ac(tester);
    t.sunucu(
      'welcome',
      _welcome(phase: 'OY', acik: {
        'idx': 1,
        'total': 10,
        'question': {'qId': 'q1', 'text': 'Kim en çok uyur?', 'category': 'x'},
        'voteProgress': {'votedCount': 0, 'total': 2},
      }),
    );
    await tester.pump();
    expect(find.text('Kim en çok uyur?'), findsOneWidget);
    await tester.tap(find.text('Bora'));
    await tester.pump();
    final vote = t.gidenler.map((e) => jsonDecode(e) as Map<String, dynamic>).lastWhere((m) => m['t'] == 'vote');
    expect((vote['p'] as Map)['target'], 'p2');
    expect((vote['p'] as Map)['qId'], 'q1');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('kesin hata (oda yok) mesajı gösterir', (tester) async {
    final t = await _ac(tester);
    t.sunucu('error', {'code': 'ROOM_NOT_FOUND'});
    await tester.pump();
    expect(find.text(hataMetni('ROOM_NOT_FOUND')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
