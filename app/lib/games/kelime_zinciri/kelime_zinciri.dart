import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../content/icerik_deposu.dart';
import '../../core/sure_sayaci.dart';
import '../../core/tr_text.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'zincir_mantik.dart';

const _dosya = '13-kelime-zinciri';

final kelimeZinciri = OyunUygulamasi(
  id: '13',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'bas',
      baslik: 'Başlangıç süresi',
      secenekler: {'8': '8 sn', '10': '10 sn', '15': '15 sn'},
      varsayilan: '10',
    ),
    AyarSatiri(
      anahtar: 'kategori',
      baslik: 'Kategori',
      secenekler: {
        'serbest': 'Serbest',
        'hayvan': 'Hayvan',
        'sehir': 'Şehir',
        'yemek': 'Yemek',
        'meslek': 'Meslek',
      },
      varsayilan: 'serbest',
    ),
    AyarSatiri(
      anahtar: 'eleme',
      baslik: 'Eleme',
      secenekler: {'1': 'Tek hata', '3': '3 can'},
      varsayilan: '1',
    ),
    AyarSatiri(
      anahtar: 'azalma',
      baslik: 'Süre azalması / tur',
      secenekler: {'0': '0', '500': '0,5 sn', '1000': '1 sn'},
      varsayilan: '500',
      gelismis: true,
    ),
    AyarSatiri(
      anahtar: 'min',
      baslik: 'Minimum süre',
      secenekler: {'3': '3 sn', '4': '4 sn', '5': '5 sn'},
      varsayilan: '3',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => KelimeZinciriEkrani(oturum: oturum),
);

enum _Asama { yukleniyor, hazir, sira, harf, onay, sureDoldu, oy, eleme, final_ }

class KelimeZinciriEkrani extends ConsumerStatefulWidget {
  const KelimeZinciriEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<KelimeZinciriEkrani> createState() => _ZincirDurum();
}

class _ZincirDurum extends ConsumerState<KelimeZinciriEkrani> {
  final _sayac = SureSayaci();
  late ZincirOyunu _oyun;
  List<String> _liste = const [];
  _Asama _asama = _Asama.yukleniyor;
  String? _hata;

  int _geriSayim = 3;
  Timer? _zaman;
  int _kalanSpoke = 0;
  String? _bekleyenHarf;
  bool _sureDolduydu = false;
  int _onayKalan = 2;
  bool _duraklat = false;
  int _sonDokunma = 0;
  final _saat = Stopwatch()..start();

  // oylama
  final Map<int, int> _oylar = {}; // id → 1 geçerli, 2 geçersiz
  int _oyKalan = 10;

  // eleme bilgisi
  String _elemeMesaji = '';

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _p => _o.oyuncular;
  Oyuncu _oyuncu(int id) => _p.firstWhere((p) => p.id == id);

  @override
  void initState() {
    super.initState();
    _sayac.addListener(_yenile);
    _kur();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _zaman?.cancel();
    _sayac.removeListener(_yenile);
    _sayac.dispose();
    super.dispose();
  }

  Future<void> _kur() async {
    final kat = _o.ayar('kategori');
    if (kat != 'serbest') {
      try {
        final tum = await ref.read(icerikHamProvider(_dosya).future);
        _liste = [
          for (final o in tum)
            if (o.tur == 'kelime' && o.seviye == kat) o.metin
        ];
      } catch (_) {}
    }
    final ilk = ZincirOyunu.ilkHarfSec(_liste, Random().nextInt(1 << 30));
    _oyun = ZincirOyunu(
      oyuncuIdleri: [for (final p in _p) p.id],
      baslangicMs: _o.ayarInt('bas') * 1000,
      azalmaMs: _o.ayarInt('azalma'),
      minMs: _o.ayarInt('min') * 1000,
      can: _o.ayarInt('eleme'),
      ilkHarf: _liste.isEmpty ? null : ilk,
    );
    if (!mounted) return;
    setState(() => _asama = _Asama.hazir);
    _geriSayim = 3;
    _zaman = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_geriSayim <= 1) {
        t.cancel();
        _siraBasla();
      } else {
        setState(() => _geriSayim--);
      }
    });
  }

  void _siraBasla() {
    _duraklat = false;
    _sureDolduydu = false;
    _sayac.baslat(_oyun.limitMs, bitince: _sureDoldu);
    setState(() => _asama = _Asama.sira);
  }

  bool _dokunmaSerbest() {
    final n = _saat.elapsedMilliseconds;
    if (n - _sonDokunma < 400) return false;
    _sonDokunma = n;
    return true;
  }

  void _soyledim() {
    if (_duraklat || !_dokunmaSerbest()) return;
    _kalanSpoke = _sayac.kalanMs;
    _sayac.durdur();
    setState(() => _asama = _Asama.harf);
  }

  void _sureDoldu() {
    HapticFeedback.heavyImpact();
    _sureDolduydu = true;
    _onayBasla(_Asama.sureDoldu);
  }

  void _harfSec(String ch) {
    _bekleyenHarf = zincirHarfNorm(ch);
    _sureDolduydu = false;
    _onayBasla(_Asama.onay);
  }

  void _onayBasla(_Asama a) {
    _onayKalan = 2;
    _zaman?.cancel();
    setState(() => _asama = a);
    _zaman = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_onayKalan <= 1) {
        t.cancel();
        _itirazsizBitti();
      } else {
        setState(() => _onayKalan--);
      }
    });
  }

  void _itirazsizBitti() {
    if (_asama == _Asama.onay) {
      _oyun.kabul(_bekleyenHarf!, kalanMs: _kalanSpoke);
      _bekleyenHarf = null;
      _siraBasla();
    } else if (_asama == _Asama.sureDoldu) {
      _hataUygula();
    }
  }

  void _itiraz() {
    _zaman?.cancel();
    _oylar.clear();
    _oyKalan = 10;
    _zaman = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_oyKalan <= 1) {
        t.cancel();
        _oyuBitir();
      } else {
        setState(() => _oyKalan--);
      }
    });
    setState(() => _asama = _Asama.oy);
  }

  void _oyDegistir(int id) {
    if (id == _oyun.aktifId) return;
    final v = _oylar[id] ?? 0;
    setState(() {
      if (v >= 2) {
        _oylar.remove(id);
      } else {
        _oylar[id] = v + 1;
      }
    });
  }

  void _oyuBitir() {
    _zaman?.cancel();
    final gecerli = _oylar.values.where((v) => v == 1).length;
    final gecersiz = _oylar.values.where((v) => v == 2).length;
    final ok = ZincirOyunu.oyGecerli(gecerli, gecersiz);
    if (_sureDolduydu) {
      // "süre dolmadan söyledi" geçerliyse harf seçimine dön
      if (ok) {
        _sureDolduydu = false;
        setState(() => _asama = _Asama.harf);
      } else {
        _hataUygula();
      }
    } else {
      if (ok) {
        _oyun.kabul(_bekleyenHarf!, kalanMs: _kalanSpoke);
        _bekleyenHarf = null;
        _siraBasla();
      } else {
        _hataUygula();
      }
    }
  }

  void _hataUygula() {
    _zaman?.cancel();
    final id = _oyun.aktifId;
    final no = _oyun.kelimeSayisi + 1;
    final elendi = _oyun.hata();
    _bekleyenHarf = null;
    _elemeMesaji = elendi
        ? '${_oyuncu(id).ad} elendi, $no. kelimede'
        : '${_oyuncu(id).ad}: ${_oyun.canOf(id)} can kaldı';
    setState(() => _asama = _Asama.eleme);
    _zaman = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_oyun.bitti) {
        setState(() => _asama = _Asama.final_);
      } else {
        _siraBasla();
      }
    });
  }

  void _duraklatAc() {
    _sayac.durdur();
    setState(() => _duraklat = true);
  }

  void _devam() {
    final kalan = _sayac.kalanMs;
    setState(() => _duraklat = false);
    _sayac.baslat(kalan <= 0 ? 1 : kalan, bitince: _sureDoldu);
  }

  void _listeyeBak() {
    final need = _oyun.need;
    if (_liste.isEmpty) return;
    final uygun = [
      for (final k in _liste)
        if (need == null || zincirHarfNorm(trUpper(k)[0]) == need) k
    ]..sort(compareTr);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Liste tam değildir; karar sizin.'),
            const SizedBox(height: 8),
            Text(uygun.isEmpty ? 'Bu harfle kelime yok.' : uygun.join(', ')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    final govde = switch (_asama) {
      _Asama.yukleniyor => const Center(child: CircularProgressIndicator()),
      _Asama.hazir => _hazir(),
      _Asama.sira => _sira(),
      _Asama.harf => _harf(),
      _Asama.onay => _onay(),
      _Asama.sureDoldu => _sureDoldu_(),
      _Asama.oy => _oy(),
      _Asama.eleme => Center(
          child: Text(_elemeMesaji,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 26)),
        ),
      _Asama.final_ => _final(),
    };
    return Container(color: context.renkler.zemin, child: govde);
  }

  String get _needYazi => _oyun.need ?? '?';

  Widget _hazir() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hazır mısınız?', style: TextStyle(fontSize: 24)),
            Text('$_geriSayim',
                style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w900)),
            Text(_oyun.need == null ? 'Serbest harf' : 'İlk harf: $_needYazi',
                style: const TextStyle(fontSize: 22)),
          ],
        ),
      );

  Widget _seritCan() {
    final r = context.renkler;
    return Wrap(spacing: 12, runSpacing: 4, alignment: WrapAlignment.center, children: [
      for (final p in _p)
        Builder(builder: (_) {
          final elendi = _oyun.elenenler.any((e) => e.id == p.id);
          return Opacity(
            opacity: elendi ? 0.4 : 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              OyuncuSimgesi(oyuncu: p, boyut: 28),
              const SizedBox(width: 4),
              Text(elendi
                  ? '✕'
                  : (_o.ayarInt('eleme') > 1 ? '♥' * _oyun.canOf(p.id) : p.ad),
                  style: TextStyle(color: r.metinIkincil)),
            ]),
          );
        }),
    ]);
  }

  Widget _sira() {
    final r = context.renkler;
    final o = _oyuncu(_oyun.aktifId);
    final zincir = _oyun.zincir.reversed.take(5).toList().reversed.map((e) => e.ch).join('→');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('Kelime ${_oyun.kelimeSayisi + 1} · Tur ${_oyun.cevrim + 1}'),
            const Spacer(),
            IconButton(
                tooltip: 'Duraklat',
                onPressed: _duraklatAc,
                icon: const Icon(Icons.pause_circle_outline)),
          ]),
          LinearProgressIndicator(
            value: _sayac.oran,
            minHeight: 8,
            color: _sayac.kalanSn <= 3 ? r.tehlike : r.ana,
          ),
          Text('${_sayac.kalanMs / 1000 < 10 ? (_sayac.kalanMs / 1000).toStringAsFixed(1) : _sayac.kalanSn} sn',
              textAlign: TextAlign.center),
          const Spacer(),
          Center(child: OyuncuSimgesi(oyuncu: o, boyut: 72)),
          Text(trUpper(o.ad),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_oyun.need == null ? 'Serbest harf: istediğin harfle başla' : 'Şu harfle başla:',
              textAlign: TextAlign.center),
          if (_oyun.need != null)
            Text(_needYazi,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900)),
          if (zincir.isNotEmpty)
            Text('Zincir: $zincir',
                textAlign: TextAlign.center, style: TextStyle(color: r.metinIkincil)),
          const Spacer(),
          _seritCan(),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: FilledButton(
              onPressed: _duraklat ? null : _soyledim,
              child: const Text('SÖYLEDİM', style: TextStyle(fontSize: 22)),
            ),
          ),
          if (_duraklat) ...[
            const SizedBox(height: 8),
            const Text('Ara verdik. Süre senin için bekliyor.', textAlign: TextAlign.center),
            FilledButton(onPressed: _devam, child: const Text('Devam')),
          ],
        ],
      ),
    );
  }

  Widget _harf() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_oyuncu(_oyun.aktifId).ad}: söylediğin kelimenin son harfi?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const Text('â, î, û için düz harfe bas.', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final h in zincirHarfleri)
                  FilledButton.tonal(
                    onPressed: () => _harfSec(h),
                    child: Text(h, style: const TextStyle(fontSize: 22)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _onay() {
    final ch = _bekleyenHarf ?? '';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(ch,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900)),
          Text(ch == 'Ğ' ? 'Ğ ile bitti: sıradaki serbest.' : 'Kabul? ($_onayKalan)',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)),
          const Spacer(),
          SizedBox(
            height: 72,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.renkler.tehlike),
              onPressed: _itiraz,
              child: const Text('İTİRAZ', style: TextStyle(fontSize: 22)),
            ),
          ),
          TextButton(
            onPressed: () {
              _zaman?.cancel();
              setState(() => _asama = _Asama.harf);
            },
            child: const Text('Harfi değiştir'),
          ),
        ],
      ),
    );
  }

  Widget _sureDoldu_() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text('Süre doldu! ${_oyuncu(_oyun.aktifId).ad} elenecek',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          Text('$_onayKalan', textAlign: TextAlign.center, style: const TextStyle(fontSize: 48)),
          const Spacer(),
          SizedBox(
            height: 72,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.renkler.tehlike),
              onPressed: _itiraz,
              child: const Text('İTİRAZ (söylemişti)', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _oy() {
    final gecerli = _oylar.values.where((v) => v == 1).length;
    final gecersiz = _oylar.values.where((v) => v == 2).length;
    final konu = _sureDolduydu
        ? '${_oyuncu(_oyun.aktifId).ad} süre dolmadan söyledi mi?'
        : '${_oyuncu(_oyun.aktifId).ad} kelimesi geçerli mi?';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$konu · $_oyKalan sn',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Avatarına dokun: ✓ geçerli, ✕ geçersiz.', textAlign: TextAlign.center),
          Expanded(
            child: ListView(children: [
              for (final p in _p)
                ListTile(
                  enabled: p.id != _oyun.aktifId,
                  leading: OyuncuSimgesi(oyuncu: p, boyut: 36),
                  title: Text(p.ad),
                  trailing: Text(switch (_oylar[p.id]) {
                    1 => '✓',
                    2 => '✕',
                    _ => p.id == _oyun.aktifId ? '🔒' : '…',
                  }, style: const TextStyle(fontSize: 22)),
                  onTap: () => _oyDegistir(p.id),
                ),
            ]),
          ),
          Text('Geçerli $gecerli · Geçersiz $gecersiz', textAlign: TextAlign.center),
          if (_liste.isNotEmpty)
            TextButton(onPressed: _listeyeBak, child: const Text('Listeye bak')),
          FilledButton(onPressed: _oyuBitir, child: const Text('Oylamayı bitir')),
        ],
      ),
    );
  }

  Widget _final() {
    final kaz = _oyun.kazanan;
    final kh = _oyun.kelimeHazinesi();
    final sn = _oyun.sonNefesRozeti();
    final elenme = _oyun.elenenler.reversed.toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(children: [
              if (kaz != null)
                ListTile(
                  leading: OyuncuSimgesi(oyuncu: _oyuncu(kaz), boyut: 48),
                  title: Text('${_oyuncu(kaz).ad} kazandı!',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              for (var i = 0; i < elenme.length; i++)
                ListTile(
                  title: Text('${i + 2}. ${_oyuncu(elenme[i].id).ad}'),
                  subtitle: Text('${elenme[i].kelimeNo}. kelimede'),
                ),
              if (kh != null)
                ListTile(title: const Text('Kelime Hazinesi'), subtitle: Text(_oyuncu(kh).ad)),
              if (sn != null)
                ListTile(title: const Text('Son Nefes'), subtitle: Text(_oyuncu(sn).ad)),
            ]),
          ),
          FilledButton(
            onPressed: () {
              ref.read(oturumProvider.notifier).bitir();
              context.go('/');
            },
            child: const Text('Ana sayfa'),
          ),
        ],
      ),
    );
  }
}
