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
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'hy_mantik.dart';

const _dosya = '05-hic-yapmadim-ki';

final hicYapmadimKi = OyunUygulamasi(
  id: '05',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'mod',
      baslik: 'Mod',
      secenekler: {'parmak': 'Parmak', 'can': 'Can', 'isimli': 'İsimli sonuç'},
      varsayilan: 'parmak',
    ),
    AyarSatiri(
      anahtar: 'seviye',
      baslik: 'Seviye',
      secenekler: {
        'tatli': 'Tatlı',
        'komik': 'Komik',
        'kisisel': 'Biraz kişisel',
        'yilbasi': 'Yılbaşı',
      },
      varsayilan: 'tatli',
    ),
    AyarSatiri(
      anahtar: 'tur',
      baslik: 'Tur sayısı',
      secenekler: {'10': '10', '15': '15', '20': '20', '0': 'Sınırsız'},
      varsayilan: '20',
    ),
    AyarSatiri(
      anahtar: 'can',
      baslik: 'Can (yalnız Can modu)',
      secenekler: {'3': '3', '5': '5'},
      varsayilan: '5',
    ),
    AyarSatiri(
      anahtar: 'takas',
      baslik: 'Kart değiştirme hakkı',
      secenekler: {'0': '0', '1': '1', '2': '2', '3': '3'},
      varsayilan: '2',
    ),
    AyarSatiri(
      anahtar: 'sonuc',
      baslik: 'Sonuç gösterimi (Parmak)',
      secenekler: {'sayi': 'Sayı', 'yuzde': 'Yüzde'},
      varsayilan: 'sayi',
      gelismis: true,
    ),
    AyarSatiri(
      anahtar: 'sure',
      baslik: 'Cevap süresi',
      secenekler: {'8': 'Normal (8 sn)', '12': 'Rahat (12 sn)'},
      varsayilan: '8',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => HicYapmadimKiEkrani(oturum: oturum),
);

class HicYapmadimKiEkrani extends ConsumerStatefulWidget {
  const HicYapmadimKiEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<HicYapmadimKiEkrani> createState() => _HyDurum();
}

class _HyDurum extends ConsumerState<HicYapmadimKiEkrani> {
  final _sayac = SureSayaci();
  final _gecmis = GecmisDeposu();
  late HyOyunu _oyun;
  Deste<IcerikOgesi>? _deste;
  IcerikOgesi? _kart;
  String? _hata;
  String? _bilgi;
  bool _rizaAlindi = false;
  int _bildirilenYenilenme = 0;
  int _sayimSecimi = 0;

  OyunOturumu get _o => widget.oturum;
  int get _cevapMs => _o.ayarInt('sure') * 1000;

  @override
  void initState() {
    super.initState();
    _oyunuKur();
    _yukle();
  }

  void _oyunuKur() {
    final mod = switch (_o.ayar('mod')) {
      'can' => HyMod.can,
      'isimli' => HyMod.isimli,
      _ => HyMod.parmak,
    };
    _oyun = HyOyunu(
      oyuncular: _o.oyuncular,
      ayar: HyAyar(
        mod: mod,
        can: _o.ayarInt('can'),
        takasHakki: _o.ayarInt('takas'),
        turSayisi: _o.ayarInt('tur'),
      ),
    );
  }

  Future<void> _yukle() async {
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      final bildirilen = await _gecmis.bildirilenler('05');
      final gorulen = await _gecmis.gorulenler('05');
      final havuz = tum
          .where((o) =>
              o.seviye == _o.ayar('seviye') && !bildirilen.contains(o.id))
          .toList();
      if (havuz.isEmpty) {
        setState(() => _hata = 'Bu seviyede kart yok.');
        return;
      }
      _deste = Deste<IcerikOgesi>(havuz, idOf: (o) => o.id, gorulmus: gorulen);
      _kartBaslat();
    } catch (_) {
      if (mounted) setState(() => _hata = 'Kartlar yüklenemedi.');
    }
  }

  @override
  void dispose() {
    _sayac.dispose();
    super.dispose();
  }

  // --- Faz geçişleri ---

  void _kartBaslat({bool degistirme = false}) {
    final deste = _deste!;
    if (degistirme && _kart != null) deste.gorulmemisSay(_kart!);
    _kart = deste.cek();
    _kaydet();
    if (deste.yenilenme > _bildirilenYenilenme) {
      _bildirilenYenilenme = deste.yenilenme;
      _bilgi = ref.read(premiumProvider)
          ? 'Havuz yenilendi.'
          : 'Ücretsiz kartlar bitti. Premium\'da tam içerik var.';
    }
    HapticFeedback.lightImpact();
    _sayac.baslat(4000, bitince: _kartBitti);
    setState(() {});
  }

  void _kaydet() {
    final d = _deste;
    if (d != null) _gecmis.gorulenleriKaydet('05', d.gorulen);
  }

  void _kartBitti() {
    _oyun.kartOkundu();
    _sayac.baslat(_cevapMs, bitince: _cevapBitti);
    setState(() {});
  }

  void _cevapBitti() {
    _oyun.cevapBitti();
    if (_oyun.asama == HyAsama.sonuc) _sonucZamani();
    setState(() {});
  }

  void _sonucZamani() {
    HapticFeedback.mediumImpact();
    _sayac.baslat(5000, bitince: _sonucBitti);
  }

  void _sonucBitti() {
    _oyun.sonucGecildi();
    if (_oyun.asama == HyAsama.kart) {
      _kartBaslat();
    } else {
      _sayac.durdur();
      setState(() {});
    }
  }

  Future<void> _rizaIste() async {
    if (_rizaAlindi || _o.ayar('mod') == 'parmak') return;
    final onay = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Adlar herkese görünecek',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                  'Kimin yaptığı herkese görünür. Herkes kabul ediyor mu?'),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Hepimiz kabul ediyoruz')),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Vazgeç')),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (onay == true) {
      _rizaAlindi = true;
    } else {
      context.go('/oyun/${_o.oyun.id}/ayar');
    }
  }

  void _yenidenOyna() {
    _oyunuKur();
    _bildirilenYenilenme = _deste?.yenilenme ?? 0;
    _kartBaslat();
  }

  void _oyunuBitir() {
    _sayac.durdur();
    _oyun.bitir();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    if (_kart == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListenableBuilder(
      listenable: _sayac,
      builder: (context, _) {
        if (_oyun.asama == HyAsama.bitti) return _final();
        return switch (_oyun.asama) {
          HyAsama.sayim => _sayimEkrani(),
          HyAsama.sonuc || HyAsama.canGuncelle => _sonucEkrani(),
          _ => _kartEkrani(),
        };
      },
    );
  }

  // --- Ekranlar ---

  Widget _ustSatir() {
    final r = context.renkler;
    final tur = _o.ayarInt('tur');
    return Row(
      children: [
        Text(tur > 0 ? 'Tur ${_oyun.tur}/$tur' : 'Tur ${_oyun.tur}',
            style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (_oyun.asama == HyAsama.kart || _oyun.asama == HyAsama.cevap)
          _Halka(sayac: _sayac, renk: r.ana),
        PopupMenuButton<String>(
          tooltip: 'Seçenekler',
          onSelected: (v) {
            if (v == 'bitir') _oyunuBitir();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'bitir', child: Text('Oyunu bitir')),
          ],
        ),
      ],
    );
  }

  Widget _kartKutusu() {
    final r = context.renkler;
    return Semantics(
      label: 'Kart: ${_kart!.metin}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: r.yuzey,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: r.vurgu, width: 2),
        ),
        child: Text(
          _kart!.metin,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, height: 1.25),
        ),
      ),
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

  Widget _kartEkrani() {
    final cevap = _oyun.asama == HyAsama.cevap;
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ustSatir(),
          const SizedBox(height: 12),
          _kartKutusu(),
          _bilgiSatiri(),
          const SizedBox(height: 12),
          Text(
            cevap
                ? (_oyun.cipModu ? 'Yapanlar? Çipe dokun.' : 'Parmaklar inerken sayın.')
                : 'Okuyun',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: r.metinIkincil),
          ),
          const SizedBox(height: 12),
          if (_oyun.cipModu) Expanded(child: _cipIzgarasi(cevap)) else const Spacer(),
          if (!cevap)
            OutlinedButton(
              onPressed: _oyun.takasKalan > 0
                  ? () {
                      _oyun.kartDegistir();
                      _kartBaslat(degistirme: true);
                    }
                  : null,
              child: Text(_oyun.takasKalan > 0
                  ? 'Kartı değiştir (${_oyun.takasKalan})'
                  : 'Değiştirme hakkı bitti.'),
            ),
          if (cevap && !_oyun.cipModu)
            FilledButton(
              onPressed: () {
                _sayac.durdur();
                _cevapBitti();
              },
              child: const Text('Sayıma geç'),
            ),
          if (cevap && _oyun.cipModu)
            FilledButton(
              onPressed: () {
                _sayac.durdur();
                _cevapBitti();
              },
              child: const Text('Tamam'),
            ),
          TextButton.icon(
            onPressed: _bildir,
            icon: const Icon(Icons.flag_rounded),
            label: const Text('Bildir'),
          ),
        ],
      ),
    );
  }

  Future<void> _bildir() async {
    final k = _kart;
    if (k == null) return;
    await _gecmis.bildir('05', k.id);
    if (!mounted) return;
    setState(() => _bilgi = 'Bildirildi. Bu kart bir daha gelmez.');
    _kartBaslat();
  }

  Widget _cipIzgarasi(bool cevap) {
    final oyuncular = _oyun.oyuncular;
    return LayoutBuilder(builder: (context, c) {
      final sutun = oyuncular.length > 12 ? 4 : (c.maxWidth > 500 ? 4 : 3);
      return GridView.count(
        crossAxisCount: sutun,
        childAspectRatio: 1.7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [for (final o in oyuncular) _cip(o, cevap)],
      );
    });
  }

  Widget _cip(Oyuncu o, bool cevap) {
    final elendi = _oyun.elendi(o.id);
    final isaret = _oyun.isaretler[o.id] ?? HyIsaret.bos;
    final isaretMetin = switch (isaret) {
      HyIsaret.yaptim => 'yaptım',
      HyIsaret.pas => 'pas',
      HyIsaret.bos => 'boş',
    };
    final alt = _oyun.canModu
        ? (elendi ? 'Elendi' : 'Can: ${_oyun.can[o.id]}')
        : null;
    return OyuncuCipi(
      oyuncu: o,
      altYazi: alt,
      secili: isaret == HyIsaret.yaptim,
      pasif: elendi || !cevap,
      rozet: isaret == HyIsaret.yaptim
          ? const Icon(Icons.check_rounded)
          : (isaret == HyIsaret.pas ? const Icon(Icons.block_rounded) : null),
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _oyun.isaretDegistir(o.id));
      },
    ).semanticsEk('Durum: $isaretMetin. Değiştirmek için çift dokun');
  }

  Widget _sayimEkrani() {
    final n = _oyun.oyuncular.length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ustSatir(),
          const SizedBox(height: 12),
          Text('Kaç kişi yaptı?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var i = 0; i <= n; i++)
                  ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text('$i', textAlign: TextAlign.center),
                    ),
                    selected: _sayimSecimi == i,
                    onSelected: (_) => setState(() => _sayimSecimi = i),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              _oyun.sayimGir(_sayimSecimi.clamp(0, n));
              _sayimSecimi = 0;
              _sonucZamani();
              setState(() {});
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _sonucEkrani() {
    final s = _oyun.sonuc!;
    final r = context.renkler;
    final yuzdeGoster = _o.ayar('sonuc') == 'yuzde';
    String baslik = '${s.yapan} / ${s.toplam}';
    if (yuzdeGoster) baslik = '%${s.yuzde}';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ustSatir(),
          const Spacer(),
          Semantics(
            liveRegion: true,
            label: '${s.toplam} kişiden ${s.yapan}\'i yaptı',
            child: Column(
              children: [
                Text(baslik,
                    style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: r.ana)),
                Text('kişi yaptı (%${s.yuzde})',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < s.toplam; i++)
                      Icon(i < s.yapan ? Icons.circle : Icons.circle_outlined,
                          size: 20, color: r.ana),
                  ],
                ),
                if (s.herkesYapti)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Tam kadro!',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                if (s.kimseYapmadi)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Kusursuzlar!',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_oyun.ayar.mod != HyMod.parmak && s.yapanlar.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final o in s.yapanlar) Chip(label: Text(o.ad)),
              ],
            ),
          if (_oyun.canModu && s.yapanlar.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Yapanlar bir can kaybeder.',
                  textAlign: TextAlign.center),
            ),
          const Spacer(),
          OutlinedButton(
            onPressed: () {
              _sayac.durdur();
              _sonucBitti();
            },
            child: const Text('Sonraki'),
          ),
        ],
      ),
    );
  }

  Widget _final() {
    final r = context.renkler;
    final can = _oyun.canModu;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.emoji_events_rounded, size: 96, color: r.vurgu),
          const SizedBox(height: 16),
          Text(
            can
                ? (_oyun.kazananlar.length == 1 ? 'Son kalan!' : 'Ortak kazananlar!')
                : 'Oyun bitti',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          if (can)
            Text(_oyun.kazananlar.map((o) => o.ad).join(', '),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge)
          else
            Text('${_oyun.turlar.length} tur oynandı.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          FilledButton(
              onPressed: _yenidenOyna, child: const Text('Tekrar oyna')),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_o.ayar('mod') != 'parmak' && !_rizaAlindi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_rizaAlindi) _rizaIste();
      });
    }
  }
}

extension on Widget {
  Widget semanticsEk(String ek) => Semantics(hint: ek, child: this);
}

class _Halka extends StatelessWidget {
  const _Halka({required this.sayac, required this.renk});
  final SureSayaci sayac;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: sayac.oran,
            strokeWidth: 6,
            color: sayac.kalanSn <= 3 ? context.renkler.tehlike : renk,
            backgroundColor: context.renkler.yukseltilmis,
          ),
          Text('${sayac.kalanSn}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }
}
