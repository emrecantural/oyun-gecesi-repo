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
import 'yk_mantik.dart';

const _dosya = '10-yasak-kelime';
const _dosyaYilbasi = '10-yasak-kelime-yilbasi';

final yasakKelime = OyunUygulamasi(
  id: '10',
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
      anahtar: 'yasak',
      baslik: 'Yasak sayısı',
      secenekler: {'3': '3', '5': '5'},
      varsayilan: '5',
    ),
    AyarSatiri(
      anahtar: 'pas',
      baslik: 'Pas',
      secenekler: {'3': '3 hak', '0': 'Sınırsız'},
      varsayilan: '3',
    ),
    AyarSatiri(
      anahtar: 'zorluk',
      baslik: 'Zorluk',
      secenekler: {'orta': 'Orta', 'kolay': 'Kolay', 'zor': 'Zor', 'yilbasi': 'Yılbaşı paketi'},
      varsayilan: 'orta',
    ),
  ],
  ekran: (context, oturum) => YasakKelimeEkrani(oturum: oturum),
);

enum _Asama { yukleniyor, hazir, geriSayim, tur, ozet, final_ }

class YasakKelimeEkrani extends ConsumerStatefulWidget {
  const YasakKelimeEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<YasakKelimeEkrani> createState() => _YkDurum();
}

class _YkDurum extends ConsumerState<YasakKelimeEkrani> {
  final _gecmis = GecmisDeposu();
  final _sayac = SureSayaci();
  late YasakOyunu _oyun;
  Deste<IcerikOgesi>? _deste;
  _Asama _asama = _Asama.yukleniyor;
  String? _hata;
  String? _bilgi;
  int _yenilenme = 0;

  IcerikOgesi? _kart;
  List<String> _yasaklar = const [];
  int _geriSayim = 3;
  Timer? _gsTimer;
  bool _duraklat = false;
  final _saat = Stopwatch()..start();

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
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  Future<void> _kur() async {
    _oyun = YasakOyunu(
      oyuncuIdleri: [for (final p in _p) p.id],
      takimSayisi: _o.ayarInt('takim'),
      turPerTakim: _o.ayarInt('tur'),
      pasHakki: _o.ayarInt('pas'),
    );
    try {
      final z = _o.ayar('zorluk');
      final ana = await ref.read(icerikProvider(_dosya).future);
      final yil = await ref.read(icerikProvider(_dosyaYilbasi).future);
      final bildirilen = await _gecmis.bildirilenler('10');
      final gorulen = await _gecmis.gorulenler('10');
      final havuz = [...ana, ...yil]
          .where((o) =>
              o.tur == 'kart' &&
              o.seviye == z &&
              o.ek.split(',').where((e) => e.trim().isNotEmpty).length >= 3 &&
              !bildirilen.contains(o.id))
          .toList();
      if (havuz.length < 5) {
        if (mounted) setState(() => _hata = 'Bu seçimde kart kalmadı.');
        return;
      }
      _deste = Deste(havuz, idOf: (o) => o.id, gorulmus: gorulen);
      setState(() => _asama = _Asama.hazir);
    } catch (_) {
      if (mounted) setState(() => _hata = 'Kartlar yüklenemedi.');
    }
  }

  void _hazir() {
    HapticFeedback.mediumImpact();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
    _kartCek();
    setState(() => _asama = _Asama.tur);
    _sayac.baslat(_o.ayarInt('sure') * 1000, bitince: _turBitti);
  }

  void _kartCek() {
    final d = _deste!;
    final k = d.cek();
    if (k == null) return;
    _gecmis.gorulenleriKaydet('10', d.gorulen);
    if (d.yenilenme > _yenilenme) {
      _yenilenme = d.yenilenme;
      _bilgi = ref.read(premiumProvider)
          ? 'Havuz yenilendi.'
          : 'Ücretsiz kartlar bitti. Premium\'da tam içerik var.';
    }
    final liste =
        k.ek.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    _kart = k;
    _yasaklar = liste.take(_o.ayarInt('yasak')).toList();
    _oyun.kartGoster(k.id, _saat.elapsedMilliseconds);
  }

  void _isaretle(YkSonuc s) {
    final k = _kart;
    if (k == null || _duraklat) return;
    bool ok;
    try {
      ok = _oyun.isaretle(s, k.id, k.metin, _saat.elapsedMilliseconds);
    } on StateError {
      return;
    }
    if (!ok) return;
    HapticFeedback.mediumImpact();
    _kartCek();
    setState(() {});
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      content: Text(switch (s) {
        YkSonuc.dogru => 'Doğru',
        YkSonuc.pas => 'Pas',
        YkSonuc.ihlal => 'İhlal: kart yandı',
      }),
      action: SnackBarAction(
        label: 'Geri al',
        onPressed: () {
          if (_oyun.geriAl()) setState(() {});
        },
      ),
    ));
  }

  void _turBitti() {
    _sayac.durdur();
    _kart = null;
    SystemChrome.setPreferredOrientations(const []);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _oyun.turuBitir();
    setState(() => _asama = _Asama.ozet);
  }

  void _ozetDevam() {
    setState(() => _asama = _oyun.bitti ? _Asama.final_ : _Asama.hazir);
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
    final k = _kart;
    if (k == null) return;
    await _gecmis.bildir('10', k.id);
    _kartCek();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    final govde = switch (_asama) {
      _Asama.yukleniyor => const Center(child: CircularProgressIndicator()),
      _Asama.hazir => _hazirEkrani(),
      _Asama.geriSayim => Center(
          child: Text('$_geriSayim',
              style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900)),
        ),
      _Asama.tur => _turEkrani(),
      _Asama.ozet => _ozet(),
      _Asama.final_ => _final(),
    };
    return Container(color: context.renkler.zemin, child: govde);
  }

  Widget _hazirEkrani() {
    final r = context.renkler;
    final roller = _oyun.siradakiRoller();
    final a = _oyuncu(roller.anlatici);
    final h = roller.hakem == null ? null : _oyuncu(roller.hakem!);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_bilgi != null) Text(_bilgi!, textAlign: TextAlign.center),
          Text('Tur ${_oyun.tamamlanan + 1}/${_oyun.toplamTur} · Sıra: ${_takimAdi(_oyun.siradakiTakim)}',
              textAlign: TextAlign.center),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OyuncuSimgesi(oyuncu: a, boyut: 64),
            const SizedBox(width: 12),
            Text('Anlatıcı: ${a.ad}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          if (h != null)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OyuncuSimgesi(oyuncu: h, boyut: 48),
              const SizedBox(width: 12),
              Text('Hakem: ${h.ad}', style: Theme.of(context).textTheme.titleMedium),
            ])
          else
            const Text('Dürüstlük modu', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('Anlatıcı ve hakem yan yana otursun; ekran takım arkadaşlarına dönük olmasın.',
              textAlign: TextAlign.center, style: TextStyle(color: r.metinIkincil)),
          const Spacer(),
          GizliEkranDugme(onBasili: _hazir),
        ],
      ),
    );
  }

  Widget _turEkrani() {
    final r = context.renkler;
    final k = _kart;
    final tur = _oyun.aktif!;
    return GizliEkran(
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 96),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            k == null ? '' : trHedef(k.metin),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          children: [
                            for (final y in _yasaklar)
                              Text('✕ $y',
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: r.tehlike)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Doğru ${tur.dogru} · İhlal ${tur.ihlal}'),
                      ],
                    ),
                  ),
                  if (tur.hakemId != null)
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('HAKEM', style: TextStyle(color: r.metinIkincil)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 96,
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: r.tehlike),
                              onPressed: _duraklat ? null : () => _isaretle(YkSonuc.ihlal),
                              child: const Text('BİP!',
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ),
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
            top: 10,
            child: IconButton(
              tooltip: 'Duraklat',
              onPressed: _duraklatAc,
              icon: const Icon(Icons.pause_circle_outline),
            ),
          ),
          Positioned(
            right: 12,
            top: 16,
            child: Text('${_takimAdi(tur.takim)} · ${_sayac.kalanSn} sn',
                style: const TextStyle(fontWeight: FontWeight.w700)),
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
                    child: OutlinedButton(
                      onPressed: _duraklat || !_oyun.pasVar ? null : () => _isaretle(YkSonuc.pas),
                      child: Text(_o.ayarInt('pas') == 0
                          ? '✕ PAS'
                          : (_oyun.pasVar ? '✕ PAS ${_oyun.pasKalan}/${_o.ayarInt('pas')}' : 'Pas bitti')),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 72,
                    child: OutlinedButton(
                      onPressed: _duraklat ? null : () => _isaretle(YkSonuc.ihlal),
                      child: const Text('⚠ İHLAL'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 72,
                    child: FilledButton(
                      onPressed: _duraklat ? null : () => _isaretle(YkSonuc.dogru),
                      child: const Text('✓ DOĞRU'),
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
                    FilledButton(onPressed: _devam, child: const Text('Devam et')),
                    TextButton(onPressed: _turBitti, child: const Text('Turu bitir')),
                    TextButton(onPressed: _bildir, child: const Text('Bu kartı bildir')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Hedef metin olduğu gibi gösterilir (büyük harfe çevirme yok: ek karışıklığı).
  String trHedef(String s) => s;

  Widget _ozet() {
    final t = _oyun.turlar.last;
    final a = _oyuncu(t.anlaticiId);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_takimAdi(t.takim)}: ${t.dogru} doğru · ${t.ihlal} ihlal (kart yandı) · ${t.pas} pas = +${t.puan}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          Expanded(
            child: ListView(children: [
              for (final k in t.kayitlar)
                ListTile(
                  leading: Text(
                      switch (k.sonuc) {
                        YkSonuc.dogru => '✓',
                        YkSonuc.ihlal => '⚠',
                        YkSonuc.pas => '✕',
                      },
                      style: const TextStyle(fontSize: 22)),
                  title: Text(k.hedef),
                ),
              const Divider(),
              for (var i = 0; i < _oyun.takimSayisi; i++)
                ListTile(
                  title: Text(_takimAdi(i)),
                  trailing: Text('${_oyun.skor[i]}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
          Text('Anlatan: ${a.ad}', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _ozetDevam,
            child: Text(_oyun.bitti ? 'Sonuç' : 'Sonraki tur'),
          ),
        ],
      ),
    );
  }

  Widget _final() {
    final kaz = _oyun.kazananlar();
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
          const Spacer(),
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

/// Basılı tutarak onaylanan "Hazırız" düğmesi (1 sn).
class GizliEkranDugme extends StatefulWidget {
  const GizliEkranDugme({super.key, required this.onBasili});
  final VoidCallback onBasili;

  @override
  State<GizliEkranDugme> createState() => _GizliEkranDugmeDurum();
}

class _GizliEkranDugmeDurum extends State<GizliEkranDugme> {
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Semantics(
      button: true,
      label: 'Hazırız',
      onTap: widget.onBasili,
      child: GestureDetector(
        onTapDown: (_) => _t = Timer(const Duration(seconds: 1), widget.onBasili),
        onTapUp: (_) => _t?.cancel(),
        onTapCancel: () => _t?.cancel(),
        child: Container(
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: r.ana, borderRadius: BorderRadius.circular(20)),
          child: Text('Hazırız (basılı tut)',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
