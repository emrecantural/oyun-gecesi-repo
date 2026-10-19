import 'package:flutter/material.dart';

import '../shell/ortak/gizli_bilgi.dart';
import 'oda_istemci.dart';
import 'oda_ortak.dart';

const _roller = {
  'kurt': 'Kurt',
  'kahin': 'Kâhin',
  'doktor': 'Doktor',
  'cadi': 'Cadı',
  'avci': 'Avcı',
  'asik': 'Âşık',
  'koylu': 'Köylü',
};

const _nedenler = {
  'kurt': 'kurtlar tarafından',
  'zehir': 'zehirlenerek',
  'askZinciri': 'aşkından',
  'oylama': 'oylamayla',
  'avci': 'avcının okuyla',
};

String _rolMetni(String? r) => _roller[r] ?? '?';

/// 03 — Köy ve Kurtlar çevrimiçi oda paneli.
class KoyKurtlarPaneli extends StatelessWidget {
  const KoyKurtlarPaneli({super.key, required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    if (i.faz == 'DURAKLA') return _Duraklat(istemci: i);
    if (i.faz == 'FINAL') return _Final(istemci: i);
    final oyuncuMu = i.rol == 'player';
    final govde = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gece ${i.acik['round'] ?? 0}', style: Theme.of(context).textTheme.titleMedium),
            GeriSayim(istemci: i),
          ],
        ),
        const SizedBox(height: 12),
        if (oyuncuMu) _RolKarti(istemci: i),
        const SizedBox(height: 12),
        _FazGovdesi(istemci: i),
      ],
    );
    return oyuncuMu ? GizliEkran(child: govde) : govde;
  }
}

bool _canli(OdaIstemcisi i, String id) => (i.acik['alive'] as Map?)?[id] != false;

class _RolKarti extends StatelessWidget {
  const _RolKarti({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final m = i.son['roleAssigned'];
    if (m == null) return const SizedBox.shrink();
    final dostlar = ((m['allies'] as List?) ?? const []).cast<String>();
    final ask = (i.son['lovers']?['loverId'] ?? m['loverId']) as String?;
    return BasiliTutKart(
      kapaliEtiket: 'Rolün',
      acik: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _rolMetni(m['role'] as String?),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (dostlar.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Kurt arkadaşların: ${dostlar.map((x) => oyuncuAdi(i, x)).join(', ')}'),
          ],
          if (ask != null) ...[
            const SizedBox(height: 8),
            Text('Âşığın: ${oyuncuAdi(i, ask)}'),
          ],
        ],
      ),
    );
  }
}

class _FazGovdesi extends StatelessWidget {
  const _FazGovdesi({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final faz = i.faz;
    final tema = Theme.of(context).textTheme;
    final canli = _canli(i, i.oyuncuId);
    final oyuncuMu = i.rol == 'player';

    Widget bekle(String metin) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(metin, textAlign: TextAlign.center, style: tema.titleMedium),
        );

    if (oyuncuMu && !canli && faz != 'SAFAK' && faz != 'OYLAMA_SONUC') {
      return bekle('Öldün. Oyunu izliyorsun.');
    }
    switch (faz) {
      case 'ROL_DAGIT':
        return bekle('Rolünü gör. Kimseye gösterme.');
      case 'GECE_ASKLAR':
        final ask = i.son['lovers']?['loverId'] as String?;
        return bekle(ask == null ? 'Gece oldu. Gözlerini kapat.' : 'Âşığın: ${oyuncuAdi(i, ask)}');
      case 'GECE_KAHIN':
      case 'GECE_KURT':
      case 'GECE_DOKTOR':
      case 'GECE_CADI':
        if (!oyuncuMu) return bekle('Gece… Köy uyuyor.');
        return _GeceIstemi(istemci: i);
      case 'SAFAK':
        return _Safak(istemci: i);
      case 'AVCI':
        return _Avci(istemci: i);
      case 'TARTISMA':
        return bekle('Tartışın! Kim kurt olabilir?');
      case 'OYLAMA':
        return _Oylama(istemci: i);
      case 'OYLAMA_SONUC':
        return _OySonuc(istemci: i);
      default:
        return bekle('…');
    }
  }
}

class _GeceIstemi extends StatefulWidget {
  const _GeceIstemi({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  State<_GeceIstemi> createState() => _GeceIstemiDurum();
}

class _GeceIstemiDurum extends State<_GeceIstemi> {
  String? _verilen;
  String? _faz;
  bool _zehirSec = false;

  void _gonder(String kind, [String? hedef]) {
    final id = widget.istemci.gonder('nightAction', {'kind': kind, 'target': ?hedef});
    if (id != null) setState(() => _verilen = kind);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.istemci;
    if (_faz != i.faz) {
      _faz = i.faz;
      _verilen = null;
      _zehirSec = false;
    }
    final tema = Theme.of(context).textTheme;
    final p = i.son['nightPrompt'];
    final tur = p?['prompt'] as String? ?? 'none';
    final kilitli = _verilen != null || ((p?['myAction'] as List?)?.isNotEmpty ?? false);
    final hedefler = ((p?['targets'] as List?) ?? const []).cast<String>();

    Widget metin(String m) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(m, textAlign: TextAlign.center, style: tema.titleMedium),
        );

    if (tur == 'none' || p == null) return metin('Gece… Gözlerini kapat ve bekle.');
    if (kilitli && tur != 'seer' && tur != 'witchAct') return metin('Seçimin alındı. Bekle.');
    if (tur == 'witchAct' && (_verilen == 'witchSkip' || _verilen == 'witchPoison')) {
      return metin('Seçimin alındı. Bekle.');
    }

    final red = i.son['actionRejected'];
    final uyari = red == null ? null : const Text('Bu seçim geçerli değil, başka dene.');

    switch (tur) {
      case 'seer':
        final sonuc = i.son['seerResult'];
        if (sonuc != null && kilitli) {
          final kurt = sonuc['isWolf'] == true;
          return metin('${oyuncuAdi(i, sonuc['targetId'] as String?)}: ${kurt ? 'KURT' : 'kurt değil'}');
        }
        return _Secim(
          istemci: i,
          baslik: 'Kimin kurt olup olmadığına bakacaksın?',
          idler: hedefler,
          onSec: (id) => _gonder('seer', id),
          uyari: uyari,
        );
      case 'wolfVote':
        final tahta = (i.son['wolfBoard']?['votes'] as Map?) ?? const {};
        return Column(
          children: [
            if (tahta.isNotEmpty)
              Text(
                tahta.entries.map((e) => '${oyuncuAdi(i, e.key as String)} → ${oyuncuAdi(i, e.value as String?)}').join('\n'),
                textAlign: TextAlign.center,
              ),
            _Secim(
              istemci: i,
              baslik: 'Kimi avlıyorsunuz? (Her kurt oy verir)',
              idler: [
                for (final h in hedefler)
                  if (!_kurtMu(i, h)) h,
              ],
              onSec: (id) => _gonder('wolfVote', id),
              uyari: uyari,
            ),
          ],
        );
      case 'protect':
        final kendini = i.ayarlar['doktorKendini'] != 'hayir';
        return _Secim(
          istemci: i,
          baslik: 'Kimi koruyacaksın?',
          idler: [if (kendini) i.oyuncuId, ...hedefler],
          onSec: (id) => _gonder('protect', id),
          uyari: uyari,
        );
      case 'witchAct':
        final b = i.son['witchInfo'];
        final kurban = b?['victimId'] as String?;
        final iksir = (b?['potions'] as Map?) ?? const {};
        if (_zehirSec) {
          return _Secim(
            istemci: i,
            baslik: 'Kimi zehirleyeceksin?',
            idler: hedefler,
            onSec: (id) => _gonder('witchPoison', id),
            uyari: uyari,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            metin(kurban == null ? 'Bu gece kimse saldırıya uğramadı.' : 'Kurtlar ${oyuncuAdi(i, kurban)} kişisine saldırdı.'),
            if (iksir['heal'] == true && kurban != null && _verilen != 'witchHeal')
              FilledButton(onPressed: () => _gonder('witchHeal'), child: const Text('İyileştir')),
            if (iksir['poison'] == true) ...[
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => setState(() => _zehirSec = true), child: const Text('Zehirle')),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: () => _gonder('witchSkip'), child: const Text('Pas geç')),
          ],
        );
    }
    return metin('…');
  }

  bool _kurtMu(OdaIstemcisi i, String id) =>
      ((i.son['roleAssigned']?['allies'] as List?) ?? const []).contains(id);
}

class _Secim extends StatefulWidget {
  const _Secim({
    required this.istemci,
    required this.baslik,
    required this.idler,
    required this.onSec,
    this.uyari,
  });
  final OdaIstemcisi istemci;
  final String baslik;
  final List<String> idler;
  final void Function(String id) onSec;
  final Widget? uyari;

  @override
  State<_Secim> createState() => _SecimDurum();
}

class _SecimDurum extends State<_Secim> {
  String? _secili;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(widget.baslik, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        OyuncuSecici(
          istemci: widget.istemci,
          idler: widget.idler,
          secili: _secili,
          onSec: (id) {
            setState(() => _secili = id);
            widget.onSec(id);
          },
        ),
        if (widget.uyari != null) Padding(padding: const EdgeInsets.only(top: 8), child: widget.uyari),
      ],
    );
  }
}

class _Safak extends StatelessWidget {
  const _Safak({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final olenler = ((i.acik['deaths'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final tema = Theme.of(context).textTheme;
    return Column(
      children: [
        Text('Sabah oldu', style: tema.headlineSmall),
        const SizedBox(height: 12),
        if (olenler.isEmpty)
          Text('Sessiz bir gece geçti. Kimse ölmedi.', style: tema.titleMedium, textAlign: TextAlign.center)
        else
          for (final o in olenler)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${oyuncuAdi(i, o['id'] as String?)} ${_nedenler[o['neden']] ?? ''} öldü'
                '${o['roleShown'] != null ? ' (${_rolMetni(o['roleShown'] as String?)})' : ''}.',
                textAlign: TextAlign.center,
                style: tema.titleMedium,
              ),
            ),
      ],
    );
  }
}

class _Avci extends StatelessWidget {
  const _Avci({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final p = i.son['hunterPrompt'];
    if (p == null || i.acik['alive'] == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Avcı son okunu atıyor…', textAlign: TextAlign.center),
      );
    }
    return _Secim(
      istemci: i,
      baslik: 'Avcısın! Son okunu kime atacaksın?',
      idler: ((p['targets'] as List?) ?? const []).cast<String>(),
      onSec: (id) => i.gonder('hunterShoot', {'target': id}),
    );
  }
}

class _Oylama extends StatefulWidget {
  const _Oylama({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  State<_Oylama> createState() => _OylamaDurum();
}

class _OylamaDurum extends State<_Oylama> {
  String? _secim;
  int? _tur;

  @override
  Widget build(BuildContext context) {
    final i = widget.istemci;
    final tur = (i.acik['round'] as num?)?.toInt();
    final adaylarHam = i.acik['candidates'] as List?;
    final canli = [
      for (final o in i.oyuncular)
        if (o.rol == 'player' && _canli(i, o.id)) o.id,
    ];
    final adaylar = adaylarHam == null ? canli : adaylarHam.cast<String>();
    if (_tur != tur) {
      _tur = tur;
      _secim = null;
    }
    final secili = _secim ?? (i.ozel?['myVote'] as String?);
    final oyuncuMu = i.rol == 'player' && _canli(i, i.oyuncuId);
    return Column(
      children: [
        Text('Kim asılsın?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        OyuncuSecici(
          istemci: i,
          idler: adaylar,
          secili: secili,
          etkin: oyuncuMu,
          onSec: (id) {
            if (i.gonder('castVote', {'target': id}) != null) setState(() => _secim = id);
          },
        ),
        const SizedBox(height: 12),
        Text('${i.acik['votedCount'] ?? 0} oy verildi'),
        if (oyuncuMu)
          TextButton(
            onPressed: () {
              if (i.gonder('castVote', {'target': null}) != null) setState(() => _secim = '');
            },
            child: const Text('Çekimser kal'),
          ),
      ],
    );
  }
}

class _OySonuc extends StatelessWidget {
  const _OySonuc({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final s = (i.acik['voteResult'] as Map<String, dynamic>?) ?? i.son['voteResult'];
    final tema = Theme.of(context).textTheme;
    if (s == null) return const SizedBox.shrink();
    final eleneni = s['eliminatedId'] as String?;
    final tally = (s['tally'] as Map?) ?? const {};
    final enCok = tally.values.fold<int>(0, (m, v) => (v as num) > m ? v.toInt() : m);
    return Column(
      children: [
        Text(
          eleneni == null
              ? (s['revote'] == true ? 'Eşitlik! Yeniden oylama.' : 'Kimse asılmadı.')
              : '${oyuncuAdi(i, eleneni)} asıldı'
                  '${s['roleShown'] != null ? ' (${_rolMetni(s['roleShown'] as String?)})' : ''}.',
          textAlign: TextAlign.center,
          style: tema.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final e in tally.entries)
          SonucSatiri(
            istemci: i,
            id: e.key as String,
            metin: '${e.value}',
            oran: enCok == 0 ? 0 : (e.value as num) / enCok,
            vurgu: e.key == eleneni,
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
          Text('Oyun duraklatıldı', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Bağlı oyuncu sayısı 6\'nın altına düştü.', textAlign: TextAlign.center),
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
    final kazanan = f?['winner'];
    final roller = ((f?['roles'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          kazanan == 'kurtlar' ? 'Kurtlar kazandı!' : (kazanan == 'koy' ? 'Köy kazandı!' : 'Oyun bitti'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        for (final r in roller)
          SonucSatiri(
            istemci: i,
            id: r['id'] as String,
            metin: '${_rolMetni(r['role'] as String?)}${r['alive'] == true ? '' : ' †'}',
          ),
        const SizedBox(height: 12),
        RozetListesi(istemci: i, rozetler: (f?['badges'] as List?) ?? const []),
      ],
    );
  }
}
