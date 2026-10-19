import 'package:flutter/material.dart';

import 'oda_istemci.dart';
import 'oda_ortak.dart';

/// 07 — En Olası Kim? çevrimiçi oda paneli.
class EnOlasiKimPaneli extends StatelessWidget {
  const EnOlasiKimPaneli({super.key, required this.istemci});
  final OdaIstemcisi istemci;

  List<String> get _oyuncular => [
        for (final o in istemci.oyuncular)
          if (o.rol == 'player') o.id,
      ];

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final faz = i.faz;
    final a = i.acik;
    final soru = a['question'] as Map<String, dynamic>?;
    final tema = Theme.of(context).textTheme;

    if (faz == 'DURAKLA') {
      return _Duraklat(istemci: i);
    }
    if (faz == 'FINAL') {
      return _Final(istemci: i);
    }
    final ust = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Soru ${a['idx'] ?? 0}/${a['total'] ?? 0}', style: tema.titleMedium),
        GeriSayim(istemci: i),
      ],
    );
    final soruMetni = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        soru?['text'] as String? ?? '',
        textAlign: TextAlign.center,
        style: tema.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );

    Widget govde;
    switch (faz) {
      case 'OY':
      case 'TAHMIN':
        govde = _Oylama(istemci: i, tahmin: faz == 'TAHMIN', qId: soru?['qId'] as String?, adaylar: _oyuncular);
      case 'SONUC':
      case 'TAHMIN_SKOR':
        govde = _Sonuc(istemci: i);
      default:
        govde = Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Hazır ol…', textAlign: TextAlign.center, style: tema.titleMedium),
        );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [ust, soruMetni, govde],
    );
  }
}

class _Oylama extends StatefulWidget {
  const _Oylama({required this.istemci, required this.tahmin, required this.qId, required this.adaylar});
  final OdaIstemcisi istemci;
  final bool tahmin;
  final String? qId;
  final List<String> adaylar;

  @override
  State<_Oylama> createState() => _OylamaDurum();
}

class _OylamaDurum extends State<_Oylama> {
  String? _secim;
  String? _soruNo;

  @override
  Widget build(BuildContext context) {
    final i = widget.istemci;
    if (_soruNo != widget.qId) {
      _soruNo = widget.qId;
      _secim = null;
    }
    // Yeniden bağlanınca sunucudaki oyu göster.
    final ozel = i.ozel;
    final sunucudaki = widget.tahmin ? ozel?['myPredict'] : ozel?['myVote'];
    final canli = i.son['myVote'];
    final secili = _secim ?? (canli != null && canli['qId'] == widget.qId ? canli['target'] as String? : null) ?? (sunucudaki is String ? sunucudaki : null);
    final izleyici = i.rol != 'player';
    final ilerleme = i.son['voteProgress'] ?? (i.acik['voteProgress'] as Map<String, dynamic>?);
    final kendineYasak = i.ayarlar['kendineOy'] != 'serbest' && !widget.tahmin;
    final adaylar = [
      for (final id in widget.adaylar)
        if (!(kendineYasak && id == i.oyuncuId)) id,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.tahmin ? 'Çoğunluk kimi seçecek?' : 'Sence kim?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        OyuncuSecici(
          istemci: i,
          idler: adaylar,
          secili: secili,
          etkin: !izleyici,
          onSec: (id) {
            if (i.gonder(widget.tahmin ? 'predict' : 'vote', {'qId': widget.qId, 'target': id}) != null) {
              setState(() => _secim = id);
            }
          },
        ),
        const SizedBox(height: 16),
        if (ilerleme != null)
          Text(
            '${ilerleme['votedCount'] ?? 0}/${ilerleme['total'] ?? 0} kişi seçti',
            textAlign: TextAlign.center,
          ),
        if (izleyici)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('İzleyici olarak oy veremezsin.', textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

class _Sonuc extends StatelessWidget {
  const _Sonuc({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final s = (i.acik['result'] as Map<String, dynamic>?) ?? i.son['result'];
    if (s == null) return const SizedBox.shrink();
    final sayim = (s['counts'] as Map<String, dynamic>?) ?? const {};
    final kazananlar = ((s['winners'] as List?) ?? const []).cast<String>();
    final enCok = sayim.values.fold<int>(0, (m, v) => (v as num) > m ? v.toInt() : m);
    final tahmin = (i.acik['predictResult'] as Map<String, dynamic>?) ?? i.son['predictResult'];
    final dogru = ((tahmin?['correctPlayerIds'] as List?) ?? const []).cast<String>();
    final hedef = s['target'] as String?;
    final satirlar = sayim.entries.toList()..sort((a, b) => (b.value as num).compareTo(a.value as num));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s['noVotes'] == true)
          const Text('Kimse oy vermedi.', textAlign: TextAlign.center)
        else
          for (final e in satirlar)
            SonucSatiri(
              istemci: i,
              id: e.key,
              metin: '${e.value}',
              oran: enCok == 0 ? 0 : (e.value as num) / enCok,
              vurgu: kazananlar.contains(e.key),
            ),
        if (s['tie'] == true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Beraberlik!', textAlign: TextAlign.center),
          ),
        if (hedef != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${oyuncuAdi(i, hedef)} üst üste üç kez seçildi!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (tahmin != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              dogru.isEmpty ? 'Doğru tahmin eden olmadı.' : 'Doğru tahmin: ${dogru.map((x) => oyuncuAdi(i, x)).join(', ')}',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _Duraklat extends StatelessWidget {
  const _Duraklat({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Oyun duraklatıldı',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Bağlı oyuncu sayısı 3\'ün altına düştü.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (i.hostMu) ...[
            FilledButton(onPressed: () => i.gonder('continue'), child: const Text('Devam et')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => i.gonder('finish'), child: const Text('Oyunu bitir')),
          ] else
            const Text('Kurucunun devam etmesi bekleniyor…', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Final extends StatelessWidget {
  const _Final({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final f = (i.acik['final'] as Map<String, dynamic>?) ?? i.son['final'];
    final tablo = (f?['scoreboard'] as List?) ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Oyun bitti', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        RozetListesi(istemci: i, rozetler: (f?['badges'] as List?) ?? const []),
        if (tablo.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Tahmin puanları', style: Theme.of(context).textTheme.titleMedium),
          for (final t in tablo)
            SonucSatiri(
              istemci: i,
              id: (t as Map)['playerId'] as String,
              metin: '${t['score']}',
            ),
        ],
      ],
    );
  }
}
