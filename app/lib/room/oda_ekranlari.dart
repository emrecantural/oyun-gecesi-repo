import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/premium.dart';
import '../app/theme.dart';
import '../games/registry.dart';
import '../monetization/oda_gecisi.dart';
import '../platform/secure_screen.dart';
import '../shell/ortak/oyuncular.dart';
import 'oda_istemci.dart';
import 'oda_ortak.dart';
import 'oda_servisi.dart';
import 'oyun_en_olasi_kim.dart';
import 'oyun_koy_kurtlar.dart';
import 'oyun_koy_paket.dart';
import 'oyun_tombala.dart';
import 'zarf.dart';

/// Çevrimiçi odası olan oyunlar (sunucuda tanımlı olanlar).
const odaOyunlari = {'01', '03', '07'};

const _minOyuncu = {'01': 2, '03': 6, '07': 3};

/// Oda kur: takma ad → sunucuda oda → odaya gir.
class OdaKurEkrani extends ConsumerStatefulWidget {
  const OdaKurEkrani({super.key, required this.oyunId});
  final String oyunId;

  @override
  ConsumerState<OdaKurEkrani> createState() => _OdaKurDurum();
}

class _OdaKurDurum extends ConsumerState<OdaKurEkrani> {
  final _ad = TextEditingController();
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _kur() async {
    final ad = _ad.text.trim();
    if (ad.length < 2) {
      setState(() => _hata = 'NICKNAME_REJECTED');
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      final id = await installIdAl();
      final giris = await odaKur(
        oyunId: widget.oyunId,
        takmaAd: ad,
        installId: id,
        premium: ref.read(premiumProvider),
        passToken: ref.read(odaGecisiProvider).gecisId,
      );
      if (!mounted) return;
      context.pushReplacement('/oda/${giris.kod}', extra: giris);
    } on OdaHatasi catch (e) {
      if (mounted) setState(() => _hata = e.kod);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Widget _gecisKutusu() {
    final g = ref.read(odaGecisiProvider);
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (g.mesaj != null) Text(g.mesaj!),
          if (g.satinAlinabilir)
            OutlinedButton(
              onPressed: g.mesgul ? null : g.satinAl,
              child: Text('4 saatlik oda geçişi · ${g.fiyat}'),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oyun = oyunBul(widget.oyunId);
    return Scaffold(
      appBar: AppBar(title: Text('${oyun?.ad ?? 'Oyun'} · Oda kur')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!sunucuAyarli) _Uyari(metin: hataMetni('NO_SERVER')),
              TextField(
                controller: _ad,
                maxLength: 16,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Takma adın'),
              ),
              if (_hata != null) _Uyari(metin: hataMetni(_hata)),
              if (_hata == 'NO_ROOM_RIGHT' || ref.read(odaGecisiProvider).mesaj != null) _gecisKutusu(),
              const Spacer(),
              FilledButton(
                onPressed: _mesgul || !sunucuAyarli ? null : _kur,
                child: Text(_mesgul ? 'Kuruluyor…' : 'Odayı kur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Odaya katıl: kod + takma ad + (isteğe bağlı) rol.
class OdaKatilEkrani extends StatefulWidget {
  const OdaKatilEkrani({super.key});

  @override
  State<OdaKatilEkrani> createState() => _OdaKatilDurum();
}

class _OdaKatilDurum extends State<OdaKatilEkrani> {
  final _kod = TextEditingController();
  final _ad = TextEditingController();
  String _rol = 'player';
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _kod.dispose();
    _ad.dispose();
    super.dispose();
  }

  Future<void> _katil() async {
    final kod = odaKoduNormalle(_kod.text);
    final ad = _ad.text.trim();
    if (!odaKoduGecerli(kod)) {
      setState(() => _hata = 'ROOM_NOT_FOUND');
      return;
    }
    if (_rol != 'display' && ad.length < 2) {
      setState(() => _hata = 'NICKNAME_REJECTED');
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await odaOzeti(kod);
      final id = await installIdAl();
      if (!mounted) return;
      context.pushReplacement(
        '/oda/$kod',
        extra: OdaGirisi(
          kod: kod,
          wsUrl: wsAdresi(kod),
          takmaAd: _rol == 'display' ? 'Ekran' : ad,
          installId: id,
          rol: _rol,
        ),
      );
    } on OdaHatasi catch (e) {
      if (mounted) setState(() => _hata = e.kod);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Odaya katıl')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!sunucuAyarli) _Uyari(metin: hataMetni('NO_SERVER')),
            TextField(
              controller: _kod,
              maxLength: 7,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(labelText: 'Oda kodu'),
            ),
            if (_rol != 'display')
              TextField(
                controller: _ad,
                maxLength: 16,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Takma adın'),
              ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'player', label: Text('Oyuncu')),
                ButtonSegment(value: 'spectator', label: Text('İzleyici')),
                ButtonSegment(value: 'display', label: Text('Ekran')),
              ],
              selected: {_rol},
              onSelectionChanged: (s) => setState(() => _rol = s.first),
            ),
            if (_hata != null) _Uyari(metin: hataMetni(_hata)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _mesgul || !sunucuAyarli ? null : _katil,
              child: Text(_mesgul ? 'Bağlanıyor…' : 'Katıl'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Uyari extends StatelessWidget {
  const _Uyari({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: r.yukseltilmis,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.uyari),
      ),
      child: Semantics(liveRegion: true, child: Text(metin)),
    );
  }
}

/// Oda kabuğu: bağlantı, lobi ve oyun panelleri.
class OdaEkrani extends StatefulWidget {
  const OdaEkrani({super.key, required this.giris, this.tasimaUret});
  final OdaGirisi giris;

  /// Testlerde sahte taşıma vermek için.
  final OdaTasimasi Function()? tasimaUret;

  @override
  State<OdaEkrani> createState() => _OdaEkraniDurum();
}

class _OdaEkraniDurum extends State<OdaEkrani> with WidgetsBindingObserver {
  late final OdaIstemcisi _i;
  StreamSubscription<SunucuMesaji>? _abone;
  bool _ekranAcik = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _i = OdaIstemcisi(tasimaUret: widget.tasimaUret ?? WebSocketTasima.new);
    _i.addListener(_degisti);
    _abone = _i.olaylar.listen(_olay);
    final g = widget.giris;
    unawaited(_i.katil(
      wsUrl: g.wsUrl,
      kod: g.kod,
      takmaAd: g.takmaAd,
      installId: g.installId,
      istenenRol: g.rol,
      resumeToken: g.resumeToken,
    ));
  }

  void _degisti() {
    // Tombala HOST ekranı: ekran kapanmasın.
    final istek = _i.oyunId == '01' && (_i.rol == 'display' || _i.hostMu) && _i.faz != 'LOBBY' && _i.faz != 'FINAL';
    if (istek != _ekranAcik) {
      _ekranAcik = istek;
      unawaited(istek ? EkranKorumasi.acikTut() : EkranKorumasi.acikTutmayiBirak());
    }
  }

  void _olay(SunucuMesaji m) {
    if (!mounted || m.t != 'error') return;
    final kod = m.p['code'] as String?;
    if (_i.durum == BaglantiDurumu.kapali) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(hataMetni(kod))));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _i.onePlana();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_abone?.cancel());
    _i.removeListener(_degisti);
    if (_ekranAcik) unawaited(EkranKorumasi.acikTutmayiBirak());
    _i.dispose();
    super.dispose();
  }

  Future<void> _cik() async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Odadan çıkılsın mı?'),
        content: const Text('Oyun devam eder; sonra aynı kodla geri katılamayabilirsin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Kal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Çık')),
        ],
      ),
    );
    if (evet != true) return;
    await _i.ayril();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _i,
      builder: (context, _) {
        final oyun = oyunBul(_i.oyunId.isEmpty ? '' : _i.oyunId);
        if (_i.durum == BaglantiDurumu.kapali) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hataMetni(_i.kapanisNedeni ?? _i.sonHata ?? 'closed'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => context.go('/'), child: const Text('Ana ekrana dön')),
                  ],
                ),
              ),
            ),
          );
        }
        if (_i.oyunId.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (geri, _) {
            if (!geri) unawaited(_cik());
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text('${oyun?.ad ?? 'Oda'} · ${widget.giris.kod}'),
              actions: [
                IconButton(
                  tooltip: 'Odadan çık',
                  onPressed: _cik,
                  icon: const Icon(Icons.exit_to_app_rounded),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  if (_i.durum == BaglantiDurumu.yenidenBaglaniyor)
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        color: context.renkler.uyari,
                        padding: const EdgeInsets.all(8),
                        child: const Text('Bağlantı koptu, yeniden bağlanılıyor…', textAlign: TextAlign.center),
                      ),
                    ),
                  Expanded(
                    child: _i.faz == 'LOBBY' ? _Lobi(istemci: _i, kod: widget.giris.kod) : _OyunPaneli(istemci: _i),
                  ),
                  if (_i.faz == 'FINAL' && _i.hostMu)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: () => _i.gonder('rematch'),
                        child: const Text('Tekrar oyna'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OyunPaneli extends StatelessWidget {
  const _OyunPaneli({required this.istemci});
  final OdaIstemcisi istemci;

  @override
  Widget build(BuildContext context) => switch (istemci.oyunId) {
        '07' => EnOlasiKimPaneli(istemci: istemci),
        '01' => TombalaPaneli(istemci: istemci),
        '03' => KoyKurtlarPaneli(istemci: istemci),
        _ => const Center(child: Text('Bu oyun çevrimiçi desteklenmiyor.')),
      };
}

class _Lobi extends StatelessWidget {
  const _Lobi({required this.istemci, required this.kod});
  final OdaIstemcisi istemci;
  final String kod;

  @override
  Widget build(BuildContext context) {
    final i = istemci;
    final r = context.renkler;
    final oyuncular = [for (final o in i.oyuncular) if (o.rol == 'player') o];
    final min = _minOyuncu[i.oyunId] ?? 2;
    final ben = i.oyuncu(i.oyuncuId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: kod));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı')));
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Semantics(
                label: 'Oda kodu ${kod.split('').join(' ')}. Kopyalamak için dokun.',
                child: ExcludeSemantics(
                  child: Text(
                    kod,
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 8, color: r.ana),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          'Arkadaşların bu kodla “Odaya katıl”dan girebilir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: r.metinIkincil),
        ),
        const SizedBox(height: 16),
        Text('Oyuncular (${oyuncular.length})', style: Theme.of(context).textTheme.titleMedium),
        for (final o in oyuncular)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: OyuncuSimgesi(oyuncu: simgeOyuncu(i, o.id), boyut: 40),
            title: Text(o.takmaAd + (o.id == i.oyuncuId ? ' (sen)' : '')),
            subtitle: Text([
              if (o.host) 'Kurucu',
              if (!o.bagli) 'bağlantı yok',
            ].join(' · ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (o.hazir) Icon(Icons.check_circle_rounded, color: r.nane, semanticLabel: 'Hazır'),
                if (i.hostMu && !o.host)
                  PopupMenuButton<String>(
                    tooltip: '${o.takmaAd} için işlemler',
                    onSelected: (v) => i.gonder(v == 'kick' ? 'kick' : 'transferHost', {'playerId': o.id}),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'host', child: Text('Kurucu yap')),
                      PopupMenuItem(value: 'kick', child: Text('Odadan çıkar')),
                    ],
                  ),
              ],
            ),
          ),
        if (i.ekranSayisi > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Büyük ekran bağlı', style: TextStyle(color: r.metinIkincil)),
          ),
        const SizedBox(height: 16),
        if (i.rol == 'player' && ben != null)
          OutlinedButton(
            onPressed: () => i.gonder('ready', {'ready': !ben.hazir}),
            child: Text(ben.hazir ? 'Hazır değilim' : 'Hazırım'),
          ),
        if (i.hostMu) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _ayarlar(context, i),
            child: const Text('Oyun ayarları'),
          ),
          if (i.oyunId == '03') ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => rolPaketiAc(context, i, oyuncular.length),
              child: const Text('Rol paketi'),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: oyuncular.length >= min ? () => i.gonder('start') : null,
            child: Text(oyuncular.length >= min ? 'Başlat' : 'En az $min oyuncu gerek'),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Kurucunun başlatması bekleniyor…', textAlign: TextAlign.center, style: TextStyle(color: r.metinIkincil)),
          ),
      ],
    );
  }
}

/// Oyuna göre ayar seçenekleri: anahtar → (etiket, değerler, değer etiketi).
class _AyarTanimi {
  const _AyarTanimi(this.anahtar, this.etiket, this.degerler, this.gosterim);
  final String anahtar;
  final String etiket;
  final List<Object> degerler;
  final String Function(Object) gosterim;
}

String _ham(Object v) => '$v';

final _ayarlar07 = [
  const _AyarTanimi('soruSayisi', 'Soru sayısı', [10, 15, 20], _ham),
  const _AyarTanimi('oySuresi', 'Oy süresi (sn)', [10, 15, 20], _ham),
  _AyarTanimi('kendineOy', 'Kendine oy', const ['yasak', 'serbest'], (v) => v == 'yasak' ? 'Yasak' : 'Serbest'),
  _AyarTanimi('tahmin', 'Tahmin modu', const [false, true], (v) => v == true ? 'Açık' : 'Kapalı'),
  _AyarTanimi('seviye', 'Seviye', const ['gunluk', 'cesur', 'yilbasi'], (v) => switch (v) {
        'gunluk' => 'Günlük',
        'cesur' => 'Cesur',
        _ => 'Yılbaşı',
      }),
  _AyarTanimi('sonuc', 'Sonuç', const ['dagilim', 'kazanan'], (v) => v == 'dagilim' ? 'Dağılım' : 'Sadece kazanan'),
];

final _ayarlar01 = [
  const _AyarTanimi('kartSayisi', 'Kart sayısı', [1, 2, 3], _ham),
  _AyarTanimi('hiz', 'Çekim hızı', const [3, 5, 8, 0], (v) => v == 0 ? 'Elle' : '$v sn'),
  _AyarTanimi('otoIsaret', 'Otomatik işaretleme', const [true, false], (v) => v == true ? 'Açık' : 'Kapalı'),
  _AyarTanimi('ceza', 'Yanlış bildirim cezası', const [0, 3], (v) => v == 0 ? 'Yok' : '3 çekim'),
  _AyarTanimi('beraberlik', 'Beraberlik', const ['ikisi', 'paylas'], (v) => v == 'ikisi' ? 'İkisi de kazanır' : 'Paylaşılır'),
  _AyarTanimi('gecKatilim', 'Geç katılım', const [true, false], (v) => v == true ? 'Açık' : 'Kapalı'),
];

final _ayarlar03 = [
  const _AyarTanimi('geceSn', 'Gece süresi (sn)', [20, 25, 35], _ham),
  const _AyarTanimi('tartismaSn', 'Tartışma (sn)', [60, 90, 120, 180], _ham),
  _AyarTanimi('oylama', 'Oylama', const ['acik', 'gizli'], (v) => v == 'acik' ? 'Açık' : 'Gizli'),
  _AyarTanimi('rolAc', 'Ölenin rolü açılsın', const ['evet', 'hayir'], (v) => v == 'evet' ? 'Evet' : 'Hayır'),
  _AyarTanimi('esit', 'Eşit oyda', const ['kimse', 'yeniden'], (v) => v == 'kimse' ? 'Kimse asılmaz' : 'Yeniden oylama'),
  _AyarTanimi('doktorKendini', 'Doktor kendini korur', const ['evet', 'hayir'], (v) => v == 'evet' ? 'Evet' : 'Hayır'),
];

Future<void> _ayarlar(BuildContext context, OdaIstemcisi i) {
  final liste = switch (i.oyunId) {
    '07' => _ayarlar07,
    '01' => _ayarlar01,
    '03' => _ayarlar03,
    _ => <_AyarTanimi>[],
  };
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => ListenableBuilder(
      listenable: i,
      builder: (c, _) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            for (final a in liste)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.etiket, style: Theme.of(c).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final d in a.degerler)
                          ChoiceChip(
                            label: Text(a.gosterim(d)),
                            selected: i.ayarlar[a.anahtar] == d,
                            onSelected: (_) => i.gonder('setSettings', {a.anahtar: d}),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
