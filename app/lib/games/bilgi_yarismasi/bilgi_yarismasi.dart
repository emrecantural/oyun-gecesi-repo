import 'dart:async';
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
import '../../core/sure_sayaci.dart';
import '../../shell/ortak/gizli_bilgi.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'quiz_mantik.dart';

const _dosya = '15-bilgi-yarismasi';

final bilgiYarismasi = OyunUygulamasi(
  id: '15',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'mod',
      baslik: 'Oyun şekli',
      secenekler: {'sirayla': 'Sırayla (telefon dolaşır)', 'ortak': 'Ortak ekran (2–4 kişi)'},
      varsayilan: 'sirayla',
    ),
    AyarSatiri(
      anahtar: 'soru',
      baslik: 'Soru sayısı',
      secenekler: {'10': '10', '15': '15', '20': '20'},
      varsayilan: '10',
    ),
    AyarSatiri(
      anahtar: 'sure',
      baslik: 'Süre / soru',
      secenekler: {'10': '10 sn', '15': '15 sn', '20': '20 sn'},
      varsayilan: '15',
    ),
    AyarSatiri(
      anahtar: 'zorluk',
      baslik: 'Zorluk',
      secenekler: {'karisik': 'Karışık', 'kolay': 'Kolay', 'orta': 'Orta', 'zor': 'Zor'},
      varsayilan: 'karisik',
    ),
    AyarSatiri(
      anahtar: 'joker',
      baslik: 'Joker',
      secenekler: {'50': '50-50', 'yok': 'Kapalı'},
      varsayilan: '50',
    ),
    AyarSatiri(
      anahtar: 'okuma',
      baslik: 'Okuma süresi',
      secenekler: {'2': '2 sn', '3': '3 sn', '5': '5 sn'},
      varsayilan: '3',
      gelismis: true,
    ),
    AyarSatiri(
      anahtar: 'seri',
      baslik: 'Seri çarpanı',
      secenekler: {'ac': 'Açık', 'kapali': 'Kapalı'},
      varsayilan: 'ac',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => BilgiYarismasiEkrani(oturum: oturum),
);

enum _Asama { yukleniyor, devir, oku, cevap, kilit, reveal, skor, esitlik, esitlikGecis, final_ }

const _sekil = ['▲', '◆', '●', '■'];

class BilgiYarismasiEkrani extends ConsumerStatefulWidget {
  const BilgiYarismasiEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<BilgiYarismasiEkrani> createState() => _QuizDurum();
}

class _QuizDurum extends ConsumerState<BilgiYarismasiEkrani> with WidgetsBindingObserver {
  final _gecmis = GecmisDeposu();
  final _sayac = SureSayaci();
  final _rng = Random();
  late QuizMotoru _m;
  Deste<IcerikOgesi>? _deste;
  List<SayisalSoru> _sayisal = const [];
  _Asama _asama = _Asama.yukleniyor;
  String? _hata;
  String? _bilgi;

  QuizSoru? _soru;
  SoruSonucu? _sonuc;
  int _siraIdx = 0; // bu soruda kaçıncı oyuncu
  List<int> _sira = const [];
  Set<int> _kaldirilan = {};
  bool _jokerli = false;
  int _yenilenme = 0;
  Timer? _zamanlayici;

  // eşitlik
  List<int> _esit = const [];
  int _ei = 0;
  final Map<int, int> _tahmin = {};
  final _giris = TextEditingController();
  bool _goster = false;
  SayisalSoru? _sayisalSoru;

  OyunOturumu get _o => widget.oturum;
  bool get _ortak => _o.ayar('mod') == 'ortak';
  List<Oyuncu> get _p => _o.oyuncular;
  Oyuncu _oyuncu(int id) => _p.firstWhere((p) => p.id == id);
  int get _toplamMs => _o.ayarInt('sure') * 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sayac.addListener(_yenile);
    _kur();
  }

  // ---- Kesinti (D-046 K-04): CEVAP'ta arka plana alınırsa süre akar; dönüşte ≥2 sn ise banner ----
  DateTime? _arkaPlanBasi;
  bool _kesinti = false;
  Timer? _kesintiT;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _arkaPlanBasi ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bas = _arkaPlanBasi;
      _arkaPlanBasi = null;
      if (bas != null &&
          _asama == _Asama.cevap &&
          DateTime.now().difference(bas) >= const Duration(seconds: 2)) {
        _kesintiT?.cancel();
        setState(() => _kesinti = true);
        _kesintiT = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _kesinti = false);
        });
      }
    }
  }

  void _kesintiyiYenile() {
    _kesintiT?.cancel();
    _kesinti = false;
    _sayac.durdur();
    if (_ortak) {
      // Yeni soru; eskisi puanlanmaz ve soru sayısı artmaz.
      _m.cevaplariSil();
      _soruHazirla();
    } else {
      // Aynı oyuncu aynı soruyu yeniden yanıtlar.
      _oyuncuBasla();
    }
  }

  Widget _kesintiBandi() => Positioned(
        left: 16,
        right: 16,
        top: 8,
        child: Material(
          color: context.renkler.uyari,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            title: Text(_ortak
                ? 'Arka plana alındı.'
                : '${_oyuncu(_sira[_siraIdx]).ad} yeniden yanıtlasın?'),
            trailing: TextButton(
              onPressed: _kesintiyiYenile,
              child: Text(_ortak ? 'Soruyu yenile' : 'Yeniden yanıtla'),
            ),
          ),
        ),
      );

  void _yenile() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kesintiT?.cancel();
    _zamanlayici?.cancel();
    _sayac.removeListener(_yenile);
    _sayac.dispose();
    _giris.dispose();
    super.dispose();
  }

  Future<void> _kur() async {
    if (_ortak && _p.length > 4) {
      // G8: ortak ekran en çok 4 bölge taşır.
      _hata = 'Bu ekran ${_p.length} kişiye yetmiyor. Sırayla oynayın.';
      setState(() {});
      return;
    }
    _m = QuizMotoru(
      oyuncuIdleri: [for (final p in _p) p.id],
      soruSayisi: _o.ayarInt('soru'),
      toplamMs: _toplamMs,
      joker: _o.ayar('joker') == '50',
      seriAcik: _o.ayar('seri') == 'ac',
    );
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      final bildirilen = await _gecmis.bildirilenler('15');
      final gorulen = await _gecmis.gorulenler('15');
      final z = _o.ayar('zorluk');
      final havuz = tum
          .where((o) =>
              o.tur == 'soru' &&
              (z == 'karisik' || o.seviye == z) &&
              !bildirilen.contains(o.id))
          .toList();
      _sayisal = [
        for (final o in tum)
          if (o.tur == 'sayisal') ?SayisalSoru.csvden(o.id, o.metin, o.ek)
      ];
      if (havuz.length < _m.soruSayisi) {
        if (mounted) setState(() => _hata = 'Bu seçimde soru kalmadı.');
        return;
      }
      _deste = Deste(havuz, idOf: (o) => o.id, gorulmus: gorulen);
      _soruHazirla();
    } catch (_) {
      if (mounted) setState(() => _hata = 'Sorular yüklenemedi.');
    }
  }

  void _soruHazirla() {
    final d = _deste!;
    QuizSoru? s;
    for (var i = 0; i < 20 && s == null; i++) {
      final o = d.cek();
      if (o == null) break;
      s = QuizSoru.csvden(o.id, o.metin, o.ek, _rng);
    }
    if (s == null) {
      setState(() => _hata = 'Soru verisi okunamadı.');
      return;
    }
    _gecmis.gorulenleriKaydet('15', d.gorulen);
    if (d.yenilenme > _yenilenme) {
      _yenilenme = d.yenilenme;
      _bilgi = ref.read(premiumProvider)
          ? 'Havuz yenilendi.'
          : 'Ücretsiz sorular bitti. Premium\'da tam içerik var.';
    }
    _soru = s;
    // başlama sırası her soruda kayar
    final n = _p.length;
    _sira = [for (var i = 0; i < n; i++) _p[(_m.soruNo + i) % n].id];
    _siraIdx = 0;
    if (_ortak) {
      _ortakBasla();
      return;
    }
    _asama = _Asama.devir;
    setState(() {});
  }

  // ---- Ortak ekran (SHARED): herkes aynı anda, ekran bölgelere ayrılır ----
  void _ortakBasla() {
    _kaldirilan = {};
    _jokerli = false;
    _asama = _Asama.oku;
    setState(() {});
    _zamanlayici?.cancel();
    _zamanlayici = Timer(Duration(seconds: _o.ayarInt('okuma')), () {
      if (!mounted || _asama != _Asama.oku) return;
      _sayac.baslat(_toplamMs, bitince: _ortakBitir);
      setState(() => _asama = _Asama.cevap);
    });
  }

  void _ortakSec(int oyuncuId, int secim) {
    if (_asama != _Asama.cevap || _m.yanitladi(oyuncuId)) return;
    HapticFeedback.selectionClick();
    _m.cevapla(oyuncuId, secim, _sayac.kalanMs);
    if (_p.every((p) => _m.yanitladi(p.id))) {
      _ortakBitir();
    } else {
      setState(() {});
    }
  }

  void _ortakBitir() {
    if (_asama != _Asama.cevap) return;
    _sayac.durdur();
    _sonuc = _m.soruyuBitir(_soru!);
    setState(() => _asama = _Asama.reveal);
  }

  void _oyuncuBasla() {
    _kaldirilan = {};
    _jokerli = false;
    _asama = _Asama.oku;
    setState(() {});
    _zamanlayici?.cancel();
    _zamanlayici = Timer(Duration(seconds: _o.ayarInt('okuma')), () {
      if (!mounted || _asama != _Asama.oku) return;
      _sayac.baslat(_toplamMs, bitince: () => _sec(null));
      setState(() => _asama = _Asama.cevap);
    });
  }

  void _sec(int? secim) {
    if (_asama != _Asama.cevap) return;
    final kalan = _sayac.kalanMs;
    _sayac.durdur();
    HapticFeedback.selectionClick();
    final id = _sira[_siraIdx];
    if (secim != null) _m.cevapla(id, secim, kalan, jokerli: _jokerli);
    setState(() => _asama = _Asama.kilit);
    _zamanlayici?.cancel();
    _zamanlayici = Timer(const Duration(seconds: 1), _siradaki);
  }

  void _siradaki() {
    if (!mounted) return;
    if (_siraIdx + 1 < _sira.length) {
      _siraIdx++;
      setState(() => _asama = _Asama.devir);
    } else {
      _sonuc = _m.soruyuBitir(_soru!);
      setState(() => _asama = _Asama.reveal);
    }
  }

  void _joker() {
    final id = _sira[_siraIdx];
    try {
      _kaldirilan = _m.jokerKullan(id, _soru!, _rng).toSet();
      _jokerli = true;
    } catch (_) {}
    setState(() {});
  }

  void _revealDevam() {
    setState(() => _asama = _Asama.skor);
  }

  void _skorDevam() {
    if (_m.sonSoru) {
      _esit = _m.esitlik();
      if (_esit.isNotEmpty && _sayisal.isNotEmpty) {
        _sayisalSoru = _sayisal[_rng.nextInt(_sayisal.length)];
        _ei = 0;
        _tahmin.clear();
        _asama = _Asama.esitlikGecis;
      } else {
        _asama = _Asama.final_;
      }
      setState(() {});
      return;
    }
    _m.sonraki();
    _soruHazirla();
  }

  void _kilitle() {
    final v = int.tryParse(_giris.text);
    if (v == null) return;
    _tahmin[_esit[_ei]] = v;
    _giris.clear();
    _goster = false;
    if (_ei + 1 < _esit.length) {
      _ei++;
      setState(() => _asama = _Asama.esitlikGecis);
    } else {
      setState(() => _asama = _Asama.final_);
    }
  }

  Future<void> _bildir() async {
    final s = _soru;
    if (s == null) return;
    await _gecmis.bildir('15', s.id);
    if (mounted) setState(() => _bilgi = 'Teşekkürler, bildirildi.');
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    final govde = switch (_asama) {
      _Asama.yukleniyor => const Center(child: CircularProgressIndicator()),
      _Asama.devir => GecisEkrani(
          oyuncu: _oyuncu(_sira[_siraIdx]),
          ipucu: 'Soru ${_m.soruNo + 1}/${_m.soruSayisi}. Hazır olunca başla.',
          onHazir: _oyuncuBasla,
        ),
      _Asama.oku => _okuEkrani(),
      _Asama.cevap => _cevapEkrani(),
      _Asama.kilit => const Center(
          child: Text('Yanıtın alındı ✓', style: TextStyle(fontSize: 24)),
        ),
      _Asama.reveal => _reveal(),
      _Asama.skor => _skor(),
      _Asama.esitlikGecis => GecisEkrani(
          oyuncu: _oyuncu(_esit[_ei]),
          ipucu: 'Eşitlik! Sayı tahmini. En yakın tahmin kazanır.',
          onHazir: () => setState(() => _asama = _Asama.esitlik),
        ),
      _Asama.esitlik => _esitlik(),
      _Asama.final_ => _final(),
    };
    return Container(
      color: context.renkler.zemin,
      child: Stack(children: [
        Positioned.fill(child: govde),
        if (_kesinti && _asama == _Asama.cevap) _kesintiBandi(),
      ]),
    );
  }

  Widget _baslikSatiri() => Text(
      '${_ortak ? '' : '${_oyuncu(_sira[_siraIdx]).ad} · '}Soru ${_m.soruNo + 1}/${_m.soruSayisi}'
      '${_m.sonSoru ? ' · Son soru: çift puan!' : ''}',
      style: TextStyle(color: context.renkler.metinIkincil));

  Widget _okuEkrani() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _baslikSatiri(),
            const Spacer(),
            Text(_soru!.metin,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            const Text('Soruyu oku…', textAlign: TextAlign.center),
            const Spacer(),
          ],
        ),
      );

  /// SHARED: her oyuncuya bir bölge; üst bölgeler karşıdan okunur için 180° döner.
  Widget _ortakCevapEkrani() {
    final r = context.renkler;
    final s = _soru!;
    final renkler = [r.tehlike, r.ana, r.uyari, r.nane];
    final n = _p.length;
    Widget bolge(Oyuncu o, {required bool ters}) {
      final cevaplandi = _m.yanitladi(o.id);
      final ic = Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: r.yuzey,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(o.ad, style: TextStyle(color: r.metinIkincil, fontWeight: FontWeight.w700)),
            Text(s.metin, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Expanded(
              child: cevaplandi
                  ? const Center(child: Text('Yanıtın alındı ✓', style: TextStyle(fontSize: 20)))
                  : GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 2.2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var i = 0; i < 4; i++)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: renkler[i],
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            onPressed: () => _ortakSec(o.id, i),
                            child: Text('${_sekil[i]} ${s.siklar[i]}',
                                maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
      return Expanded(child: ters ? RotatedBox(quarterTurns: 2, child: ic) : ic);
    }

    final ust = <Widget>[];
    final alt = <Widget>[];
    for (var i = 0; i < n; i++) {
      // 2 kişi: biri üst (ters), biri alt. 3–4 kişi: üstte ikisi (ters), altta kalanlar.
      final ustte = i < n ~/ 2;
      (ustte ? ust : alt).add(bolge(_p[i], ters: ustte));
    }
    return Column(
      children: [
        LinearProgressIndicator(value: _sayac.oran, minHeight: 8),
        Expanded(child: Row(children: ust)),
        Expanded(child: Row(children: alt)),
      ],
    );
  }

  Widget _cevapEkrani() {
    if (_ortak) return _ortakCevapEkrani();
    final r = context.renkler;
    final s = _soru!;
    final renkler = [r.tehlike, r.ana, r.uyari, r.nane];
    final jokerHakki = _o.ayar('joker') == '50' && !_m.oyuncular[_sira[_siraIdx]]!.jokerKullandi;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _baslikSatiri(),
          LinearProgressIndicator(value: _sayac.oran, minHeight: 8),
          Text('${_sayac.kalanSn} sn', textAlign: TextAlign.right),
          const SizedBox(height: 8),
          Text(s.metin,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 64,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: renkler[i],
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _kaldirilan.contains(i) ? null : () => _sec(i),
                  child: Text(_kaldirilan.contains(i)
                      ? '—'
                      : '${_sekil[i]}  ${String.fromCharCode(65 + i)}  ${s.siklar[i]}'),
                ),
              ),
            ),
          if (jokerHakki)
            TextButton(onPressed: _joker, child: const Text('Joker: 50-50')),
        ],
      ),
    );
  }

  Widget _reveal() {
    final r = context.renkler;
    final s = _soru!;
    final sn = _sonuc!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.metin,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (var i = 0; i < 4; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: i == s.dogru ? r.nane.withValues(alpha: 0.35) : r.yuzey,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: i == s.dogru ? r.nane : Colors.transparent, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i == s.dogru ? '✓ ' : ''}${_sekil[i]} ${s.siklar[i]}',
                      style: TextStyle(
                          fontWeight: i == s.dogru ? FontWeight.w800 : FontWeight.w500)),
                  if (sn.dagilim[i].isNotEmpty)
                    Text(sn.dagilim[i].map((id) => _oyuncu(id).ad).join(', '),
                        style: TextStyle(color: r.metinIkincil)),
                ],
              ),
            ),
          for (final e in sn.puanlar.entries)
            if (e.value > 0)
              Text('${_oyuncu(e.key).ad}: +${e.value}'
                  '${_m.oyuncular[e.key]!.seri >= 3 ? '  ${_m.oyuncular[e.key]!.seri} seri!' : ''}'),
          const Spacer(),
          TextButton(onPressed: _bildir, child: const Text('Bu soruyu bildir')),
          FilledButton(onPressed: _revealDevam, child: const Text('Devam')),
        ],
      ),
    );
  }

  Widget _skor() {
    final sira = _m.sira();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_m.soruNo % 5 == 4 && !_m.sonSoru ? 'Ara skor' : 'Puan durumu',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          if (_bilgi != null) Text(_bilgi!, textAlign: TextAlign.center),
          Expanded(
            child: ListView(children: [
              for (var i = 0; i < sira.length; i++)
                ListTile(
                  leading: OyuncuSimgesi(oyuncu: _oyuncu(sira[i].id), boyut: 36),
                  title: Text('${i + 1}. ${_oyuncu(sira[i].id).ad}'),
                  trailing: Text('${sira[i].puan}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
          FilledButton(onPressed: _skorDevam, child: const Text('Devam')),
        ],
      ),
    );
  }

  Widget _esitlik() {
    final q = _sayisalSoru!;
    final maske = !_goster;
    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Eşitlik! Sayı tahmini', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(q.metin,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: _giris,
              obscureText: maske,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixText: q.birim,
                suffixIcon: IconButton(
                  tooltip: 'Göster',
                  icon: Icon(maske ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _goster = !_goster),
                ),
              ),
            ),
            const Spacer(),
            FilledButton(onPressed: _kilitle, child: const Text('Kilitle')),
          ],
        ),
      ),
    );
  }

  Widget _final() {
    final r = context.renkler;
    final sira = _m.sira();
    var kazananlar = <int>{};
    if (_tahmin.isNotEmpty && _sayisalSoru != null) {
      kazananlar = QuizMotoru.yakinKazananlar(_tahmin, _sayisalSoru!.dogru).toSet();
    }
    final eh = _m.enHizli();
    final bi = _m.bilgin();
    final sa = _m.sansli();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Final',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          if (_tahmin.isNotEmpty && _sayisalSoru != null)
            Text(
                'Doğru değer: ${_sayisalSoru!.dogru} ${_sayisalSoru!.birim}. '
                'Eşitlik kazananı: ${kazananlar.map((id) => _oyuncu(id).ad).join(', ')}'
                '${kazananlar.length > 1 ? ' (paylaşıldı)' : ''}',
                textAlign: TextAlign.center),
          Expanded(
            child: ListView(children: [
              for (var i = 0; i < sira.length; i++)
                ListTile(
                  leading: OyuncuSimgesi(oyuncu: _oyuncu(sira[i].id), boyut: 36),
                  title: Text(
                      '${kazananlar.contains(sira[i].id) ? '🏆 ' : '${i + 1}. '}${_oyuncu(sira[i].id).ad}'),
                  subtitle: Text('${sira[i].dogruSayisi} doğru'),
                  trailing: Text('${sira[i].puan}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              if (eh != null)
                ListTile(
                    leading: Icon(Icons.bolt_rounded, color: r.uyari),
                    title: const Text('En hızlı'),
                    subtitle: Text(_oyuncu(eh).ad)),
              if (bi != null)
                ListTile(
                    leading: Icon(Icons.school_rounded, color: r.mor),
                    title: const Text('Bilgin'),
                    subtitle: Text(_oyuncu(bi).ad)),
              if (sa != null)
                ListTile(
                    leading: Icon(Icons.casino_rounded, color: r.nane),
                    title: const Text('Şanslı'),
                    subtitle: Text(_oyuncu(sa).ad)),
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
