import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/premium.dart';
import '../../app/theme.dart';
import '../../content/deste.dart';
import '../../content/gecmis.dart';
import '../../content/icerik.dart';
import '../../content/icerik_deposu.dart';
import '../../core/sure_sayaci.dart';
import '../../core/tr_text.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'tod_mantik.dart';
import '../../platform/titresim.dart';

const _dosya = '06-dogruluk-cesaret';

final dogrulukCesaret = OyunUygulamasi(
  id: '06',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'seviye',
      baslik: 'Seviye',
      secenekler: {'tatli': 'Tatlı', 'komik': 'Komik', 'kisisel': 'Biraz kişisel'},
      varsayilan: 'tatli',
    ),
    AyarSatiri(
      anahtar: 'sira',
      baslik: 'Sıra nasıl seçilsin?',
      secenekler: {'sise': 'Şişe', 'sirayla': 'Sırayla', 'kura': 'Kura'},
      varsayilan: 'sise',
    ),
    AyarSatiri(
      anahtar: 'pas',
      baslik: 'Pas hakkı',
      secenekler: {'0': '0', '1': '1', '2': '2', '3': '3', '5': '5'},
      varsayilan: '3',
    ),
    AyarSatiri(
      anahtar: 'joker',
      baslik: 'Joker hakkı',
      secenekler: {'0': '0', '1': '1', '2': '2'},
      varsayilan: '1',
    ),
    AyarSatiri(
      anahtar: 'hedef',
      baslik: 'Kart sayısı',
      secenekler: {'10': '10', '20': '20', '30': '30', '0': 'Sınırsız'},
      varsayilan: '20',
    ),
    AyarSatiri(
      anahtar: 'sure',
      baslik: 'Görev süresi',
      secenekler: {'0': 'Kapalı', '30': '30 sn', '60': '60 sn'},
      varsayilan: '0',
      gelismis: true,
    ),
    AyarSatiri(
      anahtar: 'fiziksel',
      baslik: 'Ayakta görevler',
      secenekler: {'hayir': 'Kapalı', 'evet': 'Açık'},
      varsayilan: 'hayir',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => DogrulukCesaretEkrani(oturum: oturum),
);

class DogrulukCesaretEkrani extends ConsumerStatefulWidget {
  const DogrulukCesaretEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<DogrulukCesaretEkrani> createState() => _TodDurum();
}

class _TodDurum extends ConsumerState<DogrulukCesaretEkrani>
    with SingleTickerProviderStateMixin {
  final _sayac = SureSayaci();
  final _gecmis = GecmisDeposu();
  late final AnimationController _sise;
  late TodOyunu _oyun;
  Deste<IcerikOgesi>? _dogruluk;
  Deste<IcerikOgesi>? _cesaret;
  final Map<String, IcerikOgesi> _kartlar = {};
  String? _hata;
  String? _bilgi;
  bool _doner = false;
  double _bitisAcisi = 0;
  int _bildirilenYenilenme = 0;

  OyunOturumu get _o => widget.oturum;
  bool get _fizikselAcik => _o.ayar('fiziksel') == 'evet';

  @override
  void initState() {
    super.initState();
    _sise = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _oyunuKur();
    _yukle();
  }

  void _oyunuKur() {
    _oyun = TodOyunu(
      oyuncular: _o.oyuncular,
      ayar: TodAyar(
        sira: switch (_o.ayar('sira')) {
          'sirayla' => TodSira.sirayla,
          'kura' => TodSira.kura,
          _ => TodSira.sise,
        },
        pas: _o.ayarInt('pas'),
        joker: _o.ayarInt('joker'),
        gorevSn: _o.ayarInt('sure'),
        kartHedefi: _o.ayarInt('hedef'),
      ),
      kartCek: _kartCek,
    );
  }

  TodKart? _kartCek(TodTur tur, {bool alternatif = false}) {
    final deste = tur == TodTur.dogruluk ? _dogruluk : _cesaret;
    if (deste == null) return null;
    IcerikOgesi? bulunan;
    for (var i = 0; i < 30; i++) {
      final k = deste.cek();
      if (k == null) break;
      if (alternatif && (k.grup || k.fiziksel)) {
        deste.gorulmemisSay(k);
        continue;
      }
      bulunan = k;
      break;
    }
    if (bulunan == null) return null;
    if (deste.yenilenme > _bildirilenYenilenme) {
      _bildirilenYenilenme = deste.yenilenme;
      _bilgi = ref.read(premiumProvider)
          ? 'Havuz yenilendi.'
          : 'Ücretsiz kartlar bitti. Premium\'da tam içerik var.';
    }
    _gecmis.gorulenleriKaydet(
      '06',
      {...?_dogruluk?.gorulen, ...?_cesaret?.gorulen},
    );
    return TodKart(
      id: bulunan.id,
      tur: tur,
      metin: bulunan.metin,
      grup: bulunan.grup,
      fiziksel: bulunan.fiziksel,
    );
  }

  Future<void> _yukle() async {
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      final bildirilen = await _gecmis.bildirilenler('06');
      final gorulen = await _gecmis.gorulenler('06');
      final havuz = tum.where((o) {
        if (o.seviye != _o.ayar('seviye')) return false;
        if (bildirilen.contains(o.id)) return false;
        if (o.fiziksel && !_fizikselAcik) return false;
        return true;
      }).toList();
      final d = havuz.where((o) => o.tur == 'dogruluk').toList();
      final c = havuz.where((o) => o.tur == 'cesaret').toList();
      if (d.isEmpty || c.isEmpty) {
        setState(() => _hata = 'Bu ayarlarla yeterli kart yok.');
        return;
      }
      _dogruluk = Deste(d, idOf: (o) => o.id, gorulmus: gorulen);
      _cesaret = Deste(c, idOf: (o) => o.id, gorulmus: gorulen);
      for (final o in havuz) {
        _kartlar[o.id] = o;
      }
      if (_fizikselAcik) await _guvenlikUyarisi();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _hata = 'Kartlar yüklenemedi.');
    }
  }

  Future<void> _guvenlikUyarisi() async {
    if (!mounted) return;
    final tamam = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ayakta görevler var',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                  'Çevrende kırılacak, sıcak ya da keskin bir şey olmasın. Kendini iyi hissetmiyorsan Pas de.'),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Anladım, aç')),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Vazgeç')),
            ],
          ),
        ),
      ),
    );
    if (tamam != true && mounted) {
      context.go('/oyun/${_o.oyun.id}/ayar');
    }
  }

  @override
  void dispose() {
    _sayac.dispose();
    _sise.dispose();
    super.dispose();
  }

  // --- Akış ---

  bool get _hareketAzalt => MediaQuery.of(context).disableAnimations;

  Future<void> _siseyiCevir() async {
    if (_doner) return;
    final id = _oyun.siraCek();
    Titresim.hafif();
    final idx = _oyun.durumlar.indexWhere((d) => d.oyuncu.id == id);
    final n = _oyun.durumlar.length;
    final hedef = 2 * math.pi * idx / n;
    if (_hareketAzalt || _o.ayar('sira') != 'sise') {
      setState(() => _bitisAcisi = hedef);
      await Future<void>.delayed(const Duration(seconds: 1));
    } else {
      setState(() {
        _doner = true;
        _bitisAcisi = hedef + 4 * math.pi;
      });
      _sise.reset();
      await _sise.forward();
    }
    if (!mounted) return;
    setState(() => _doner = false);
    _secimBaslat();
  }

  void _secimBaslat() {
    _sayac.baslat(10000, bitince: () {
      if (_oyun.asama == TodAsama.secim) {
        _sec(TodTur.dogruluk, otomatik: true);
      }
    });
    setState(() {});
  }

  void _sec(TodTur tur, {bool otomatik = false}) {
    _sayac.durdur();
    try {
      _oyun.sec(tur);
    } on StateError {
      setState(() => _hata = 'Kartlar bitti.');
      return;
    }
    Titresim.hafif();
    if (otomatik) _bilgi = 'Süre doldu, Doğruluk seçildi.';
    setState(() {});
  }

  void _basla() {
    _oyun.basla();
    _sayac.baslat(_o.ayarInt('sure') * 1000, bitince: () => setState(() {}));
    setState(() {});
  }

  void _tamam() {
    _sayac.durdur();
    _oyun.tamam();
    Titresim.orta();
    _sonraki();
  }

  void _gec() {
    _sayac.durdur();
    _oyun.gec();
    _sonraki();
  }

  void _sonraki() => setState(() {});

  void _pas() {
    try {
      _oyun.pas();
      setState(() {});
    } on StateError {
      setState(() => _hata = 'Kartlar bitti.');
    }
  }

  Future<void> _joker() async {
    final adaylar = _oyun.jokerAdaylari;
    final secilen = await showModalBottomSheet<Oyuncu>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Görevi kime devredeceksin?',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final a in adaylar)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OyuncuCipi(
                    oyuncu: a, onTap: () => Navigator.pop(ctx, a)),
              ),
          ],
        ),
      ),
    );
    if (secilen != null) {
      _oyun.joker(secilen.id);
      setState(() {});
    }
  }

  Future<void> _bildir() async {
    final k = _oyun.kart;
    if (k == null) return;
    await _gecmis.bildir('06', k.id);
    if (!mounted) return;
    // Kartı değiştir: Pas hakkı harcamadan yeni kart.
    final yeni = _kartCek(_oyun.secilenTur!);
    if (yeni != null) {
      setState(() {
        _oyun.kart = yeni;
        _bilgi = 'Bildirildi. Bu kart bir daha gelmez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    if (_dogruluk == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListenableBuilder(
      listenable: Listenable.merge([_sayac, _sise]),
      builder: (context, _) => switch (_oyun.asama) {
        TodAsama.siraSec => _siraEkrani(),
        TodAsama.secim => _secimEkrani(),
        TodAsama.kart || TodAsama.yap => _kartEkrani(),
        TodAsama.bitti => _final(),
      },
    );
  }

  // --- Ekranlar ---

  Widget _ust() {
    final hedef = _o.ayarInt('hedef');
    return Row(
      children: [
        Text(
          hedef > 0 ? 'Kart ${_oyun.oynanan + 1}/$hedef' : 'Kart ${_oyun.oynanan + 1}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Spacer(),
        PopupMenuButton<String>(
          tooltip: 'Seçenekler',
          onSelected: (v) {
            if (v == 'bitir') {
              _sayac.durdur();
              _oyun.bitir();
              setState(() {});
            }
          },
          itemBuilder: (_) =>
              const [PopupMenuItem(value: 'bitir', child: Text('Oyunu bitir'))],
        ),
      ],
    );
  }

  Widget _bilgiSatiri() => _bilgi == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: context.renkler.yukseltilmis,
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
        );

  Widget _siraEkrani() {
    final r = context.renkler;
    final sise = _o.ayar('sira') == 'sise';
    final durumlar = _oyun.durumlar;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ust(),
          _bilgiSatiri(),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final yaricap = math.min(c.maxWidth, c.maxHeight) / 2 - 36;
              final merkez = Offset(c.maxWidth / 2, c.maxHeight / 2);
              final n = durumlar.length;
              final aci = _sise.isAnimating || _sise.value > 0
                  ? _bitisAcisi * Curves.easeOutCubic.transform(_sise.value)
                  : _bitisAcisi;
              return Stack(
                children: [
                  for (var i = 0; i < n; i++)
                    Positioned(
                      left: merkez.dx +
                          yaricap * math.cos(2 * math.pi * i / n - math.pi / 2) -
                          28,
                      top: merkez.dy +
                          yaricap * math.sin(2 * math.pi * i / n - math.pi / 2) -
                          28,
                      child: Semantics(
                        label: durumlar[i].oyuncu.ad,
                        child: Column(
                          children: [
                            OyuncuSimgesi(
                                oyuncu: durumlar[i].oyuncu, boyut: 44),
                            SizedBox(
                              width: 72,
                              child: Text(
                                durumlar[i].oyuncu.kisaAd,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _oyun.siraId ==
                                          durumlar[i].oyuncu.id
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Center(
                    child: Transform.rotate(
                      angle: aci,
                      child: Icon(Icons.arrow_upward_rounded,
                          size: yaricap * 0.9, color: r.ana),
                    ),
                  ),
                ],
              );
            }),
          ),
          Text(
            sise ? 'Şişeye dokun, dönsün.' : 'Sıradaki oyuncuyu belirle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: r.metinIkincil),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _doner ? null : _siseyiCevir,
            child: Text(sise ? 'Şişeyi çevir' : 'Sıradaki'),
          ),
        ],
      ),
    );
  }

  Widget _secimEkrani() {
    final r = context.renkler;
    final sira = _oyun.siradaki;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ust(),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text('${trUpper(sira.ad)}, sıra sende',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Text('${_sayac.kalanSn} sn',
              textAlign: TextAlign.center,
              style: TextStyle(color: r.metinIkincil)),
          const Spacer(),
          SizedBox(
            height: 120,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: r.ikincil),
              onPressed: () => _sec(TodTur.dogruluk),
              icon: const Icon(Icons.help_outline_rounded, size: 36),
              label: const Text('Doğruluk', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: r.ana),
              onPressed: () => _sec(TodTur.cesaret),
              icon: const Icon(Icons.bolt_rounded, size: 36),
              label: const Text('Cesaret', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pas: ${_oyun.durum(sira.id).pasKalan}   Joker: ${_oyun.durum(sira.id).jokerKalan}',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _kartEkrani() {
    final r = context.renkler;
    final k = _oyun.kart!;
    final yapiliyor = _oyun.asama == TodAsama.yap;
    final sureli = _o.ayarInt('sure') > 0;
    final cesaret = _oyun.secilenTur == TodTur.cesaret;
    final etiket = _oyun.devredildi
        ? 'Görev: ${_oyun.gorevSahibi.ad}'
        : '${cesaret ? 'CESARET' : 'DOĞRULUK'} · ${trUpper(_oyun.siradaki.ad)}';
    final sira = _oyun.durum(_oyun.siraId!);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ust(),
          _bilgiSatiri(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(etiket,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: 'Bildir',
                icon: const Icon(Icons.flag_rounded),
                onPressed: _bildir,
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Semantics(
                label:
                    '${cesaret ? 'Cesaret' : 'Doğruluk'} kartı: ${k.metin}',
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: r.yuzey,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: cesaret ? r.ana : r.ikincil, width: 3),
                  ),
                  child: Column(
                    children: [
                      if (k.grup || k.fiziksel)
                        Wrap(spacing: 8, children: [
                          if (k.grup) const Chip(label: Text('Grup')),
                          if (k.fiziksel) const Chip(label: Text('Ayakta')),
                        ]),
                      Text(k.metin,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.25)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (k.fiziksel)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: r.uyari.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Çevrene dikkat et. Güvenli değilse Pas de.')),
              ]),
            ),
          if (sureli && yapiliyor)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _sayac.calisiyor ? '${_sayac.kalanSn} sn' : 'Süre doldu.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          const SizedBox(height: 8),
          if (!yapiliyor)
            FilledButton(onPressed: _basla, child: const Text('Başla'))
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pas,
                    child: Text(sira.pasKalan > 0
                        ? 'Pas (${sira.pasKalan})'
                        : 'Yapamıyorum'),
                  ),
                ),
                if (_oyun.jokerKullanilabilir) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _joker,
                      child: Text('Joker (${sira.jokerKalan})'),
                    ),
                  ),
                ],
                if (_oyun.devredildi) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                        onPressed: _gec, child: const Text('Geç')),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _tamam, child: const Text('Tamam')),
          ],
        ],
      ),
    );
  }

  Widget _final() {
    final r = context.renkler;
    final cesur = _oyun.enCesurlar;
    final durust = _oyun.durustler;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.celebration_rounded, size: 96, color: r.vurgu),
          const SizedBox(height: 16),
          Text('Oyun bitti',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
              '${_oyun.oynanan} kart oynandı, ${_oyun.tamamlananToplam} görev tamamlandı.',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (cesur.isNotEmpty)
            Text('En cesur: ${cesur.map((o) => o.ad).join(', ')}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          if (durust.isNotEmpty)
            Text('Dürüst Abi/Abla: ${durust.map((o) => o.ad).join(', ')}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton(
            onPressed: () {
              _oyunuKur();
              setState(() {});
            },
            child: const Text('Tekrar oyna'),
          ),
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
