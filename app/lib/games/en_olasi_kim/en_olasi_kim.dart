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
import '../../core/sure_sayaci.dart';
import '../../shell/ortak/oturum.dart';
import '../oyun_uygulamasi.dart';

const _dosya = '07-en-olasi-kim';

/// 07 En Olası Kim? — tek cihaz ("parmakla göster") modu.
/// Oy toplanmaz; sonuç ve rozet yoktur. Çevrimiçi oda ayrıca gelecek.
final enOlasiKim = OyunUygulamasi(
  id: '07',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'kategori',
      baslik: 'Konu',
      secenekler: {
        'hepsi': 'Karışık',
        'gunluk': 'Günlük',
        'isokul': 'İş / Okul',
        'seyahat': 'Seyahat',
        'yilbasi': 'Yılbaşı',
        'cesur': 'Cesur',
      },
      varsayilan: 'hepsi',
    ),
    AyarSatiri(
      anahtar: 'soru',
      baslik: 'Soru sayısı',
      secenekler: {'10': '10', '15': '15', '20': '20', '0': 'Sınırsız'},
      varsayilan: '15',
    ),
    AyarSatiri(
      anahtar: 'dusun',
      baslik: 'Düşünme süresi',
      secenekler: {'10': '10 sn', '15': '15 sn', '20': '20 sn'},
      varsayilan: '10',
    ),
  ],
  ekran: (context, oturum) => EnOlasiKimEkrani(oturum: oturum),
);

enum _Asama { soru, dusunme, geriSayim, goster, bitti }

class EnOlasiKimEkrani extends ConsumerStatefulWidget {
  const EnOlasiKimEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<EnOlasiKimEkrani> createState() => _EokDurum();
}

class _EokDurum extends ConsumerState<EnOlasiKimEkrani> {
  final _sayac = SureSayaci(aralik: const Duration(milliseconds: 100));
  final _gecmis = GecmisDeposu();
  Deste<IcerikOgesi>? _deste;
  IcerikOgesi? _soru;
  _Asama _asama = _Asama.soru;
  int _no = 0;
  
  String? _hata;
  String? _bilgi;
  int _bildirilen = 0;

  OyunOturumu get _o => widget.oturum;
  int get _hedef => _o.ayarInt('soru');

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      final bildirilen = await _gecmis.bildirilenler('07');
      final gorulen = await _gecmis.gorulenler('07');
      final kat = _o.ayar('kategori');
      final havuz = tum
          .where((o) =>
              (kat == 'hepsi' || o.seviye == kat) && !bildirilen.contains(o.id))
          .toList();
      if (havuz.isEmpty) {
        setState(() => _hata = 'Bu konuda soru yok.');
        return;
      }
      _deste = Deste(havuz, idOf: (o) => o.id, gorulmus: gorulen);
      _sonrakiSoru();
    } catch (_) {
      if (mounted) setState(() => _hata = 'Sorular yüklenemedi.');
    }
  }

  void _sonrakiSoru() {
    final d = _deste!;
    _soru = d.cek();
    _no++;
    _asama = _Asama.soru;
    _gecmis.gorulenleriKaydet('07', d.gorulen);
    if (d.yenilenme > _bildirilen) {
      _bildirilen = d.yenilenme;
      _bilgi = ref.read(premiumProvider)
          ? 'Havuz yenilendi.'
          : 'Ücretsiz sorular bitti. Premium\'da tam içerik var.';
    }
    setState(() {});
  }

  void _hazir() {
    HapticFeedback.lightImpact();
    _asama = _Asama.dusunme;
    _sayac.baslat(_o.ayarInt('dusun') * 1000, bitince: _geriSayimBaslat);
    setState(() {});
  }

  void _geriSayimBaslat() {
    _asama = _Asama.geriSayim;
    _sayac.baslat(3000, bitince: _goster);
    setState(() {});
  }

  void _goster() {
    HapticFeedback.heavyImpact();
    _asama = _Asama.goster;
    setState(() {});
  }

  void _sonraki() {
    if (_hedef > 0 && _no >= _hedef) {
      setState(() => _asama = _Asama.bitti);
    } else {
      _sonrakiSoru();
    }
  }

  Future<void> _bildir() async {
    final s = _soru;
    if (s == null) return;
    await _gecmis.bildir('07', s.id);
    _sayac.durdur();
    if (!mounted) return;
    _bilgi = 'Bildirildi. Bu soru bir daha gelmez.';
    _no--;
    _sonrakiSoru();
  }

  @override
  void dispose() {
    _sayac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    if (_soru == null) return const Center(child: CircularProgressIndicator());
    return ListenableBuilder(
      listenable: _sayac,
      builder: (context, _) => _asama == _Asama.bitti ? _final() : _ana(),
    );
  }

  Widget _ana() {
    final r = context.renkler;
    String? alt;
    Widget? orta;
    Widget buton;
    switch (_asama) {
      case _Asama.soru:
        alt = 'Kendinize parmak göstermek yok.';
        buton = FilledButton(onPressed: _hazir, child: const Text('Hazır mısınız?'));
      case _Asama.dusunme:
        alt = 'Düşünün…';
        orta = Text('${_sayac.kalanSn}',
            style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: r.ana));
        buton = OutlinedButton(
            onPressed: () {
              _sayac.durdur();
              _geriSayimBaslat();
            },
            child: const Text('Hazırız'));
      case _Asama.geriSayim:
        final n = (_sayac.kalanMs / 1000).ceil().clamp(1, 3);
        orta = Text('$n',
            style: TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: r.ana));
        buton = const SizedBox(height: 56);
      case _Asama.goster:
        alt = 'Şimdi göster!';
        buton = FilledButton(
            onPressed: _sonraki,
            child: Text(_hedef > 0 && _no >= _hedef ? 'Bitir' : 'Sonraki soru'));
      case _Asama.bitti:
        buton = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(_hedef > 0 ? 'Soru $_no/$_hedef' : 'Soru $_no',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: 'Soruyu bildir',
              icon: const Icon(Icons.flag_rounded),
              onPressed: _bildir,
            ),
          ]),
          if (_bilgi != null)
            Material(
              color: r.yukseltilmis,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                title: Text(_bilgi!),
                trailing: IconButton(
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _bilgi = null),
                ),
              ),
            ),
          const Spacer(),
          Semantics(
            label: 'Soru: ${_soru!.metin}',
            child: Text(_soru!.metin,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800, height: 1.25)),
          ),
          const SizedBox(height: 24),
          if (orta != null) Center(child: orta),
          if (alt != null)
            Text(alt,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: r.metinIkincil)),
          const Spacer(),
          buton,
        ],
      ),
    );
  }

  Widget _final() {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.celebration_rounded, size: 96, color: r.vurgu),
          const SizedBox(height: 16),
          Text('Gecenin sonucu',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('$_no soru soruldu.', textAlign: TextAlign.center),
          const Spacer(),
          FilledButton(
            onPressed: () {
              _no = 0;
              _sonrakiSoru();
            },
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
