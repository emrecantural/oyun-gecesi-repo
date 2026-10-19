import 'dart:async';

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
import '../../shell/ortak/gizli_bilgi.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'dilsiz_mantik.dart';

const _dosya = '09-dilsiz-sinema';

const _kategoriler = {
  'karisik': 'Karışık',
  'film': 'Film',
  'dizi': 'Dizi',
  'deyim': 'Deyim',
  'hayvan': 'Hayvan',
  'meslek': 'Meslek',
  'yilbasi': 'Yılbaşı',
};

final dilsizSinema = OyunUygulamasi(
  id: '09',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'takim',
      baslik: 'Takım',
      secenekler: {'2': '2', '3': '3', '4': '4'},
      varsayilan: '2',
    ),
    AyarSatiri(
      anahtar: 'sure',
      baslik: 'Tur süresi',
      secenekler: {'45': '45 sn', '60': '60 sn', '90': '90 sn'},
      varsayilan: '60',
    ),
    AyarSatiri(
      anahtar: 'tur',
      baslik: 'Tur / takım',
      secenekler: {'2': '2', '3': '3', '4': '4', '5': '5'},
      varsayilan: '3',
    ),
    AyarSatiri(
      anahtar: 'kategori',
      baslik: 'Kategori',
      secenekler: _kategoriler,
      varsayilan: 'karisik',
    ),
    AyarSatiri(
      anahtar: 'pas',
      baslik: 'Pas',
      secenekler: {'3': '3 hak', '-1': 'Sınırsız', '0': 'Yok'},
      varsayilan: '3',
    ),
    AyarSatiri(
      anahtar: 'ceza',
      baslik: 'Pas cezası',
      secenekler: {'0': '0', '1': '−1'},
      varsayilan: '0',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => DilsizSinemaEkrani(oturum: oturum),
);

enum _Asama { yukleniyor, sira, geriSayim, tur, ozet, skor, final_ }

class DilsizSinemaEkrani extends ConsumerStatefulWidget {
  const DilsizSinemaEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<DilsizSinemaEkrani> createState() => _DilsizDurum();
}

class _DilsizDurum extends ConsumerState<DilsizSinemaEkrani> {
  final _gecmis = GecmisDeposu();
  final _sayac = SureSayaci();
  late DilsizOyunu _oyun;
  Deste<IcerikOgesi>? _deste;
  _Asama _asama = _Asama.yukleniyor;
  String? _hata;
  String? _bilgi;
  int _yenilenme = 0;

  IcerikOgesi? _oge;
  final List<String> _sonZorluk = [];
  int _geriSayim = 3;
  Timer? _gsTimer;
  bool _duraklat = false;
  final _saat = Stopwatch()..start();
  int _sonDokunma = -1000;

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _p => _o.oyuncular;
  Oyuncu _oyuncu(int id) => _p.firstWhere((p) => p.id == id);
  String _takimAdi(int t) => 'Takım ${t + 1}';

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
    _gsTimer?.cancel();
    _sayac.removeListener(_yenile);
    _sayac.dispose();
    super.dispose();
  }

  Future<void> _kur() async {
    _oyun = DilsizOyunu(
      oyuncuIdleri: [for (final p in _p) p.id],
      takimSayisi: _o.ayarInt('takim'),
      turPerTakim: _o.ayarInt('tur'),
      pasHakki: _o.ayarInt('pas'),
      pasCezali: _o.ayar('ceza') == '1',
    );
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      final bildirilen = await _gecmis.bildirilenler('09');
      final gorulen = await _gecmis.gorulenler('09');
      final k = _o.ayar('kategori');
      final havuz = tum
          .where((o) =>
              o.tur == 'oge' &&
              (k == 'karisik' || o.seviye == k) &&
              !bildirilen.contains(o.id))
          .toList();
      if (havuz.length < 5) {
        if (mounted) setState(() => _hata = 'Bu kategoride öğe kalmadı.');
        return;
      }
      _deste = Deste(havuz, idOf: (o) => o.id, gorulmus: gorulen);
      setState(() => _asama = _Asama.sira);
    } catch (_) {
      if (mounted) setState(() => _hata = 'Öğeler yüklenemedi.');
    }
  }

  void _hazir() {
    _geriSayim = 3;
    setState(() => _asama = _Asama.geriSayim);
    _gsTimer?.cancel();
    _gsTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_geriSayim <= 1) {
        t.cancel();
        _turBasla();
      } else {
        setState(() => _geriSayim--);
      }
    });
  }

  void _turBasla() {
    _oyun.turBaslat();
    _duraklat = false;
    _sonZorluk.clear();
    _ogeCek();
    setState(() => _asama = _Asama.tur);
    _sayac.baslat(_o.ayarInt('sure') * 1000, bitince: _turBitti);
  }

  void _ogeCek() {
    final d = _deste!;
    IcerikOgesi? o = d.cek();
    // Art arda 3 "zor" gelmez
    for (var i = 0;
        i < 5 &&
            o != null &&
            o.ek == 'zor' &&
            _sonZorluk.length >= 2 &&
            _sonZorluk[_sonZorluk.length - 1] == 'zor' &&
            _sonZorluk[_sonZorluk.length - 2] == 'zor';
        i++) {
      o = d.cek();
    }
    if (o == null) return;
    _sonZorluk.add(o.ek);
    _gecmis.gorulenleriKaydet('09', d.gorulen);
    if (d.yenilenme > _yenilenme) {
      _yenilenme = d.yenilenme;
      _bilgi = ref.read(premiumProvider)
          ? 'Havuz yenilendi.'
          : 'Ücretsiz öğeler bitti. Premium\'da tam içerik var.';
    }
    _oge = o;
  }

  bool _dokunmaSerbest() {
    final n = _saat.elapsedMilliseconds;
    if (n - _sonDokunma < 400) return false;
    _sonDokunma = n;
    return true;
  }

  void _dogru() {
    final o = _oge;
    if (o == null || _duraklat || !_dokunmaSerbest()) return;
    _oyun.dogru(o.id, o.metin);
    HapticFeedback.mediumImpact();
    _ogeCek();
    setState(() {});
    _snack('Doğru');
  }

  void _pas() {
    final o = _oge;
    if (o == null || _duraklat || !_oyun.pasVar || !_dokunmaSerbest()) return;
    _oyun.pas(o.id, o.metin);
    HapticFeedback.selectionClick();
    _ogeCek();
    setState(() {});
    _snack('Pas');
  }

  void _snack(String yazi) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      content: Text(yazi),
      action: SnackBarAction(
        label: 'Geri al',
        onPressed: () {
          final k = _oyun.geriAl();
          if (k != null) {
            // geri alınan öğeyi tekrar göster
            setState(() => _oge = IcerikOgesi(
                  id: k.id,
                  oyun: '09',
                  tur: 'oge',
                  seviye: '',
                  metin: k.metin,
                  ek: '',
                  fiziksel: false,
                  grup: false,
                  risk: '',
                  durum: 'onayli',
                ));
          }
        },
      ),
    ));
  }

  void _turBitti() {
    _sayac.durdur();
    final o = _oge;
    if (o != null) _oyun.yarimKalan(o.id, o.metin);
    _oge = null;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _asama = _Asama.ozet);
  }

  void _ozetTamam() {
    _oyun.turuBitir();
    setState(() => _asama = _oyun.bitti ? _Asama.final_ : _Asama.skor);
  }

  void _duraklatAc() {
    _sayac.durdur();
    setState(() => _duraklat = true);
  }

  void _devam() {
    final kalan = _sayac.kalanMs;
    setState(() => _duraklat = false);
    _sayac.baslat(kalan <= 0 ? 1 : kalan, bitince: _turBitti);
  }

  Future<void> _bildir() async {
    final o = _oge;
    if (o == null) return;
    await _gecmis.bildir('09', o.id);
    _ogeCek();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    final govde = switch (_asama) {
      _Asama.yukleniyor => const Center(child: CircularProgressIndicator()),
      _Asama.sira => GecisEkrani(
          oyuncu: _oyuncu(_oyun.siradakiAnlatici()),
          ipucu:
              '${_takimAdi(_oyun.siradakiTakim)} · Tur ${_oyun.tamamlanan + 1}/${_oyun.toplamTur}. '
              'Hakem: diğer takımlar. ${_bilgi ?? ''}',
          onHazir: _hazir,
        ),
      _Asama.geriSayim => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_geriSayim',
                  style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900)),
              const Text('Ekranı kendine çevir. Konuşmak ve harf göstermek yasak.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      _Asama.tur => _tur(),
      _Asama.ozet => _ozet(),
      _Asama.skor => _skor(),
      _Asama.final_ => _final(),
    };
    return Container(color: context.renkler.zemin, child: govde);
  }

  Widget _tur() {
    final r = context.renkler;
    final t = _oyun.aktif!;
    final pasSatiri = _o.ayarInt('pas') == 0
        ? 'Pas yok'
        : (_o.ayarInt('pas') < 0 ? 'Pas: sınırsız' : 'Pas: ${_oyun.pasKalan} hakkın kaldı');
    return GizliEkran(
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 300) _dogru();
          if (v < -300) _pas();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 120),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_duraklat)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _oge?.metin ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text('$pasSatiri · Doğru: ${t.dogru()}',
                        style: TextStyle(color: r.metinIkincil)),
                  ],
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
              left: 4,
              top: 12,
              child: IconButton(
                tooltip: 'Duraklat',
                onPressed: _duraklatAc,
                icon: const Icon(Icons.pause_circle_outline),
              ),
            ),
            Positioned(
              right: 12,
              top: 20,
              child: Text('${_takimAdi(t.takim)} · ${_sayac.kalanSn} sn',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 72,
                      child: OutlinedButton(
                        onPressed: _duraklat || !_oyun.pasVar ? null : _pas,
                        child: Text(_oyun.pasVar
                            ? (_o.ayar('ceza') == '1' ? '◀ PAS (−1)' : '◀ PAS')
                            : 'Pas bitti'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 72,
                      child: FilledButton(
                        onPressed: _duraklat ? null : _dogru,
                        child: const Text('DOĞRU ▶'),
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
                      const Text('Ara verdik. Süre senin için bekliyor.',
                          style: TextStyle(fontSize: 22), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _devam, child: const Text('Devam')),
                      TextButton(onPressed: _turBitti, child: const Text('Turu bitir')),
                      TextButton(onPressed: _bildir, child: const Text('Bu öğeyi bildir')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ozet() {
    final r = context.renkler;
    final t = _oyun.aktif!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              '${_takimAdi(t.takim)}: ${t.dogru()} doğru · ${t.ihlal()} ihlal · ${t.pas()} pas = '
              '${t.puan(pasCezali: _o.ayar('ceza') == '1')}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          Text('Hakemler: doğru satırlarda ⚑ ile ihlal işaretleyin.',
              textAlign: TextAlign.center, style: TextStyle(color: r.metinIkincil)),
          Expanded(
            child: t.ogeler.isEmpty
                ? const Center(child: Text('Bu turda öğe kalmadı.'))
                : ListView(children: [
                    for (final k in t.ogeler)
                      ListTile(
                        leading: Text(
                            switch (k.durum) {
                              DurumOge.dogru => k.ihlal ? '⚑' : '✓',
                              DurumOge.pas => '↷',
                              DurumOge.yarim => '○',
                            },
                            style: const TextStyle(fontSize: 22)),
                        title: Text(k.metin),
                        subtitle: Text(switch (k.durum) {
                          DurumOge.dogru => k.ihlal ? 'İhlal (−1)' : 'Doğru',
                          DurumOge.pas => 'Pas',
                          DurumOge.yarim => 'Yarım kaldı, sayılmaz',
                        }),
                        trailing: k.durum == DurumOge.yarim
                            ? null
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                if (k.durum == DurumOge.dogru)
                                  IconButton(
                                    tooltip: 'İhlal',
                                    icon: Icon(
                                        k.ihlal ? Icons.flag : Icons.flag_outlined),
                                    onPressed: () =>
                                        setState(() => _oyun.ihlalIsaretle(k, !k.ihlal)),
                                  ),
                                TextButton(
                                  onPressed: () => setState(() => _oyun.duzelt(k)),
                                  child: const Text('Düzelt'),
                                ),
                              ]),
                      ),
                  ]),
          ),
          FilledButton(onPressed: _ozetTamam, child: const Text('Tamam')),
        ],
      ),
    );
  }

  Widget _skor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Skor',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          Expanded(
            child: ListView(children: [
              for (var i = 0; i < _oyun.takimSayisi; i++)
                ListTile(
                  title: Text(_takimAdi(i)),
                  trailing: Text('${_oyun.skor[i]}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
          Text('Sıradaki: ${_takimAdi(_oyun.siradakiTakim)}', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => setState(() => _asama = _Asama.sira),
            child: const Text('Devam'),
          ),
        ],
      ),
    );
  }

  Widget _final() {
    final kaz = _oyun.kazananlar();
    final mu = _oyun.mimikUstasi();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(kaz.length > 1 ? 'Eşitlik!' : '${_takimAdi(kaz.first)} kazandı!',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          for (var i = 0; i < _oyun.takimSayisi; i++)
            ListTile(
              title: Text(_takimAdi(i)),
              subtitle: Text(_oyun.takimlar[i].map((id) => _oyuncu(id).ad).join(', ')),
              trailing: Text('${_oyun.skor[i]}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          if (mu != null)
            ListTile(title: const Text('Mimik Ustası'), subtitle: Text(_oyuncu(mu).ad)),
          const Spacer(),
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
