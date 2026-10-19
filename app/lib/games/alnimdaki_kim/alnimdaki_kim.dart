import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../app/premium.dart';
import '../../app/theme.dart';
import '../../content/deste.dart';
import '../../content/gecmis.dart';
import '../../content/icerik.dart';
import '../../content/icerik_deposu.dart';
import '../../core/sure_sayaci.dart';
import '../../shell/ortak/gizli_bilgi.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'alnim_mantik.dart';
import 'egim.dart';

const _dosya = '29-alnimdaki-kim';

const _kategoriler = {
  'karisik': 'Karışık',
  'hayvan': 'Hayvan',
  'meslek': 'Meslek',
  'yemek': 'Yemek',
  'esya': 'Eşya',
  'yer': 'Yer',
  'film_dizi': 'Film-Dizi',
  'unlu': 'Ünlü isim',
  'yilbasi': 'Yılbaşı',
};

final alnimdakiKim = OyunUygulamasi(
  id: '29',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'sure',
      baslik: 'Tur süresi',
      secenekler: {'45': '45 sn', '60': '60 sn', '90': '90 sn'},
      varsayilan: '60',
    ),
    AyarSatiri(
      anahtar: 'tur',
      baslik: 'Tur / oyuncu',
      secenekler: {'1': '1', '2': '2', '3': '3'},
      varsayilan: '1',
    ),
    AyarSatiri(
      anahtar: 'takim',
      baslik: 'Takım',
      secenekler: {'0': 'Bireysel', '2': '2 takım', '3': '3 takım', '4': '4 takım'},
      varsayilan: '0',
    ),
    AyarSatiri(
      anahtar: 'kategori',
      baslik: 'Kategori',
      secenekler: _kategoriler,
      varsayilan: 'karisik',
    ),
    AyarSatiri(
      anahtar: 'giris',
      baslik: 'Kontrol',
      secenekler: {'egim': 'Eğim', 'dugme': 'Düğme'},
      varsayilan: 'egim',
    ),
    AyarSatiri(
      anahtar: 'pas',
      baslik: 'Pas',
      secenekler: {'3': '3 hak', '0': 'Sınırsız'},
      varsayilan: '3',
    ),
  ],
  ekran: (context, oturum) => AlnimdakiKimEkrani(oturum: oturum),
);

enum _Asama { yukleniyor, sira, hazirlik, tur, ozet, final_ }

class AlnimdakiKimEkrani extends ConsumerStatefulWidget {
  const AlnimdakiKimEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<AlnimdakiKimEkrani> createState() => _AlnimDurum();
}

class _AlnimDurum extends ConsumerState<AlnimdakiKimEkrani> {
  final _gecmis = GecmisDeposu();
  final _sayac = SureSayaci();
  late AlnimdakiOyunu _oyun;
  Deste<IcerikOgesi>? _deste;
  _Asama _asama = _Asama.yukleniyor;
  String? _hata;
  String? _bilgi;

  // tur durumu
  IcerikOgesi? _kelime;
  final List<KelimeSatiri> _satirlar = [];
  DateTime _kelimeBasi = DateTime.now();
  int _geriSayim = 3;
  bool _kalibreBekliyor = false;
  Timer? _gsTimer;
  EgimTespitcisi? _egim;
  StreamSubscription<AccelerometerEvent>? _egimAbone;
  bool _egimModu = false;
  Timer? _flasTimer;
  Color? _flas;
  String _flasYazi = '';
  bool _duraklat = false;
  int _yenilenme = 0;

  // özet düzeltme
  Timer? _ozetTimer;
  int _ozetKalan = 8;

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _p => _o.oyuncular;
  Oyuncu _oyuncu(int id) => _p.firstWhere((p) => p.id == id);

  @override
  void initState() {
    super.initState();
    _kur();
  }

  @override
  void dispose() {
    _gsTimer?.cancel();
    _flasTimer?.cancel();
    _ozetTimer?.cancel();
    _egimBitir();
    _sayac.dispose();
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  Future<void> _kur() async {
    var takim = _o.ayarInt('takim');
    if (takim >= 2 && _p.length < takim * 2) takim = 0;
    _oyun = AlnimdakiOyunu(
      oyuncuIdleri: [for (final p in _p) p.id],
      turPerOyuncu: _o.ayarInt('tur'),
      takimSayisi: takim,
      pasHakki: _o.ayarInt('pas'),
    );
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      final bildirilen = await _gecmis.bildirilenler('29');
      final gorulen = await _gecmis.gorulenler('29');
      final kat = _o.ayar('kategori');
      final havuz = tum
          .where((o) =>
              o.tur == 'oge' &&
              (kat == 'karisik' || o.seviye == kat) &&
              !bildirilen.contains(o.id))
          .toList();
      if (havuz.isEmpty) {
        if (mounted) setState(() => _hata = 'Bu kategoride kelime yok.');
        return;
      }
      _deste = Deste(havuz, idOf: (o) => o.id, gorulmus: gorulen);
      if (mounted) setState(() => _asama = _Asama.sira);
    } catch (_) {
      if (mounted) setState(() => _hata = 'Kelimeler yüklenemedi.');
    }
  }

  void _egimBaslat() {
    _egimBitir();
    if (_o.ayar('giris') != 'egim') return;
    final e = EgimTespitcisi();
    _egim = e;
    try {
      _egimAbone = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        (ev) {
          final o = e.isle(ev.x, ev.y, ev.z, DateTime.now().millisecondsSinceEpoch);
          if (o != null && _asama == _Asama.tur && _egimModu) {
            _kaydetVeIlerle(o == EgimOlayi.dogru ? Sonuc.dogru : Sonuc.pas);
          }
        },
        onError: (_) => _egimHatasi(),
        cancelOnError: true,
      );
    } catch (_) {
      _egim = null;
    }
  }

  void _egimHatasi() {
    // Sensör akışı kesildi: tur bozulmadan Düğme Moduna geç.
    _egimModu = false;
    if (mounted && _asama == _Asama.tur) {
      _flasGoster(Colors.orange.shade800, 'Eğim çalışmıyor, düğmeyle oynanacak.');
    }
  }

  void _egimBitir() {
    unawaited(_egimAbone?.cancel());
    _egimAbone = null;
  }

  void _hazirlikBaslat() {
    _egimBaslat();
    _geriSayim = 3;
    _kalibreBekliyor = false;
    _asama = _Asama.hazirlik;
    setState(() {});
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _gsTimer?.cancel();
    _gsTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_geriSayim <= 1) {
        t.cancel();
        _kalibrasyonuBekle();
      } else {
        HapticFeedback.selectionClick();
        setState(() => _geriSayim--);
      }
    });
  }

  /// 3-2-1 bitti ama eğim henüz kalibre değilse en çok 10 sn (hazırlık başından) bekler;
  /// sonra Düğme Moduna düşer (tasarım §3: "kalibrasyon 10 sn'de başarısızsa").
  void _kalibrasyonuBekle() {
    final e = _egim;
    if (_o.ayar('giris') != 'egim' || e == null || e.hazir) {
      _turBaslat();
      return;
    }
    setState(() => _kalibreBekliyor = true);
    final bas = DateTime.now();
    _gsTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted) return t.cancel();
      final gecen = DateTime.now().difference(bas).inMilliseconds + 3000;
      if (e.hazir || gecen >= 10000) {
        t.cancel();
        _kalibreBekliyor = false;
        _turBaslat();
      }
    });
  }

  void _turBaslat() {
    _egimModu = _egim?.hazir ?? false;
    _satirlar.clear();
    _duraklat = false;
    _yeniKelime();
    _asama = _Asama.tur;
    setState(() {});
    _sayac.addListener(_yenile);
    _sayac.baslat(_o.ayarInt('sure') * 1000, bitince: _turBitti);
    if (_o.ayar('giris') == 'egim' && !_egimModu) {
      _flasGoster(Colors.orange.shade800, 'Eğim çalışmıyor, düğmeyle oynanacak.');
    }
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  void _yeniKelime() {
    final d = _deste!;
    _kelime = d.cek();
    _kelimeBasi = DateTime.now();
    _gecmis.gorulenleriKaydet('29', d.gorulen);
    if (d.yenilenme > _yenilenme) {
      _yenilenme = d.yenilenme;
      _bilgi = ref.read(premiumProvider)
          ? 'Havuz yenilendi.'
          : 'Ücretsiz kelimeler bitti. Premium\'da tam içerik var.';
    }
  }

  void _kaydetVeIlerle(Sonuc s) {
    final k = _kelime;
    if (k == null || _duraklat) return;
    if (s == Sonuc.pas && _oyun.pasKalan(_satirlar) <= 0) {
      _flasGoster(Colors.orange.shade800, 'PAS BİTTİ');
      return;
    }
    final ms = DateTime.now().difference(_kelimeBasi).inMilliseconds;
    _satirlar.add(KelimeSatiri(k.id, k.metin, s, ms));
    HapticFeedback.mediumImpact();
    if (s == Sonuc.dogru) {
      _flasGoster(context.renkler.nane, '✓ DOĞRU');
    } else {
      _flasGoster(context.renkler.tehlike, '✕ PAS');
    }
    _yeniKelime();
    setState(() {});
  }

  void _flasGoster(Color c, String yazi) {
    _flasTimer?.cancel();
    setState(() {
      _flas = c;
      _flasYazi = yazi;
    });
    _flasTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flas = null);
    });
  }

  void _turBitti() {
    _sayac.removeListener(_yenile);
    _egimBitir();
    _egimModu = false;
    _kelime = null; // açık kelime sayılmaz
    _asama = _Asama.ozet;
    SystemChrome.setPreferredOrientations(const []);
    _ozetKalan = 8;
    _ozetTimer?.cancel();
    _ozetTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_ozetKalan <= 1) {
        t.cancel();
        _ozetBitir();
      } else {
        setState(() => _ozetKalan--);
      }
    });
    setState(() {});
  }

  void _ozetBitir() {
    _ozetTimer?.cancel();
    _oyun.turuBitir(List.of(_satirlar));
    _asama = _oyun.bitti ? _Asama.final_ : _Asama.sira;
    setState(() {});
  }

  void _duzelt(KelimeSatiri s) {
    // Doğru → İptal → İhlal → Doğru ; Pas satırı değişmez
    if (s.sonuc == Sonuc.pas) return;
    s.sonuc = switch (s.sonuc) {
      Sonuc.dogru => Sonuc.iptal,
      Sonuc.iptal => Sonuc.ihlal,
      _ => Sonuc.dogru,
    };
    _ozetKalan = 8;
    setState(() {});
  }

  void _duraklatAc() {
    _sayac.durdur();
    setState(() => _duraklat = true);
  }

  void _devamEt() {
    final kalan = _sayac.kalanMs;
    setState(() => _duraklat = false);
    _sayac.baslat(kalan <= 0 ? 1 : kalan, bitince: _turBitti);
  }

  Future<void> _bildir() async {
    final k = _kelime;
    if (k == null) return;
    await _gecmis.bildir('29', k.id);
    _yeniKelime();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    final r = context.renkler;
    final govde = switch (_asama) {
      _Asama.yukleniyor => const Center(child: CircularProgressIndicator()),
      _Asama.sira => _sira(),
      _Asama.hazirlik => _hazirlik(),
      _Asama.tur => _tur(),
      _Asama.ozet => _ozet(),
      _Asama.final_ => _final(),
    };
    return Container(color: r.zemin, child: govde);
  }

  String _takimAdi(int? t) => t == null ? '' : ' (Takım ${t + 1})';

  Widget _sira() {
    final id = _oyun.siradaki!;
    final o = _oyuncu(id);
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_bilgi != null) Text(_bilgi!, textAlign: TextAlign.center),
          const Spacer(),
          Center(child: OyuncuSimgesi(oyuncu: o, boyut: 96)),
          const SizedBox(height: 16),
          Text('Sıra: ${o.ad}${_takimAdi(_oyun.takimiOf(id))}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Tur ${_oyun.tamamlanan + 1}/${_oyun.toplamTur}',
              textAlign: TextAlign.center, style: TextStyle(color: r.metinIkincil)),
          const SizedBox(height: 8),
          Text(
            'Telefonu ekranı dışa dönük, alnına tut. Diğerleri kelimeyi anlatır. '
            'Doğru için ✓, pas için ✕ düğmesine basın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: r.metinIkincil),
          ),
          const Spacer(),
          FilledButton(onPressed: _hazirlikBaslat, child: const Text('Hazırım')),
        ],
      ),
    );
  }

  Widget _hazirlik() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Telefonu alnına tut…', style: TextStyle(fontSize: 22)),
            if (_kalibreBekliyor)
              const Text('Telefonu sabit tut…',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900))
            else
              Text('$_geriSayim',
                  style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _tur() {
    final r = context.renkler;
    final k = _kelime;
    final dogru = _satirlar.where((s) => s.sonuc == Sonuc.dogru).length;
    final pasKalan = _oyun.pasHakki == 0 ? null : _oyun.pasKalan(_satirlar);
    return GizliEkran(
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: _flas ?? r.yuzey,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: _duraklat
                  ? const SizedBox.shrink()
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _flas != null ? _flasYazi : (k?.metin ?? ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900),
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              value: _sayac.oran,
              minHeight: 8,
              color: _sayac.kalanSn <= 5 ? r.tehlike : r.ana,
            ),
          ),
          Positioned(
            right: 12,
            top: 16,
            child: Text('Doğru $dogru · ${_sayac.kalanSn} sn',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Positioned(
            left: 4,
            top: 8,
            child: IconButton(
              tooltip: 'Duraklat',
              onPressed: _duraklatAc,
              icon: const Icon(Icons.pause_circle_outline),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 72,
                    child: _TutKoruma(
                      etkin: _egimModu && !_duraklat,
                      onTetik: () => _kaydetVeIlerle(Sonuc.pas),
                      child: OutlinedButton(
                        onPressed: _duraklat ? null : (_egimModu ? () {} : () => _kaydetVeIlerle(Sonuc.pas)),
                        child: Text(pasKalan == null ? '✕ PAS' : '✕ PAS ($pasKalan)'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 72,
                    child: _TutKoruma(
                      etkin: _egimModu && !_duraklat,
                      onTetik: () => _kaydetVeIlerle(Sonuc.dogru),
                      child: FilledButton(
                        onPressed: _duraklat ? null : (_egimModu ? () {} : () => _kaydetVeIlerle(Sonuc.dogru)),
                        child: const Text('✓ DOĞRU'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_duraklat)
            Positioned.fill(
              child: Container(
                color: r.zemin,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Duraklatıldı', style: TextStyle(fontSize: 28)),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _devamEt, child: const Text('Devam')),
                    TextButton(
                      onPressed: () {
                        _sayac.removeListener(_yenile);
                        _sayac.durdur();
                        _turBitti();
                      },
                      child: const Text('Turu bitir'),
                    ),
                    TextButton(onPressed: _bildir, child: const Text('Bu kelimeyi bildir')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ozet() {
    final id = _oyun.siradaki!;
    final pu = turPuani(_satirlar);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              '${_oyuncu(id).ad}: ${_satirlar.where((s) => s.sonuc == Sonuc.dogru).length} doğru · '
              '${_satirlar.where((s) => s.sonuc == Sonuc.pas).length} pas = ${pu >= 0 ? '+' : ''}$pu',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Dokunarak düzelt: Doğru → İptal → İhlal  ($_ozetKalan sn)',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.renkler.metinIkincil)),
          Expanded(
            child: ListView(
              children: [
                for (final s in _satirlar)
                  ListTile(
                    onTap: () => _duzelt(s),
                    leading: Text(switch (s.sonuc) {
                      Sonuc.dogru => '✓',
                      Sonuc.pas => '✕',
                      Sonuc.iptal => '↺',
                      Sonuc.ihlal => '⚠',
                    }, style: const TextStyle(fontSize: 22)),
                    title: Text(s.metin),
                    subtitle: Text(switch (s.sonuc) {
                      Sonuc.dogru => 'Doğru',
                      Sonuc.pas => 'Pas',
                      Sonuc.iptal => 'İptal (sayılmaz)',
                      Sonuc.ihlal => 'İhlal (−1)',
                    }),
                  ),
              ],
            ),
          ),
          FilledButton(onPressed: _ozetBitir, child: const Text('Tamam')),
        ],
      ),
    );
  }

  Widget _final() {
    final r = context.renkler;
    final bp = _oyun.bireyselPuan();
    final sirali = _p.toList()..sort((a, b) => bp[b.id]!.compareTo(bp[a.id]!));
    final tp = _oyun.takimPuani();
    final dil = _oyun.dilBilmez().map((id) => _oyuncu(id).ad).join(', ');
    final tele = _oyun.telepati().map((id) => _oyuncu(id).ad).join(', ');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sonuç',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          Expanded(
            child: ListView(
              children: [
                if (tp.isNotEmpty)
                  for (final e in (tp.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value))))
                    ListTile(
                      leading: Icon(Icons.groups_rounded, color: r.mor),
                      title: Text('Takım ${e.key + 1}'),
                      trailing: Text('${e.value}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                if (tp.isNotEmpty) const Divider(),
                for (var i = 0; i < sirali.length; i++)
                  ListTile(
                    leading: OyuncuSimgesi(oyuncu: sirali[i], boyut: 36),
                    title: Text('${i + 1}. ${sirali[i].ad}'),
                    trailing: Text('${bp[sirali[i].id]}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                if (dil.isNotEmpty)
                  ListTile(title: const Text('Dil Bilmez'), subtitle: Text(dil)),
                if (tele.isNotEmpty)
                  ListTile(title: const Text('Telepati'), subtitle: Text(tele)),
              ],
            ),
          ),
          FilledButton(
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

/// Eğim Modu'nda yanlışlıkla alına/ele değmeye karşı düğme 400 ms basılı tutulmalı.
/// [etkin] false ise (Düğme Modu) sarmalayıcı hiçbir şey yapmaz; düğmenin kendi dokunuşu çalışır.
class _TutKoruma extends StatefulWidget {
  const _TutKoruma({required this.etkin, required this.onTetik, required this.child});
  final bool etkin;
  final VoidCallback onTetik;
  final Widget child;

  @override
  State<_TutKoruma> createState() => _TutKorumaDurum();
}

class _TutKorumaDurum extends State<_TutKoruma> {
  Timer? _t;

  void _iptal() {
    _t?.cancel();
    _t = null;
  }

  @override
  void dispose() {
    _iptal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.etkin) return widget.child;
    return Listener(
      onPointerDown: (_) {
        _iptal();
        _t = Timer(const Duration(milliseconds: 400), widget.onTetik);
      },
      onPointerUp: (_) => _iptal(),
      onPointerCancel: (_) => _iptal(),
      child: widget.child,
    );
  }
}
