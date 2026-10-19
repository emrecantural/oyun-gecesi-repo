import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../content/icerik.dart';
import '../../content/icerik_deposu.dart';
import '../../shell/ortak/gizli_bilgi.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'hediye_mantik.dart';

const _dosya = '24-gizli-hediye-cekilisi';

final gizliHediye = OyunUygulamasi(
  id: '24',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'butce',
      baslik: 'Bütçe',
      secenekler: {'yok': 'Yok', 'aralik': 'Aralık belirle'},
      varsayilan: 'yok',
    ),
    AyarSatiri(
      anahtar: 'istek',
      baslik: 'İstek listesi',
      secenekler: {'evet': 'Açık', 'hayir': 'Kapalı'},
      varsayilan: 'evet',
    ),
  ],
  ekran: (context, oturum) => GizliHediyeEkrani(oturum: oturum),
);

enum _Asama { kur, istek, dagit, gecis, sonuc, bitti }

class GizliHediyeEkrani extends ConsumerStatefulWidget {
  const GizliHediyeEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<GizliHediyeEkrani> createState() => _HediyeDurum();
}

class _HediyeDurum extends ConsumerState<GizliHediyeEkrani> {
  late final HediyeCekilisi _cekilis;
  _Asama _asama = _Asama.kur;
  int? _aktifId;
  int? _gosterilenAlici;
  final Map<int, Set<String>> _istekler = {};
  final List<int> _istekSirasi = [];
  List<IcerikOgesi> _fikirler = const [];
  List<IcerikOgesi> _butceOnerileri = const [];
  bool _cekiliyor = false;
  String? _hata;
  final _min = TextEditingController();
  final _max = TextEditingController();

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _oyuncular => _o.oyuncular;
  Oyuncu _oyuncu(int id) => _oyuncular.firstWhere((o) => o.id == id);
  bool get _butceAralik => _o.ayar('butce') == 'aralik';
  bool get _istekAcik => _o.ayar('istek') == 'evet';

  @override
  void initState() {
    super.initState();
    _cekilis = HediyeCekilisi();
    for (final o in _oyuncular) {
      _cekilis.katilimciEkle(o.id);
    }
    _icerikYukle();
  }

  Future<void> _icerikYukle() async {
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      if (!mounted) return;
      setState(() {
        _fikirler = tum.where((o) => o.tur == 'fikir').toList();
        _butceOnerileri = tum.where((o) => o.tur == 'butce').toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  String? get _butceMetni {
    if (!_butceAralik) return null;
    final a = int.tryParse(_min.text);
    final b = int.tryParse(_max.text);
    if (a == null || b == null) return null;
    return '₺$a–$b';
  }

  bool get _butceGecerli {
    if (!_butceAralik) return true;
    final a = int.tryParse(_min.text);
    final b = int.tryParse(_max.text);
    return a != null && b != null && a <= b;
  }

  // --- Akış ---

  Future<void> _cekiliseGec() async {
    if (_istekAcik) {
      _istekSirasi
        ..clear()
        ..addAll(_oyuncular.map((o) => o.id));
      _aktifId = _istekSirasi.first;
      setState(() => _asama = _Asama.istek);
    } else {
      await _onayIste();
    }
  }

  Future<void> _onayIste() async {
    final onay = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${_oyuncular.length} kişi · ${_cekilis.haricCiftler.length} çift ayrılacak',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                  'Çekilişten sonra eşleşmeler görüntülenir görüntülenmez geri alınamaz.'),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Çek')),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Vazgeç')),
            ],
          ),
        ),
      ),
    );
    if (onay != true || !mounted) return;
    setState(() {
      _cekiliyor = true;
      _hata = null;
    });
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    try {
      _cekilis.cek();
      setState(() {
        _cekiliyor = false;
        _asama = _Asama.dagit;
      });
    } on HediyeHata catch (e) {
      setState(() {
        _cekiliyor = false;
        _hata = e.kod == 'E_UNSOLVABLE'
            ? (_oyuncular.length == 3
                ? 'Bu kurallarla çekiliş yapılamıyor. 3 kişide bir çift bile ayrılamaz.'
                : 'Bu kurallarla çekiliş yapılamıyor. Hariç tutmayı düzenle.')
            : 'Çekiliş yapılamadı.';
      });
    }
  }

  void _istekBitti() {
    final i = _istekSirasi.indexOf(_aktifId!);
    if (i + 1 < _istekSirasi.length) {
      setState(() {
        _aktifId = _istekSirasi[i + 1];
        _asama = _Asama.istek;
        _istekGecisAktif = false;
      });
    } else {
      _aktifId = null;
      _istekGecisAktif = false;
      _onayIste();
      setState(() => _asama = _Asama.kur);
    }
  }

  bool _istekGecisAktif = false;

  Future<void> _haricDuzenle() async {
    int? a;
    int? b;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final ciftler = _cekilis.haricCiftler;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Kimler eşleşmesin?',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _kisiSecici(ctx, a, (v) => set(() => a = v))),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('ile')),
                  Expanded(child: _kisiSecici(ctx, b, (v) => set(() => b = v))),
                ]),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    if (a == null || b == null) return;
                    if (a == b) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Aynı kişiyi seçemezsin.')));
                      return;
                    }
                    final varMi = ciftler.any((c) =>
                        (c.$1 == a && c.$2 == b) || (c.$1 == b && c.$2 == a));
                    if (varMi) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Bu çift zaten ekli.')));
                      return;
                    }
                    set(() => _cekilis.haricEkle(a!, b!));
                    setState(() {});
                  },
                  child: const Text('Çifti ekle'),
                ),
                for (final c in _cekilis.haricCiftler)
                  ListTile(
                    title: Text('${_oyuncu(c.$1).ad} ⇄ ${_oyuncu(c.$2).ad}'),
                    trailing: IconButton(
                      tooltip: 'Çifti kaldır',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        set(() => _cekilis.haricKaldir(c.$1, c.$2));
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _kisiSecici(BuildContext ctx, int? deger, ValueChanged<int?> degisti) {
    return DropdownButton<int>(
      isExpanded: true,
      hint: const Text('Kişi'),
      value: deger,
      items: [
        for (final o in _oyuncular)
          DropdownMenuItem(value: o.id, child: Text(o.kisaAd)),
      ],
      onChanged: degisti,
    );
  }

  Future<void> _bitirVeSil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bitir ve sil'),
        content: const Text('Eşleşmeler silinir. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true) return;
    _cekilis.sil();
    if (mounted) setState(() => _asama = _Asama.bitti);
  }

  // --- Ekranlar ---

  @override
  Widget build(BuildContext context) {
    switch (_asama) {
      case _Asama.kur:
        return _kurEkrani();
      case _Asama.istek:
        return _istekGecisAktif ? _istekSecimi() : GecisEkrani(
              oyuncu: _oyuncu(_aktifId!),
              onHazir: () => setState(() => _istekGecisAktif = true),
              ipucu: 'İstek listeni yazacaksın. Hazır olunca dokun.',
            );
      case _Asama.dagit:
        return _dagitEkrani();
      case _Asama.gecis:
        return GecisEkrani(
          oyuncu: _oyuncu(_aktifId!),
          onHazir: () => setState(() => _asama = _Asama.sonuc),
          onGeri: () => setState(() {
            _aktifId = null;
            _asama = _Asama.dagit;
          }),
        );
      case _Asama.sonuc:
        return _sonucEkrani();
      case _Asama.bitti:
        return _bittiEkrani();
    }
  }

  Widget _kurEkrani() {
    final r = context.renkler;
    if (_cekiliyor) {
      return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Zarflar karışıyor…'),
      ]));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Herkes bir kişiye hediye alır. Kime aldığını yalnız sen bilirsin.',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Text('${_oyuncular.length} kişi · 3–50'),
        const SizedBox(height: 16),
        if (_butceAralik) ...[
          Text('Bütçe (₺)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _min,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'En az'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'En çok'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          if (!_butceGecerli && (_min.text.isNotEmpty || _max.text.isNotEmpty))
            Text('En az, en çoktan büyük olamaz.',
                style: TextStyle(color: r.tehlike)),
          const SizedBox(height: 8),
          for (final b in _butceOnerileri)
            Text('• ${b.metin}', style: TextStyle(color: r.metinIkincil)),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: _haricDuzenle,
          icon: const Icon(Icons.link_off_rounded),
          label: Text('Çiftleri ayır (${_cekilis.haricCiftler.length})'),
        ),
        if (_hata != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_hata!, style: TextStyle(color: r.tehlike)),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _butceGecerli ? _cekiliseGec : null,
          child: const Text('Çekilişe geç'),
        ),
      ],
    );
  }

  Widget _istekSecimi() {
    final id = _aktifId!;
    final secili = _istekler.putIfAbsent(id, () => <String>{});
    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${_oyuncu(id).ad}, istediklerini seç',
                style: Theme.of(context).textTheme.titleLarge),
            const Text('En çok 3 tane.'),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in _fikirler)
                      FilterChip(
                        label: Text(f.metin),
                        selected: secili.contains(f.metin),
                        onSelected: (v) => setState(() {
                          if (v && secili.length < 3) secili.add(f.metin);
                          if (!v) secili.remove(f.metin);
                        }),
                      ),
                  ],
                ),
              ),
            ),
            FilledButton(onPressed: _istekBitti, child: const Text('Tamam')),
            TextButton(
              onPressed: () {
                secili.clear();
                _istekBitti();
              },
              child: const Text('Atla'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dagitEkrani() {
    final r = context.renkler;
    final bakan = _cekilis.bakanSayisi;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Çekiliş yapıldı. Adına dokun, telefonu ver.',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final o in _oyuncular)
                  Card(
                    child: ListTile(
                      minTileHeight: 64,
                      leading: OyuncuSimgesi(oyuncu: o, boyut: 40),
                      title: Text(o.ad,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: Text(
                        (_cekilis.goruntulenme[o.id] ?? 0) > 0
                            ? '✓ baktı (${_cekilis.goruntulenme[o.id]} kez)'
                            : 'bekliyor',
                        style: TextStyle(color: r.metinIkincil),
                      ),
                      onTap: () => setState(() {
                        _aktifId = o.id;
                        _asama = _Asama.gecis;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Text('Baktı: $bakan / ${_oyuncular.length}',
              textAlign: TextAlign.center),
          if (_cekilis.herkesBakti)
            const Text('Herkes baktı.', textAlign: TextAlign.center),
          if (!_cekilis.kilitli)
            TextButton(
              onPressed: () => setState(() {
                _cekilis.iptal();
                _asama = _Asama.kur;
              }),
              child: const Text('Çekilişi iptal et'),
            ),
          FilledButton(
              onPressed: _bitirVeSil, child: const Text('Bitir ve sil')),
        ],
      ),
    );
  }

  Widget _sonucEkrani() {
    final id = _aktifId!;
    final o = _oyuncu(id);
    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${o.ad}, parmağını kaldırma',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            BasiliTutKart(
              kapaliEtiket: 'Eşleşmen',
              minBasmaMs: 400,
              azamiAcikSn: 20,
              acildi: () => _gosterilenAlici = _cekilis.goster(id),
              acik: (ctx) {
                final alici = _gosterilenAlici == null
                    ? null
                    : _oyuncu(_gosterilenAlici!);
                final istek = alici == null
                    ? const <String>{}
                    : (_istekler[alici.id] ?? const <String>{});
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Hediye alacağın kişi:'),
                    const SizedBox(height: 8),
                    Text(alici?.ad.toUpperCase() ?? '',
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.w900)),
                    if (istek.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('İstekleri: ${istek.join(', ')}'),
                    ],
                    if (_butceMetni != null) ...[
                      const SizedBox(height: 8),
                      Text('Bütçe: $_butceMetni'),
                    ],
                  ],
                );
              },
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => setState(() {
                _gosterilenAlici = null;
                _aktifId = null;
                _asama = _Asama.dagit;
              }),
              child: const Text('Listeye dön'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bittiEkrani() {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.card_giftcard_rounded, size: 96, color: r.vurgu),
          const SizedBox(height: 16),
          Text('Çekiliş silindi. Hediyeleri unutma!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
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
