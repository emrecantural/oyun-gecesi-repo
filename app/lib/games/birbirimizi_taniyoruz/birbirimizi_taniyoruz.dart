import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../content/deste.dart';
import '../../content/gecmis.dart';
import '../../content/icerik.dart';
import '../../content/icerik_deposu.dart';
import '../../core/sure_sayaci.dart';
import '../../core/tr_text.dart';
import '../../shell/ortak/gizli_bilgi.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'tanis_mantik.dart';

const _dosya = '14-birbirimizi-taniyoruz';

final birbirimiziTaniyoruz = OyunUygulamasi(
  id: '14',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'odak',
      baslik: 'Odak tur sayısı',
      secenekler: {'1': 'Herkes 1 kez', '2': 'Herkes 2 kez'},
      varsayilan: '1',
    ),
    AyarSatiri(
      anahtar: 'soru',
      baslik: 'Soru / odak',
      secenekler: {'3': '3', '5': '5', '7': '7'},
      varsayilan: '5',
    ),
    AyarSatiri(
      anahtar: 'sure',
      baslik: 'Tahmin süresi',
      secenekler: {'10': '10 sn', '15': '15 sn'},
      varsayilan: '15',
    ),
  ],
  ekran: (context, oturum) => BirbirimiziTaniyoruzEkrani(oturum: oturum),
);

enum _Asama {
  yukleniyor,
  duyuru,
  odakGecis,
  odakSoru,
  tahminGecis,
  tahminSoru,
  reveal,
  skor,
  final_,
}

class BirbirimiziTaniyoruzEkrani extends ConsumerStatefulWidget {
  const BirbirimiziTaniyoruzEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<BirbirimiziTaniyoruzEkrani> createState() => _TanisDurum();
}

class _TanisDurum extends ConsumerState<BirbirimiziTaniyoruzEkrani> {
  final _gecmis = GecmisDeposu();
  final _sayac = SureSayaci();
  late TanisOyunu _oyun;
  Deste<IcerikOgesi>? _deste;
  _Asama _asama = _Asama.yukleniyor;
  String? _hata;

  int _odakNo = 0;
  OdakBlogu? _blok;
  int _q = 0; // blok içi soru sırası (cevaplananlar üzerinde)
  List<int> _tahminSirasi = const [];
  int _gi = 0;
  DateTime _soruBasi = DateTime.now();
  bool _kilitli = false;
  List<RevealSonucu> _revealler = const [];
  int _ri = 0;

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _p => _o.oyuncular;
  Oyuncu _oyuncu(int id) => _p.firstWhere((p) => p.id == id);
  int get _soruAdedi => _o.ayarInt('soru');
  int get _tahminMs => _o.ayarInt('sure') * 1000;

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
    _sayac.removeListener(_yenile);
    _sayac.dispose();
    super.dispose();
  }

  Future<void> _kur() async {
    _oyun = TanisOyunu(
      oyuncuIdleri: [for (final p in _p) p.id],
      odakTur: _o.ayarInt('odak'),
    );
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      final bildirilen = await _gecmis.bildirilenler('14');
      final gorulen = await _gecmis.gorulenler('14');
      final cift = _p.length == 2;
      final havuz = tum
          .where((o) =>
              o.tur == 'soru' &&
              o.ek.split('|').length >= 2 &&
              (cift || o.seviye != 'cift') &&
              !bildirilen.contains(o.id))
          .toList();
      if (havuz.length < _soruAdedi) {
        if (mounted) setState(() => _hata = 'Yeterli soru yok.');
        return;
      }
      _deste = Deste(havuz, idOf: (o) => o.id, gorulmus: gorulen);
      _odakBaslat();
    } catch (_) {
      if (mounted) setState(() => _hata = 'Sorular yüklenemedi.');
    }
  }

  void _odakBaslat() {
    if (_odakNo >= _oyun.odakSirasi.length) {
      setState(() => _asama = _Asama.final_);
      return;
    }
    final d = _deste!;
    final sorular = <TanisSoru>[];
    for (var i = 0; i < _soruAdedi; i++) {
      final s = d.cek();
      if (s == null) continue;
      sorular.add(TanisSoru(s.id, s.metin, s.ek.split('|')));
    }
    _gecmis.gorulenleriKaydet('14', d.gorulen);
    _blok = _oyun.blokAc(_oyun.odakSirasi[_odakNo], sorular);
    setState(() => _asama = _Asama.duyuru);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && _asama == _Asama.duyuru) {
        setState(() => _asama = _Asama.odakGecis);
      }
    });
  }

  // ---- odak soruları ----
  void _odakSoruBasla() {
    _q = 0;
    _soruAc(odak: true);
    setState(() => _asama = _Asama.odakSoru);
  }

  void _soruAc({required bool odak}) {
    _kilitli = false;
    _soruBasi = DateTime.now();
    _sayac.baslat(odak ? 10000 : _tahminMs, bitince: () => _sec(null));
  }

  void _sec(int? secim) {
    if (_kilitli) return;
    _kilitli = true;
    _sayac.durdur();
    HapticFeedback.selectionClick();
    final b = _blok!;
    final ms = DateTime.now().difference(_soruBasi).inMilliseconds;
    if (_asama == _Asama.odakSoru) {
      _oyun.odakCevapla(b, _q, secim);
    } else {
      final sira = b.cevaplananlar;
      _oyun.tahminEt(b, _tahminSirasi[_gi], sira[_q], secim, ms);
    }
    setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 600), _sonrakiSoru);
  }

  void _sonrakiSoru() {
    if (!mounted) return;
    final b = _blok!;
    if (_asama == _Asama.odakSoru) {
      if (_q + 1 < b.sorular.length) {
        _q++;
        _soruAc(odak: true);
        setState(() {});
      } else if (b.cevaplananlar.isEmpty) {
        // Cevap yok: odak atlandı
        _odakNo++;
        _odakBaslat();
      } else {
        _tahminSirasi = _oyun.tahminciler(b.odakId);
        _gi = 0;
        setState(() => _asama = _Asama.tahminGecis);
      }
    } else {
      final n = b.cevaplananlar.length;
      if (_q + 1 < n) {
        _q++;
        _soruAc(odak: false);
        setState(() {});
      } else if (_gi + 1 < _tahminSirasi.length) {
        _gi++;
        setState(() => _asama = _Asama.tahminGecis);
      } else {
        _revealler = _oyun.revealHesapla(b);
        _ri = 0;
        setState(() => _asama = _Asama.reveal);
      }
    }
  }

  void _tahminBasla() {
    _q = 0;
    _soruAc(odak: false);
    setState(() => _asama = _Asama.tahminSoru);
  }

  void _revealIlerle() {
    if (_ri + 1 < _revealler.length) {
      setState(() => _ri++);
    } else {
      setState(() => _asama = _Asama.skor);
    }
  }

  void _skorDevam() {
    _odakNo++;
    _odakBaslat();
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    final govde = switch (_asama) {
      _Asama.yukleniyor => const Center(child: CircularProgressIndicator()),
      _Asama.duyuru => _duyuru(),
      _Asama.odakGecis => GecisEkrani(
          oyuncu: _oyuncu(_blok!.odakId),
          ipucu: 'Odak sensin: soruları gizlice yanıtla.',
          onHazir: _odakSoruBasla,
        ),
      _Asama.odakSoru => _soruEkrani(odak: true),
      _Asama.tahminGecis => GecisEkrani(
          oyuncu: _oyuncu(_tahminSirasi[_gi]),
          ipucu: 'Odak: ${_oyuncu(_blok!.odakId).ad}. Ne seçtiğini tahmin et.',
          onHazir: _tahminBasla,
        ),
      _Asama.tahminSoru => _soruEkrani(odak: false),
      _Asama.reveal => _reveal(),
      _Asama.skor => _skor(),
      _Asama.final_ => _final(),
    };
    return Container(color: context.renkler.zemin, child: govde);
  }

  Widget _duyuru() {
    final o = _oyuncu(_blok!.odakId);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OyuncuSimgesi(oyuncu: o, boyut: 96),
          const SizedBox(height: 16),
          Text('Odak: ${trUpper(o.ad)}',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _soruEkrani({required bool odak}) {
    final r = context.renkler;
    final b = _blok!;
    final sorular = odak ? b.sorular : [for (final i in b.cevaplananlar) b.sorular[i]];
    final soru = sorular[_q];
    final baslik = odak
        ? 'Odak: ${_oyuncu(b.odakId).ad}'
        : 'Odak: ${_oyuncu(b.odakId).ad}, tahmin sırası: ${_oyuncu(_tahminSirasi[_gi]).ad}';
    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(baslik, style: TextStyle(color: r.metinIkincil)),
            Text('Soru ${_q + 1}/${sorular.length} · ${_sayac.kalanSn} sn',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            LinearProgressIndicator(value: _sayac.oran),
            const SizedBox(height: 12),
            Text(soru.metin,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (_kilitli)
              const Expanded(child: Center(child: Text('Kilitlendi ✓')))
            else
              Expanded(
                child: BasiliTutKart(
                  kapaliEtiket: 'Basılı tut: şıklar',
                  ipucu: 'Basılı tutarken diğer parmağınla şıkka dokun.',
                  azamiAcikSn: 12,
                  acik: (c) => Column(
                    children: [
                      for (var i = 0; i < soru.siklar.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            height: 64,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _sec(i),
                              child: Text('${String.fromCharCode(65 + i)}  ${soru.siklar[i]}'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reveal() {
    final r = context.renkler;
    final b = _blok!;
    final rv = _revealler[_ri];
    final soru = b.sorular[rv.qIdx];
    String ad(int id) => _oyuncu(id).ad;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Soru ${_ri + 1}/${_revealler.length} · Odak: ${ad(b.odakId)}',
              style: TextStyle(color: r.metinIkincil)),
          const SizedBox(height: 8),
          Text(soru.metin,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (var i = 0; i < soru.siklar.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: i == rv.dogruSik ? r.nane.withValues(alpha: 0.35) : r.yuzey,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: i == rv.dogruSik ? r.nane : Colors.transparent, width: 2),
              ),
              child: Text(
                  '${i == rv.dogruSik ? '✔ ★ ' : ''}${String.fromCharCode(65 + i)}  ${soru.siklar[i]}',
                  style: TextStyle(
                      fontWeight: i == rv.dogruSik ? FontWeight.w800 : FontWeight.w500)),
            ),
          if (rv.acikKitap) const Text('Açık Kitap!', textAlign: TextAlign.center),
          if (rv.gizemli) const Text('Gizemli!', textAlign: TextAlign.center),
          if (rv.bilen.isNotEmpty) Text('Bildi: ✓ ${rv.bilen.map(ad).join(', ')}'),
          if (rv.bilemeyen.isNotEmpty) Text('Bilemedi: ✕ ${rv.bilemeyen.map(ad).join(', ')}'),
          const Spacer(),
          FilledButton(onPressed: _revealIlerle, child: const Text('Sonraki')),
        ],
      ),
    );
  }

  String _sayi(double d) => d.toStringAsFixed(d == d.roundToDouble() ? 0 : 1).replaceAll('.', ',');

  Widget _skor() {
    final sirali = _p.toList()
      ..sort((a, b) => (_oyun.puan[b.id] ?? 0).compareTo(_oyun.puan[a.id] ?? 0));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Puan durumu',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          Expanded(
            child: ListView(children: [
              for (var i = 0; i < sirali.length; i++)
                ListTile(
                  leading: OyuncuSimgesi(oyuncu: sirali[i], boyut: 36),
                  title: Text('${i + 1}. ${sirali[i].ad}'),
                  trailing: Text(_sayi(_oyun.puan[sirali[i].id] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
          FilledButton(onPressed: _skorDevam, child: const Text('Devam')),
        ],
      ),
    );
  }

  Widget _final() {
    final sirali = _p.toList()
      ..sort((a, b) => (_oyun.puan[b.id] ?? 0).compareTo(_oyun.puan[a.id] ?? 0));
    final ak = _oyun.enCokAcikKitap();
    final gz = _oyun.enCokGizemli();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kim kimi tanıyor?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          Expanded(
            child: ListView(children: [
              for (var i = 0; i < sirali.length; i++)
                ListTile(
                  leading: OyuncuSimgesi(oyuncu: sirali[i], boyut: 36),
                  title: Text('${i + 1}. ${sirali[i].ad}'),
                  trailing: Text(_sayi(_oyun.puan[sirali[i].id] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              if (ak != null)
                ListTile(title: const Text('Açık Kitap'), subtitle: Text(_oyuncu(ak).ad)),
              if (gz != null)
                ListTile(title: const Text('Gizemli'), subtitle: Text(_oyuncu(gz).ad)),
            ]),
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
