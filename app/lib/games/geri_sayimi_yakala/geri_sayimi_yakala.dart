import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'gys_mantik.dart';
import '../../platform/titresim.dart';

final geriSayimiYakala = OyunUygulamasi(
  id: '18',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'mod',
      baslik: 'Mod',
      secenekler: {
        'klasik': 'Klasik: sayaç kaybolur',
        'kor': 'Kör: sayaç hiç görünmez',
      },
      varsayilan: 'klasik',
    ),
    AyarSatiri(
      anahtar: 'hedef',
      baslik: 'Hedef süre',
      secenekler: {'5': '5 sn', '7': '7 sn', '10': '10 sn', '12': '12 sn'},
      varsayilan: '7',
    ),
    AyarSatiri(
      anahtar: 'tur',
      baslik: 'Tur sayısı',
      secenekler: {'3': '3', '5': '5', '7': '7'},
      varsayilan: '3',
    ),
    AyarSatiri(
      anahtar: 'gorunur',
      baslik: 'Sayaç kaç sn görünsün? (Klasik)',
      secenekler: {'2': '2 sn', '1': '1 sn', '0': 'Hemen gizle'},
      varsayilan: '2',
      gelismis: true,
    ),
    AyarSatiri(
      anahtar: 'rahat',
      baslik: 'Rahat mod (kapanış penceresi uzar)',
      secenekler: {'hayir': 'Kapalı', 'evet': 'Açık'},
      varsayilan: 'hayir',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => GeriSayimiYakalaEkrani(oturum: oturum),
);

enum _Asama { hazir, sayac, kapat, reveal, bitti }

class GeriSayimiYakalaEkrani extends ConsumerStatefulWidget {
  const GeriSayimiYakalaEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<GeriSayimiYakalaEkrani> createState() => _GysDurum();
}

class _GysDurum extends ConsumerState<GeriSayimiYakalaEkrani>
    with WidgetsBindingObserver {
  late GysOyunu _oyun;
  _Asama _asama = _Asama.hazir;
  final Map<int, int> _bolgeBasili = {}; // zoneIndex -> pointer sayısı
  final Map<int, int> _pointerBolge = {}; // pointerId -> zoneIndex
  bool _hepsiAyniAnda = false;
  Duration? _t0; // sayaç başlangıcı (olay saat tabanı)
  Duration? _hedefAn; // hedef an (olay saat tabanı)
  final Stopwatch _saat = Stopwatch();
  Timer? _kare;
  Timer? _baslatZamani;
  Timer? _uyariZamani;
  final Map<int, double> _sapma = {};
  List<GysSira>? _sonuc;
  bool _hedefGecti = false;
  bool _sayacUyarisi = false;
  String? _bilgi;

  OyunOturumu get _o => widget.oturum;
  int get _hedefSn => _o.ayarInt('hedef');
  bool get _kor => _o.ayar('mod') == 'kor';
  int get _gorunurSn => _kor ? 0 : _o.ayarInt('gorunur');
  int get _kapatMs => _o.ayar('rahat') == 'evet' ? 4500 : 3000;
  List<Oyuncu> get _oyuncular => _o.oyuncular;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _oyunuKur();
    _hazirla();
  }

  void _oyunuKur() {
    _oyun = GysOyunu(
      oyuncuIdleri: [for (final o in _oyuncular) o.id],
      turSayisi: _o.ayarInt('tur'),
    );
  }

  void _hazirla() {
    _kare?.cancel();
    _baslatZamani?.cancel();
    _uyariZamani?.cancel();
    _kapatZamani?.cancel();
    _saat
      ..stop()
      ..reset();
    _bolgeBasili.clear();
    _pointerBolge.clear();
    _hepsiAyniAnda = false;
    _t0 = null;
    _hedefAn = null;
    _sapma.clear();
    _hedefGecti = false;
    _sayacUyarisi = false;
    _asama = _Asama.hazir;
    _uyariZamani = Timer(const Duration(seconds: 10), () {
      if (mounted && _asama == _Asama.hazir && !_hepsiAyniAnda) {
        setState(() => _sayacUyarisi = true);
      }
    });
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A1 istisnası (K-04): sayaç–kapat arasında arka plan turu iptal eder.
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        (_asama == _Asama.sayac || _asama == _Asama.kapat)) {
      _hazirla();
      setState(() => _bilgi = 'Tur yarıda kaldı, yeniden oynanacak.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kare?.cancel();
    _baslatZamani?.cancel();
    _uyariZamani?.cancel();
    _kapatZamani?.cancel();
    super.dispose();
  }

  // --- Dokunma ---

  void _asagi(int bolge, PointerDownEvent e) {
    if (_asama == _Asama.hazir) {
      _pointerBolge[e.pointer] = bolge;
      _bolgeBasili[bolge] = (_bolgeBasili[bolge] ?? 0) + 1;
      if (_bolgeBasili.values.where((v) => v > 0).length == _oyuncular.length) {
        _hepsiAyniAnda = true;
      }
      Titresim.secim();
      setState(() {});
      return;
    }
    if (_asama != _Asama.sayac && _asama != _Asama.kapat) return;
    final t0 = _t0;
    final hedef = _hedefAn;
    if (t0 == null || hedef == null) return;
    if (e.timeStamp < t0) return; // TOO_EARLY
    final id = _oyuncular[bolge].id;
    if (_sapma.containsKey(id)) return; // SECOND_TOUCH
    _sapma[id] = (e.timeStamp - hedef).inMicroseconds / 1000.0;
    Titresim.hafif();
    setState(() {});
    if (_sapma.length == _oyuncular.length) _kapatmayiPlanla();
  }

  void _yukari(PointerEvent e) {
    if (_asama != _Asama.hazir) return;
    final bolge = _pointerBolge.remove(e.pointer);
    if (bolge == null) return;
    _bolgeBasili[bolge] = (_bolgeBasili[bolge] ?? 1) - 1;
    final kalan = _bolgeBasili.values.fold<int>(0, (a, b) => a + b);
    if (kalan == 0 && _hepsiAyniAnda) {
      _sayaciKur(e.timeStamp);
    }
    setState(() {});
  }

  void _sayaciKur(Duration birakis) {
    _uyariZamani?.cancel();
    _t0 = birakis + const Duration(seconds: 1);
    _hedefAn = _t0! + Duration(seconds: _hedefSn);
    _asama = _Asama.sayac;
    _baslatZamani = Timer(const Duration(seconds: 1), () {
      _saat
        ..reset()
        ..start();
      _kare = Timer.periodic(const Duration(milliseconds: 30), (_) => _kareGuncelle());
    });
    setState(() {});
  }

  void _kareGuncelle() {
    if (!mounted) return;
    final ms = _saat.elapsedMilliseconds;
    if (!_hedefGecti && ms >= _hedefSn * 1000) {
      _hedefGecti = true;
      _asama = _Asama.kapat;
      Titresim.orta();
      _kapatmayiPlanla(sureMs: _kapatMs);
    }
    setState(() {});
  }

  Timer? _kapatZamani;
  void _kapatmayiPlanla({int? sureMs}) {
    if (sureMs != null) {
      // Zaman aşımı: hedef + 3 sn (rahat 4,5 sn); hedef geçildikten sonra kurulur.
      _kapatZamani?.cancel();
      _kapatZamani = Timer(Duration(milliseconds: sureMs), _revealeGec);
    } else if (_hedefGecti) {
      // Herkes dokundu: en erken hedef + 0,5 sn.
      final gecen = _saat.elapsedMilliseconds - _hedefSn * 1000;
      final bekle = (500 - gecen).clamp(0, 500);
      _kapatZamani?.cancel();
      _kapatZamani = Timer(Duration(milliseconds: bekle), _revealeGec);
    }
  }

  void _revealeGec() {
    if (_asama == _Asama.reveal || _asama == _Asama.bitti) return;
    _kare?.cancel();
    _saat.stop();
    _sonuc = _oyun.turBitir({
      for (final o in _oyuncular) o.id: _sapma[o.id],
    });
    _asama = _Asama.reveal;
    Titresim.orta();
    setState(() {});
  }

  void _devam() {
    if (_oyun.bitti) {
      setState(() => _asama = _Asama.bitti);
    } else {
      _bilgi = null;
      _hazirla();
    }
  }

  // --- Arayüz ---

  /// Üst sıralar 180° döner; bölge dizilimi oyuncu sayısına göre.
  List<List<int>> _satirlar(int n) => switch (n) {
        2 => [
            [0],
            [1]
          ],
        3 => [
            [0],
            [1, 2]
          ],
        4 => [
            [0, 1],
            [2, 3]
          ],
        5 => [
            [0, 1],
            [2, 3, 4]
          ],
        _ => [
            [0, 1, 2],
            [3, 4, 5]
          ],
      };

  @override
  Widget build(BuildContext context) {
    if (_oyuncular.length < 2 || _oyuncular.length > 6) {
      return const Center(
          child: Text('Bu oyun tek cihazda 2–6 kişiyle oynanır.'));
    }
    if (_asama == _Asama.reveal) return _revealEkrani();
    if (_asama == _Asama.bitti) return _final();
    return _bolgeler();
  }

  Widget _bolgeler() {
    final satirlar = _satirlar(_oyuncular.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Expanded(child: _yarim(satirlar[0], donuk: true)),
          const SizedBox(height: 16),
          _orta(),
          const SizedBox(height: 16),
          Expanded(child: _yarim(satirlar[1], donuk: false)),
        ],
      ),
    );
  }

  Widget _yarim(List<int> bolgeler, {required bool donuk}) {
    final satir = Row(
      children: [
        for (var i = 0; i < bolgeler.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: _bolge(bolgeler[i])),
        ],
      ],
    );
    return donuk ? RotatedBox(quarterTurns: 2, child: satir) : satir;
  }

  bool get _sayacGorunur {
    if (_asama != _Asama.sayac && _asama != _Asama.kapat) return false;
    if (_kor) return false;
    return _saat.elapsedMilliseconds < _gorunurSn * 1000 && _saat.isRunning;
  }

  Widget _orta() {
    final r = context.renkler;
    final tur = '${_oyun.turlar.length + 1}/${_o.ayarInt('tur')}';
    String ana;
    switch (_asama) {
      case _Asama.hazir:
        ana = _hepsiAyniAnda ? 'Hazır…' : 'Bölgene bas ve basılı tut';
      case _Asama.sayac:
      case _Asama.kapat:
        if (!_saat.isRunning) {
          ana = 'Başladı!';
        } else if (_hedefGecti) {
          ana = 'ŞİMDİ';
        } else if (_sayacGorunur) {
          ana = (_saat.elapsedMilliseconds / 1000).toStringAsFixed(1);
        } else {
          ana = 'Zamanı hisset';
        }
      default:
        ana = '';
    }
    return Semantics(
      liveRegion: _asama == _Asama.hazir,
      child: Column(
        children: [
          Text('Tur $tur · Hedef: $_hedefSn sn${_kor ? ' · Kör' : ''}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(ana,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: _sayacGorunur ? 48 : 28,
                  fontWeight: FontWeight.w900,
                  color: _hedefGecti ? r.ana : r.metin)),
          if (_sayacUyarisi)
            const Text('Bu cihaz tüm oyuncuları aynı anda algılamıyor olabilir.',
                textAlign: TextAlign.center),
          if (_bilgi != null) Text(_bilgi!, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _bolge(int i) {
    final r = context.renkler;
    final o = _oyuncular[i];
    final basili = (_bolgeBasili[i] ?? 0) > 0;
    final aldi = _sapma.containsKey(o.id);
    String durum;
    switch (_asama) {
      case _Asama.hazir:
        durum = basili ? 'Basılı ✓' : 'BAS';
      case _Asama.sayac:
      case _Asama.kapat:
        durum = aldi ? 'Alındı ✓' : (_sayacGorunur ? 'DOKUN!' : '◌');
      default:
        durum = '';
    }
    return Semantics(
      label: '${o.ad}, dokunma bölgesi',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _asagi(i, e),
        onPointerUp: _yukari,
        onPointerCancel: _yukari,
        child: Container(
          decoration: BoxDecoration(
            color: basili || aldi
                ? o.stil.renk.withValues(alpha: 0.30)
                : r.yuzey,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: o.stil.renk, width: 3),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OyuncuSimgesi(oyuncu: o, boyut: 48),
                const SizedBox(height: 4),
                Text(o.kisaAd,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(durum,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _revealEkrani() {
    final r = context.renkler;
    final sonuc = [..._sonuc!]..sort((a, b) {
        if (a.uyudu != b.uyudu) return a.uyudu ? 1 : -1;
        return a.sira.compareTo(b.sira);
      });
    Oyuncu oyuncu(int id) => _oyuncular.firstWhere((o) => o.id == id);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tur ${_oyun.turlar.length}/${_o.ayarInt('tur')}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final s in sonuc)
                  Card(
                    child: ListTile(
                      minTileHeight: 64,
                      leading: OyuncuSimgesi(oyuncu: oyuncu(s.oyuncuId), boyut: 40),
                      title: Text(
                        '${s.sira == 1 ? '👑 ' : ''}${oyuncu(s.oyuncuId).ad}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        s.uyudu
                            ? 'Uyuyakaldı'
                            : (s.sapmaMs! < 0
                                ? '${(-s.sapmaMs!).round()} ms erken ←'
                                : '${s.sapmaMs!.round()} ms geç →'),
                      ),
                      trailing: Text('+${s.puan}',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: r.ana)),
                    ),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _devam,
            child: Text(_oyun.bitti ? 'Sonuçlar' : 'Sonraki tur'),
          ),
        ],
      ),
    );
  }

  Widget _final() {
    final r = context.renkler;
    final sira = _oyun.siralama;
    Oyuncu oyuncu(int id) => _oyuncular.firstWhere((o) => o.id == id);
    final usta = _oyun.zamanUstasi;
    final kus = _oyun.kusGibi;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.emoji_events_rounded, size: 72, color: r.vurgu),
          Text('Final',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < sira.length; i++)
                  Card(
                    child: ListTile(
                      minTileHeight: 64,
                      leading: Text('${i + 1}.',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900)),
                      title: Row(children: [
                        OyuncuSimgesi(oyuncu: oyuncu(sira[i].oyuncuId), boyut: 32),
                        const SizedBox(width: 8),
                        Expanded(child: Text(oyuncu(sira[i].oyuncuId).ad)),
                      ]),
                      trailing: Text('${sira[i].puan}',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                  ),
                if (usta != null)
                  ListTile(
                      leading: const Icon(Icons.timer_rounded),
                      title: Text('Zaman Ustası: ${oyuncu(usta).ad}')),
                if (kus != null)
                  ListTile(
                      leading: const Icon(Icons.flutter_dash_rounded),
                      title: Text('Kuş Gibi: ${oyuncu(kus).ad}')),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              _oyunuKur();
              _hazirla();
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
