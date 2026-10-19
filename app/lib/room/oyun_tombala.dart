import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'oda_istemci.dart';
import 'oda_ortak.dart';
import 'zarf.dart';

const _odulTurAdi = {'cinko1': '1. Çinko', 'cinko2': '2. Çinko', 'tombala': 'Tombala'};

List<int> _cekilenler(OdaIstemcisi i) =>
    ((i.acik['drawn'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();

/// 01 — Tombala çevrimiçi oda paneli (oyuncu kartı / HOST ekranı).
class TombalaPaneli extends StatelessWidget {
  const TombalaPaneli({super.key, required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    if (i.faz == 'FINAL') return _TombalaFinal(istemci: i);
    if (i.rol == 'display') return _Ekran(istemci: i);
    return _Oyuncu(istemci: i);
  }
}

class _Oyuncu extends StatefulWidget {
  const _Oyuncu({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  State<_Oyuncu> createState() => _OyuncuDurum();
}

class _OyuncuDurum extends State<_Oyuncu> {
  final Set<int> _isaret = {};
  String? _mesaj;
  SunucuAbone? _abone;

  @override
  void initState() {
    super.initState();
    _abone = SunucuAbone(widget.istemci, (t, p) {
      if (t != 'claimResult' || !mounted) return;
      setState(() {
        _mesaj = p['ok'] == true
            ? 'Ödül senin! ${_odulTurAdi[p['type']] ?? ''}'
            : (p['reason'] == 'NO_PRIZE' ? 'Bu ödül zaten alınmış.' : 'Geçersiz bildirim, kısa süre bildiremezsin.');
      });
    });
  }

  @override
  void dispose() {
    _abone?.kapat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.istemci;
    final cekilen = _cekilenler(i).toSet();
    final otomatik = i.ayarlar['otoIsaret'] != false;
    final kartlar = ((i.son['cards']?['cards'] as List?) ?? const []);
    final guncel = i.acik['current'];
    final kilit = (i.son['claimResult']?['lockUntilIdx'] as num?)?.toInt() ??
        (i.ozel?['lockUntilIdx'] as num?)?.toInt() ??
        0;
    final cekimNo = (i.acik['idx'] as num?)?.toInt() ?? 0;
    final kilitli = cekimNo < kilit;
    final oduller = ((i.acik['prizes'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final tema = Theme.of(context).textTheme;
    final r = context.renkler;

    if (i.rol == 'spectator') {
      return const Center(child: Text('Tombalayı izliyorsun.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Çekilen: $cekimNo/90', style: tema.titleMedium),
            if (i.hostMu) _HostKumanda(istemci: i),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Semantics(
            liveRegion: true,
            label: guncel == null ? 'Henüz sayı çekilmedi' : 'Çekilen sayı $guncel',
            child: Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: r.ana),
              child: Text(
                guncel == null ? '—' : '$guncel',
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var k = 0; k < kartlar.length; k++)
          _Kart(
            kart: (kartlar[k] as List).map((s) => (s as List).map((e) => (e as num).toInt()).toList()).toList(),
            cekilen: cekilen,
            isaret: _isaret,
            otomatik: otomatik,
            onBas: (n) => setState(() => _isaret.contains(n) ? _isaret.remove(n) : _isaret.add(n)),
          ),
        if (_mesaj != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_mesaj!, textAlign: TextAlign.center, style: tema.titleMedium),
          ),
        const SizedBox(height: 8),
        if (kilitli)
          Text(
            'Yanlış bildirim: ${kilit - cekimNo} çekim bildiremezsin.',
            textAlign: TextAlign.center,
          ),
        for (final tur in const ['cinko1', 'cinko2', 'tombala'])
          if (_odulKalan(oduller, tur))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: kartlar.length <= 1
                  ? FilledButton(
                      onPressed: kilitli ? null : () => i.gonder('claim', {'type': tur, 'cardIdx': 0}),
                      child: Text('${_odulTurAdi[tur]}!'),
                    )
                  : Wrap(
                      spacing: 8,
                      children: [
                        for (var k = 0; k < kartlar.length; k++)
                          FilledButton(
                            onPressed: kilitli ? null : () => i.gonder('claim', {'type': tur, 'cardIdx': k}),
                            child: Text('${_odulTurAdi[tur]} · Kart ${k + 1}'),
                          ),
                      ],
                    ),
            ),
        const SizedBox(height: 16),
        _OdulListesi(istemci: i, oduller: oduller),
      ],
    );
  }

  bool _odulKalan(List<Map<String, dynamic>> oduller, String tur) =>
      oduller.any((o) => o['tur'] == tur && ((o['winners'] as List?) ?? const []).isEmpty);
}

class _Kart extends StatelessWidget {
  const _Kart({
    required this.kart,
    required this.cekilen,
    required this.isaret,
    required this.otomatik,
    required this.onBas,
  });
  final List<List<int>> kart;
  final Set<int> cekilen;
  final Set<int> isaret;
  final bool otomatik;
  final void Function(int n) onBas;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: r.yuzey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.ana, width: 2),
      ),
      child: Column(
        children: [
          for (final satir in kart)
            Row(
              children: [
                for (final n in satir)
                  Expanded(
                    child: n == 0
                        ? const SizedBox(height: 40)
                        : _Hucre(
                            n: n,
                            dolu: otomatik ? cekilen.contains(n) : isaret.contains(n),
                            onBas: otomatik ? null : () => onBas(n),
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Hucre extends StatelessWidget {
  const _Hucre({required this.n, required this.dolu, required this.onBas});
  final int n;
  final bool dolu;
  final VoidCallback? onBas;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Semantics(
      label: dolu ? '$n işaretli' : '$n',
      button: onBas != null,
      child: InkWell(
        onTap: onBas,
        child: Container(
          height: 40,
          margin: const EdgeInsets.all(1.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: dolu ? r.ana : r.yukseltilmis,
          ),
          child: Text(
            '$n',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: dolu ? Colors.white : r.metin,
            ),
          ),
        ),
      ),
    );
  }
}

class _OdulListesi extends StatelessWidget {
  const _OdulListesi({required this.istemci, required this.oduller});
  final OdaIstemcisi istemci;
  final List<Map<String, dynamic>> oduller;

  @override
  Widget build(BuildContext context) {
    if (oduller.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ödüller', style: Theme.of(context).textTheme.titleMedium),
        for (final o in oduller)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${o['name']}: ${((o['winners'] as List?) ?? const []).isEmpty ? 'açık' : ((o['winners'] as List).map((x) => oyuncuAdi(istemci, x as String)).join(', '))}',
            ),
          ),
      ],
    );
  }
}

/// Kurucunun çekim kumandası: hız, duraklat, sıradaki sayı.
class _HostKumanda extends StatelessWidget {
  const _HostKumanda({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final hiz = (i.acik['speed'] as num?)?.toInt() ?? 5;
    final durakladi = i.acik['paused'] == true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hiz == 0)
          FilledButton.tonal(
            onPressed: i.faz == 'CEKIM' ? () => i.gonder('next') : null,
            child: const Text('Sıradaki'),
          )
        else
          IconButton(
            tooltip: durakladi ? 'Devam' : 'Duraklat',
            onPressed: i.faz == 'CEKIM' ? () => i.gonder(durakladi ? 'unpause' : 'pause') : null,
            icon: Icon(durakladi ? Icons.play_arrow_rounded : Icons.pause_rounded),
          ),
        PopupMenuButton<int>(
          tooltip: 'Hız',
          icon: const Icon(Icons.speed_rounded),
          onSelected: (h) => i.gonder('setSpeed', {'speed': h}),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 3, child: Text('Hızlı (3 sn)')),
            PopupMenuItem(value: 5, child: Text('Normal (5 sn)')),
            PopupMenuItem(value: 8, child: Text('Yavaş (8 sn)')),
            PopupMenuItem(value: 0, child: Text('Elle')),
          ],
        ),
      ],
    );
  }
}

/// Büyük ekran: son sayı, 1–90 tablosu, ödüller.
class _Ekran extends StatelessWidget {
  const _Ekran({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final cekilen = _cekilenler(i).toSet();
    final guncel = i.acik['current'];
    final oduller = ((i.acik['prizes'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            guncel == null ? '—' : '$guncel',
            style: TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: r.ana),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 10,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (var n = 1; n <= 90; n++)
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: cekilen.contains(n) ? r.ana : r.yukseltilmis,
                    ),
                    child: Text(
                      '$n',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cekilen.contains(n) ? Colors.white : r.metinIkincil,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _OdulListesi(istemci: i, oduller: oduller),
        ],
      ),
    );
  }
}

class _TombalaFinal extends StatelessWidget {
  const _TombalaFinal({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final f = (i.acik['final'] as Map<String, dynamic>?) ?? i.son['final'];
    final oduller = ((f?['prizes'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Oyun bitti', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('${f?['drawnCount'] ?? 0} sayı çekildi', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        _OdulListesi(istemci: i, oduller: oduller),
        const SizedBox(height: 12),
        RozetListesi(istemci: i, rozetler: (f?['badges'] as List?) ?? const []),
      ],
    );
  }
}

/// Olay akışına abone olup bırakmayı sarar.
class SunucuAbone {
  SunucuAbone(OdaIstemcisi i, void Function(String t, Map<String, dynamic> p) cb)
      : _s = i.olaylar.listen((m) => cb(m.t, m.p));
  final StreamSubscription<SunucuMesaji> _s;
  void kapat() => unawaited(_s.cancel());
}
