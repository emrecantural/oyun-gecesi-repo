import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/premium.dart';
import '../../app/theme.dart';
import '../../content/deste.dart';
import '../../content/gecmis.dart';
import '../../content/icerik.dart';
import '../../content/icerik_deposu.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';

const _dosya = '27-gece-yarisi-sorgusu';

final geceYarisiSorgusu = OyunUygulamasi(
  id: '27',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'paket',
      baslik: 'Paket',
      secenekler: {
        'hafif': 'Hafif sohbet',
        'ani': 'Anılar ve hayaller',
        'hepsi': 'Hepsi',
      },
      varsayilan: 'hafif',
    ),
    AyarSatiri(
      anahtar: 'kart',
      baslik: 'Kart sayısı',
      secenekler: {'10': '10', '15': '15', '20': '20'},
      varsayilan: '10',
    ),
  ],
  ekran: (context, oturum) => GeceYarisiSorgusuEkrani(oturum: oturum),
);

const _seviyeAdi = {
  'tanisma': 'Tanışma',
  'anilar': 'Anılar',
  'hayaller': 'Hayaller',
  'tatli': 'Tatlı tercihler',
};

enum _Asama { devir, kart, yanit, bitti }

class GeceYarisiSorgusuEkrani extends ConsumerStatefulWidget {
  const GeceYarisiSorgusuEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<GeceYarisiSorgusuEkrani> createState() => _GeceDurum();
}

class _GeceDurum extends ConsumerState<GeceYarisiSorgusuEkrani>
    with WidgetsBindingObserver {
  final _gecmis = GecmisDeposu();
  Deste<IcerikOgesi>? _deste;
  IcerikOgesi? _kart;
  _Asama _asama = _Asama.devir;
  int _sira = 0;
  int _n = 0; // gösterilen kart sayısı
  bool _birlikte = false;
  bool _kapakli = false;
  bool _dugmeAktif = true;
  String? _hata;
  String? _bilgi;
  int _yenilenme = 0;

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _p => _o.oyuncular;
  int get _hedef => _o.ayarInt('kart');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sira = Random().nextInt(2);
    _yukle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_asama == _Asama.kart || _asama == _Asama.yanit)) {
      setState(() => _kapakli = true);
    }
  }

  Future<void> _yukle() async {
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      final bildirilen = await _gecmis.bildirilenler('27');
      final gorulen = await _gecmis.gorulenler('27');
      final seviyeler = switch (_o.ayar('paket')) {
        'hafif' => {'tanisma', 'tatli'},
        'ani' => {'anilar', 'hayaller'},
        _ => {'tanisma', 'tatli', 'anilar', 'hayaller'},
      };
      final havuz = tum
          .where((o) => seviyeler.contains(o.seviye) && !bildirilen.contains(o.id))
          .toList();
      if (havuz.isEmpty) {
        setState(() => _hata = 'Bu pakette yeni kart kalmadı.');
        return;
      }
      _deste = Deste(havuz, idOf: (o) => o.id, gorulmus: gorulen);
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _hata = 'Kartlar yüklenemedi.');
    }
  }

  void _kartiAc() {
    HapticFeedback.lightImpact();
    final d = _deste!;
    _kart = d.cek();
    _n++;
    _gecmis.gorulenleriKaydet('27', d.gorulen);
    if (d.yenilenme > _yenilenme) {
      _yenilenme = d.yenilenme;
      _bilgi = ref.read(premiumProvider)
          ? 'Havuz yenilendi.'
          : 'Ücretsiz kartlar bitti. Premium\'da tam içerik var.';
    }
    _birlikte = false;
    _asama = _Asama.kart;
    _kapakli = false;
    _dugmeAktif = false;
    setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _dugmeAktif = true);
    });
  }

  void _sonraki() {
    if (_n >= _hedef) {
      setState(() => _asama = _Asama.bitti);
      return;
    }
    setState(() {
      _sira = 1 - _sira;
      _asama = _Asama.devir;
    });
  }

  Future<void> _bildir() async {
    final k = _kart;
    if (k == null) return;
    await _gecmis.bildir('27', k.id);
    if (!mounted) return;
    setState(() => _bilgi = 'Kart atlandı, teşekkürler.');
    _sonraki();
  }

  void _bitirmekIstiyorum() => setState(() => _asama = _Asama.bitti);

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    if (_deste == null) return const Center(child: CircularProgressIndicator());
    if (_p.length != 2) {
      return const Center(child: Text('Bu oyun iki kişiyle oynanır.'));
    }
    return Container(
      color: context.renkler.zemin,
      child: switch (_asama) {
        _Asama.devir => _devir(),
        _Asama.kart => _kapakli ? _kapak() : _kartEkrani(),
        _Asama.yanit => _kapakli ? _kapak() : _yanitEkrani(),
        _Asama.bitti => _son(),
      },
    );
  }

  Widget _devir() {
    final r = context.renkler;
    final o = _p[_sira];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_bilgi != null)
            Text(_bilgi!, textAlign: TextAlign.center),
          const Spacer(),
          Center(child: OyuncuSimgesi(oyuncu: o, boyut: 96)),
          const SizedBox(height: 16),
          Text('Telefon sırası: ${o.ad}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Hazır olunca basılı tut',
              textAlign: TextAlign.center,
              style: TextStyle(color: r.metinIkincil)),
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: 'Kartı aç',
            onTap: _kartiAc,
            child: GestureDetector(
              onLongPress: _kartiAc,
              child: Container(
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: r.ana,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Basılı tut',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _bitirmekIstiyorum,
            child: const Text('Bitirmek istiyorum'),
          ),
        ],
      ),
    );
  }

  Widget _kapak() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kart gizlendi.'),
            const SizedBox(height: 12),
            GestureDetector(
              onLongPress: () => setState(() => _kapakli = false),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: context.renkler.ana, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Devam için basılı tut'),
              ),
            ),
          ],
        ),
      );

  Widget _kartKutusu(String ust) {
    final r = context.renkler;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: r.yuzey,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: r.mor, width: 2),
      ),
      child: Column(
        children: [
          Text(ust, style: TextStyle(color: r.metinIkincil)),
          const SizedBox(height: 12),
          Text(_kart!.metin,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, height: 1.25)),
        ],
      ),
    );
  }

  Widget _kartEkrani() {
    final r = context.renkler;
    final ust = 'Kart $_n/$_hedef · ${_seviyeAdi[_kart!.seviye] ?? ''}';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            label: 'Kart $_n / $_hedef. ${_kart!.metin}. Yanıtla, Pas, Sonra',
            child: _kartKutusu(ust),
          ),
          const SizedBox(height: 8),
          Text('İstemezsen yanıtlama, sorun değil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: r.metinIkincil)),
          const Spacer(),
          FilledButton(
            onPressed: _dugmeAktif ? () => setState(() => _asama = _Asama.yanit) : null,
            child: const Text('Yanıtla'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _dugmeAktif ? _sonraki : null,
            child: const Text('Pas'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _dugmeAktif ? _sonraki : null,
            child: const Text('Sonra'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _birlikte = true;
              _asama = _Asama.yanit;
            }),
            child: const Text('Birlikte yanıtlayalım'),
          ),
          TextButton(onPressed: _bildir, child: const Text('Bildir')),
        ],
      ),
    );
  }

  Widget _yanitEkrani() {
    final ust = 'Kart $_n/$_hedef';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kartKutusu(ust),
          const SizedBox(height: 16),
          Text(_birlikte ? 'İkimiz de yanıtlıyoruz' : 'Anlat, dinleyen var.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton(
            onPressed: _sonraki,
            child: Text(_birlikte ? 'Bitirdik' : 'Bitirdim'),
          ),
        ],
      ),
    );
  }

  Widget _son() {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.nightlight_round, size: 80, color: r.mor),
          const SizedBox(height: 16),
          Text('Güzel sohbetti.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('$_n kart görüldü.', textAlign: TextAlign.center),
          const Spacer(),
          FilledButton(
            onPressed: () => setState(() {
              _n = 0;
              _asama = _Asama.devir;
            }),
            child: const Text('Tekrar oyna'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
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
