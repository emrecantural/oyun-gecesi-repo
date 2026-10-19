import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'hafiza_mantik.dart';

const _yilbasi = <IconData>[
  Icons.ac_unit_rounded,
  Icons.star_rounded,
  Icons.card_giftcard_rounded,
  Icons.celebration_rounded,
  Icons.notifications_rounded,
  Icons.cake_rounded,
  Icons.local_fire_department_rounded,
  Icons.nightlight_round,
  Icons.favorite_rounded,
  Icons.wb_sunny_rounded,
];

const _gunluk = <IconData>[
  Icons.pets_rounded,
  Icons.flutter_dash_rounded,
  Icons.set_meal_rounded,
  Icons.local_pizza_rounded,
  Icons.icecream_rounded,
  Icons.music_note_rounded,
  Icons.rocket_launch_rounded,
  Icons.sports_esports_rounded,
  Icons.camera_alt_rounded,
  Icons.beach_access_rounded,
];

const _tumSimgeler = [..._yilbasi, ..._gunluk];

final hafizaDuellosu = OyunUygulamasi(
  id: '20',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'izgara',
      baslik: 'Izgara',
      secenekler: {'4x4': '4×4 (8 çift)', '5x4': '5×4 (10 çift)'},
      varsayilan: '4x4',
    ),
    AyarSatiri(
      anahtar: 'tema',
      baslik: 'Tema',
      secenekler: {'yilbasi': 'Yılbaşı', 'gunluk': 'Günlük', 'karisik': 'Karışık'},
      varsayilan: 'yilbasi',
    ),
    AyarSatiri(
      anahtar: 'sure',
      baslik: 'Sıra süresi',
      secenekler: {'15': '15 sn', '10': '10 sn', '0': 'Kapalı'},
      varsayilan: '15',
    ),
    AyarSatiri(
      anahtar: 'bonus',
      baslik: 'Seri bonusu',
      secenekler: {'evet': 'Açık', 'hayir': 'Kapalı'},
      varsayilan: 'evet',
      gelismis: true,
    ),
    AyarSatiri(
      anahtar: 'rahat',
      baslik: 'Rahat mod (daha uzun süreler)',
      secenekler: {'hayir': 'Kapalı', 'evet': 'Açık'},
      varsayilan: 'hayir',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => HafizaDuellosuEkrani(oturum: oturum),
);

enum _Asama { onizleme, oyun, bitti }

class HafizaDuellosuEkrani extends ConsumerStatefulWidget {
  const HafizaDuellosuEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<HafizaDuellosuEkrani> createState() => _HafizaDurum();
}

class _HafizaDurum extends ConsumerState<HafizaDuellosuEkrani>
    with WidgetsBindingObserver {
  late HafizaOyunu _oyun;
  _Asama _asama = _Asama.onizleme;
  Timer? _zamanlayici;
  Timer? _sureT;
  int _kalanMs = 0;
  String? _bilgi;

  OyunOturumu get _o => widget.oturum;
  bool get _rahat => _o.ayar('rahat') == 'evet';
  int get _ciftSayisi => _o.ayar('izgara') == '5x4' ? 10 : 8;
  int get _siraMs {
    final sn = _o.ayarInt('sure');
    return sn == 0 ? 0 : (sn * 1000 * (_rahat ? 1.5 : 1)).round();
  }

  Oyuncu _oyuncu(int id) => _o.oyuncular.firstWhere((e) => e.id == id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _yeniOyun();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zamanlayici?.cancel();
    _sureT?.cancel();
    super.dispose();
  }

  void _yeniOyun() {
    _zamanlayici?.cancel();
    _sureT?.cancel();
    final havuz = switch (_o.ayar('tema')) {
      'gunluk' => List.generate(_gunluk.length, (i) => i + _yilbasi.length),
      'karisik' => List.generate(_tumSimgeler.length, (i) => i),
      _ => List.generate(_yilbasi.length, (i) => i),
    };
    _oyun = HafizaOyunu(
      oyuncuIdleri: [for (final p in _o.oyuncular) p.id],
      dizilim: dizilimUret(_ciftSayisi, havuz, Random.secure()),
      seriBonus: _o.ayar('bonus') != 'hayir',
    );
    _bilgi = null;
    _asama = _Asama.onizleme;
    for (final k in _oyun.kartlar) {
      k.acik = true;
    }
    _zamanlayici = Timer(Duration(milliseconds: _rahat ? 4500 : 3000), () {
      if (!mounted) return;
      for (final k in _oyun.kartlar) {
        k.acik = false;
      }
      setState(() => _asama = _Asama.oyun);
      _sureyiBaslat();
    });
    if (mounted) setState(() {});
  }

  void _sureyiBaslat() {
    _sureT?.cancel();
    if (_siraMs == 0 || _asama != _Asama.oyun) {
      _kalanMs = 0;
      return;
    }
    _kalanMs = _siraMs;
    _sureT = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _oyun.kilitli) return;
      _kalanMs -= 250;
      if (_kalanMs <= 0) {
        _sureT?.cancel();
        _oyun.sureDoldu();
        _bilgi = 'Süre doldu.';
        setState(() {});
        _sureyiBaslat();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_asama != _Asama.oyun) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // A1: süre durur; açık kart kapanır.
      _sureT?.cancel();
      _zamanlayici?.cancel();
      if (_oyun.acik.length == 2) {
        _oyun.kapat();
      } else {
        for (final i in _oyun.acik) {
          _oyun.kartlar[i].acik = false;
        }
        _oyun.acik.clear();
      }
      setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _sureyiBaslat();
    }
  }

  void _dokun(int idx) {
    if (_asama != _Asama.oyun) return;
    final sonuc = _oyun.ac(idx);
    if (sonuc == HamleSonucu.reddedildi) return;
    HapticFeedback.selectionClick();
    _bilgi = null;
    switch (sonuc) {
      case HamleSonucu.eslesti:
        HapticFeedback.mediumImpact();
        final o = _oyun.oyuncular.firstWhere((e) => e.id == _oyun.kartlar[idx].sahip);
        _bilgi = o.seri >= 2 ? 'Seri x${o.seri}!' : 'Eşleşti!';
        setState(() {});
        _zamanlayici?.cancel();
        _zamanlayici = Timer(const Duration(milliseconds: 600), _eslesmeSonrasi);
      case HamleSonucu.uyusmadi:
        _sureT?.cancel();
        _bilgi = 'Olmadı, sıra geçti.';
        setState(() {});
        _zamanlayici?.cancel();
        _zamanlayici = Timer(
          Duration(milliseconds: _rahat ? 1800 : 1200),
          () {
            if (!mounted) return;
            _oyun.kapat();
            setState(() {});
            _sureyiBaslat();
          },
        );
      default:
        setState(() {});
    }
  }

  void _eslesmeSonrasi() {
    if (!mounted) return;
    if (_oyun.sonCiftiOtomatik()) {
      final son = _oyun.oyuncular.firstWhere((e) => e.id == _oyun.siradaki.id);
      _bilgi = 'Son çift: ${_oyuncu(son.id).ad}';
    }
    if (_oyun.bitti) {
      _sureT?.cancel();
      _zamanlayici?.cancel();
      _zamanlayici = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _asama = _Asama.bitti);
      });
      setState(() {});
      return;
    }
    setState(() {});
    _sureyiBaslat();
  }

  @override
  Widget build(BuildContext context) {
    final n = _o.oyuncular.length;
    if (n < 2 || n > 6) {
      return const Center(child: Text('Bu oyun tek cihazda 2–6 kişiyle oynanır.'));
    }
    if (_asama == _Asama.bitti) return _final();
    return _tahta();
  }

  Widget _tahta() {
    final r = context.renkler;
    final onizleme = _asama == _Asama.onizleme;
    final sira = _oyun.siradaki;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              onizleme ? 'Ezberle!' : 'Sıra: ${_oyuncu(sira.id).ad}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SizedBox(
            height: 24,
            child: Text(
              _bilgi ??
                  (!onizleme && _siraMs > 0 && !_oyun.kilitli
                      ? '${(_kalanMs / 1000).ceil()} sn'
                      : ''),
              style: TextStyle(color: r.metinIkincil),
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              const bosluk = 8.0;
              const sutun = 4;
              final satir = (_oyun.kartlar.length / sutun).ceil();
              final w = (c.maxWidth - bosluk * (sutun - 1)) / sutun;
              final h = (c.maxHeight - bosluk * (satir - 1)) / satir;
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: sutun,
                  mainAxisSpacing: bosluk,
                  crossAxisSpacing: bosluk,
                  childAspectRatio: w / h,
                ),
                itemCount: _oyun.kartlar.length,
                itemBuilder: (context, i) => _kart(i),
              );
            }),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final o in _oyun.oyuncular) _skorCipi(o, !onizleme && identical(o, sira)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skorCipi(HafizaOyuncu o, bool sirada) {
    final r = context.renkler;
    final p = _oyuncu(o.id);
    return Semantics(
      label: '${p.ad}, ${puanYaz(o.puan2)} puan${o.ayrildi ? ', ayrıldı' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: r.yuzey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sirada ? r.ana : r.yukseltilmis, width: sirada ? 3 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          OyuncuSimgesi(oyuncu: p, boyut: 24),
          const SizedBox(width: 6),
          Text(o.ayrildi ? '${p.kisaAd} (ayrıldı)' : '${p.kisaAd} ${puanYaz(o.puan2)}'),
        ]),
      ),
    );
  }

  Widget _kart(int i) {
    final r = context.renkler;
    final k = _oyun.kartlar[i];
    final sahip = k.sahip == null ? null : _oyuncu(k.sahip!);
    final ac = k.acik || k.eslesti;
    final sure = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 350);
    return Semantics(
      button: !ac,
      label: k.eslesti
          ? 'Kart ${i + 1}, eşleşti, eşleştiren: ${sahip?.ad ?? ''}'
          : k.acik
              ? 'Kart ${i + 1}, açık'
              : 'Kart ${i + 1}, kapalı, çevirmek için çift dokun',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _dokun(i),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: ac ? 1 : 0),
          duration: sure,
          builder: (context, v, _) {
            final on = v > 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(pi * v),
              child: on
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(pi),
                      child: _on(k, sahip),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: r.ikincil,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.ac_unit_rounded, color: Colors.white54, size: 28),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _on(HafizaKart k, Oyuncu? sahip) {
    final r = context.renkler;
    return Container(
      decoration: BoxDecoration(
        color: r.yuzey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sahip?.stil.renk ?? r.yukseltilmis, width: sahip == null ? 1 : 3),
      ),
      child: Stack(children: [
        Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(_tumSimgeler[k.sembol], size: 48, color: r.metin),
            ),
          ),
        ),
        if (sahip != null)
          Positioned(top: 2, right: 2, child: OyuncuSimgesi(oyuncu: sahip, boyut: 20)),
      ]),
    );
  }

  Widget _final() {
    final r = context.renkler;
    final sira = _oyun.siralama();
    final fil = _oyun.filHafizasi();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.emoji_events_rounded, size: 72, color: r.vurgu),
          Text('Final',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(children: [
              for (final s in sira)
                Card(
                  child: ListTile(
                    minTileHeight: 64,
                    leading: Text('${s.sira}.',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    title: Row(children: [
                      OyuncuSimgesi(oyuncu: _oyuncu(s.oyuncuId), boyut: 32),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_oyuncu(s.oyuncuId).ad)),
                    ]),
                    subtitle: s.enUzunSeri > 1 ? Text('En uzun seri: ${s.enUzunSeri}') : null,
                    trailing: Text('${puanYaz(s.puan2)} puan',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                ),
              for (final id in fil)
                ListTile(
                  leading: const Icon(Icons.psychology_rounded),
                  title: Text('Fil Hafızası: ${_oyuncu(id).ad}'),
                ),
            ]),
          ),
          FilledButton(onPressed: _yeniOyun, child: const Text('Tekrar oyna')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              ref.read(oturumProvider.notifier).tamamlandi();
              context.go('/');
            },
            child: const Text('Ana sayfa'),
          ),
        ],
      ),
    );
  }
}
