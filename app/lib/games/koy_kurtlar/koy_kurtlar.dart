import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../content/icerik_deposu.dart';
import '../../core/sure_sayaci.dart';
import '../../core/tr_text.dart';
import '../../shell/ortak/gizli_bilgi.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'koy_mantik.dart';
import '../../platform/titresim.dart';

const _dosya = '03-koy-ve-kurtlar';

final koyKurtlar = OyunUygulamasi(
  id: '03',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'tartisma',
      baslik: 'Tartışma süresi',
      secenekler: {'60': '60 sn', '90': '90 sn', '120': '120 sn', '180': '180 sn'},
      varsayilan: '90',
    ),
    AyarSatiri(
      anahtar: 'oylama',
      baslik: 'Oylama',
      secenekler: {'acik': 'Açık', 'gizli': 'Gizli'},
      varsayilan: 'acik',
    ),
    AyarSatiri(
      anahtar: 'rolac',
      baslik: 'Ölünce rolü aç',
      secenekler: {'evet': 'Evet', 'hayir': 'Hayır'},
      varsayilan: 'evet',
    ),
    AyarSatiri(
      anahtar: 'esit',
      baslik: 'Eşit oy',
      secenekler: {'kimse': 'Kimse elenmez', 'yeniden': 'Yeniden oy'},
      varsayilan: 'kimse',
    ),
    AyarSatiri(
      anahtar: 'doktor',
      baslik: 'Doktor kendini korur',
      secenekler: {'evet': 'Evet', 'hayir': 'Hayır'},
      varsayilan: 'evet',
      gelismis: true,
    ),
    AyarSatiri(
      anahtar: 'gece',
      baslik: 'Kişi başı gece süresi',
      secenekler: {'12': '12 sn', '18': '18 sn'},
      varsayilan: '12',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => KoyKurtlarEkrani(oturum: oturum),
);

enum _Asama {
  yukleniyor,
  rolGecis,
  rolKart,
  geceDuyuru,
  geceGecis,
  gecePanel,
  cadiGecis,
  cadiPanel,
  sabah,
  avciGecis,
  avciPanel,
  tartisma,
  oyGecis,
  oyPanel,
  oySonuc,
  final_,
}

const _rolKartYedek = {
  Rol.kurt: 'Kurtsun. Her gece diğer kurtlarla birlikte bir köylüyü seç.',
  Rol.kahin: 'Kâhinsin. Her gece bir kişinin kurt olup olmadığını öğrenirsin.',
  Rol.doktor: 'Doktorsun. Her gece bir kişiyi korursun.',
  Rol.cadi: 'Cadısın. Bir iyileştirme ve bir zehir hakkın var.',
  Rol.avci: 'Avcısın. Elenirsen hemen birini vurursun.',
  Rol.asik: 'Âşıksın. Eşin ölürse sen de ölürsün.',
  Rol.koylu: 'Köylüsün. Kurtları bul.',
};

class KoyKurtlarEkrani extends ConsumerStatefulWidget {
  const KoyKurtlarEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<KoyKurtlarEkrani> createState() => _KoyDurum();
}

class _KoyDurum extends ConsumerState<KoyKurtlarEkrani> {
  final _sayac = SureSayaci();
  final _rng = Random();
  late KoyOyunu _oyun;
  _Asama _asama = _Asama.yukleniyor;
  String? _hata;

  Map<String, String> _rolMetni = {};
  List<String> _bekleme = const ['Gece sessiz…'];
  List<String> _sabahOlum = const [];
  List<String> _sabahSessiz = const [];

  // sıralı dolaşım
  List<int> _sira = const [];
  int _i = 0;
  int? _secim;
  bool _onayli = false;
  String? _panelMesaj;
  bool _cadiZehirModu = false;

  // sabah
  List<String> _sabahSatirlari = const [];
  int? _avciId;
  bool _sonrasiOylama = false; // avcı sonrası akış hangi faza döner
  List<int> _oyAdaylari = const [];
  String _oySonucMetni = '';
  bool _yeniden = false;
  bool _yenidenYapildi = false;
  Timer? _zaman;
  int _tartKalan = 0;

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _p => _o.oyuncular;
  Oyuncu _oyuncu(int id) => _p.firstWhere((p) => p.id == id);
  int get _geceSn => _o.ayarInt('gece');

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
    _zaman?.cancel();
    _sayac.removeListener(_yenile);
    _sayac.dispose();
    super.dispose();
  }

  Future<void> _kur() async {
    final n = _p.length;
    if (n < 6 || n > 12) {
      setState(() => _hata = 'Tek cihazda 6–12 oyuncu gerekir.');
      return;
    }
    _oyun = KoyOyunu(
      oyuncuIdleri: [for (final p in _p) p.id],
      ayar: KoyAyarlar(
        acikOylama: _o.ayar('oylama') == 'acik',
        oluncRoluAc: _o.ayar('rolac') == 'evet',
        esitOyYenidenOy: _o.ayar('esit') == 'yeniden',
        doktorKendiniKorur: _o.ayar('doktor') == 'evet',
      ),
    );
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      _rolMetni = {
        for (final k in tum)
          if (k.tur == 'rolkarti') k.seviye: k.metin
      };
      final b = [for (final k in tum) if (k.tur == 'bekleme') k.metin];
      if (b.isNotEmpty) _bekleme = b;
      _sabahOlum = [for (final k in tum) if (k.tur == 'sabah_olum') k.metin];
      _sabahSessiz = [for (final k in tum) if (k.tur == 'sabah_sessiz') k.metin];
    } catch (_) {}
    _sira = [for (final p in _p) p.id];
    _i = 0;
    if (mounted) setState(() => _asama = _Asama.rolGecis);
  }

  // ---------- yardımcılar ----------
  String _rolYazi(Rol r) {
    const anahtar = {
      Rol.kurt: 'kurt',
      Rol.kahin: 'kahin',
      Rol.doktor: 'doktor',
      Rol.cadi: 'cadi',
      Rol.avci: 'avci',
      Rol.asik: 'asik',
      Rol.koylu: 'koylu',
    };
    return _rolMetni[anahtar[r]] ?? _rolKartYedek[r]!;
  }

  String _beklemeMetni() => _bekleme[_rng.nextInt(_bekleme.length)];

  void _panelBaslat(VoidCallback bitince, {int? sn}) {
    _secim = null;
    _onayli = false;
    _panelMesaj = null;
    _sayac.baslat((sn ?? _geceSn) * 1000, bitince: bitince);
  }

  // ---------- 1) rol dağıtımı ----------
  void _rolKartGor() => setState(() => _asama = _Asama.rolKart);

  void _rolGordum() {
    if (_i + 1 < _sira.length) {
      _i++;
      setState(() => _asama = _Asama.rolGecis);
    } else {
      _geceyeGec();
    }
  }

  // ---------- 2) gece ----------
  void _geceyeGec() {
    _oyun.geceBasla();
    _sira = _oyun.canlilar;
    _i = 0;
    setState(() => _asama = _Asama.geceDuyuru);
    _zaman?.cancel();
    _zaman = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _asama = _Asama.geceGecis);
    });
  }

  void _gecePanelAc() {
    _panelBaslat(_geceKisiBitti);
    setState(() => _asama = _Asama.gecePanel);
  }

  void _geceKisiBitti() {
    _sayac.durdur();
    if (_i + 1 < _sira.length) {
      _i++;
      setState(() => _asama = _Asama.geceGecis);
      return;
    }
    // A turu bitti
    final cadi = _oyun.canlilar.where((id) => _oyun.roller[id] == Rol.cadi);
    if (cadi.isNotEmpty) {
      _sira = _oyun.canlilar;
      _i = 0;
      setState(() => _asama = _Asama.cadiGecis);
    } else {
      _sabahaCik();
    }
  }

  void _gecenOnayla() {
    final id = _sira[_i];
    final rol = _oyun.roller[id]!;
    final s = _secim;
    if (s == null || _onayli) return;
    try {
      switch (rol) {
        case Rol.kahin:
          final kurt = _oyun.kahinSorgula(id, s);
          _panelMesaj = kurt
              ? '${_oyuncu(s).ad}: KURT 🐺'
              : '${_oyuncu(s).ad}: kurt değil ✓';
        case Rol.kurt:
          _oyun.kurtOyu(id, s);
          _panelMesaj = 'Seçimin alındı.';
        case Rol.doktor:
          _oyun.koru(id, s);
          _panelMesaj = 'Seçimin alındı.';
        default:
          _panelMesaj = 'Seçimin alındı.'; // sahte: kaydedilmez
      }
      _onayli = true;
    } on KoyHatasi catch (e) {
      _panelMesaj = switch (e.kod) {
        'DOCTOR_REPEAT' => 'Aynı kişiyi art arda koruyamazsın.',
        'DOCTOR_SELF_OFF' => 'Kendini koruyamazsın.',
        'INVALID_TARGET' => 'Bu kişiyi seçemezsin.',
        _ => 'Bu seçim olmaz.',
      };
    }
    Titresim.hafif();
    setState(() {});
  }

  Widget _hedefIzgara(int id, Rol rol, {List<int>? izinli}) {
    final r = context.renkler;
    final kurtOylari = rol == Rol.kurt ? _oyun.kurtOylari : const <int, int>{};
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in _p)
          Builder(builder: (_) {
            final olu = !_oyun.canli(p.id);
            final secilebilir = !olu && (izinli == null || izinli.contains(p.id));
            final isaret = kurtOylari.entries.where((e) => e.value == p.id).length;
            return ChoiceChip(
              avatar: OyuncuSimgesi(oyuncu: p, boyut: 22),
              label: Text('${p.ad}${olu ? ' ✕' : ''}${isaret > 0 ? ' ${'🐺' * isaret}' : ''}'),
              selected: _secim == p.id,
              onSelected: !secilebilir || _onayli ? null : (_) => setState(() => _secim = p.id),
              selectedColor: r.ana.withValues(alpha: 0.35),
            );
          }),
      ],
    );
  }

  Widget _geceGovde() {
    final id = _sira[_i];
    final rol = _oyun.roller[id]!;
    final r = context.renkler;
    final eylemli = rol == Rol.kahin || rol == Rol.kurt || rol == Rol.doktor;
    final baslik = switch (rol) {
      Rol.kahin => 'Kimi sorgulayacaksın?',
      Rol.kurt => 'Bu gece kimi avlayalım?',
      Rol.doktor => 'Kimi koruyacaksın?',
      _ => 'Gece sessiz…',
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Gece ${_oyun.gece} · ${_oyuncu(id).ad} · ${_sayac.kalanSn} sn',
              style: TextStyle(color: r.metinIkincil)),
          LinearProgressIndicator(value: _sayac.oran),
          const SizedBox(height: 12),
          Text(baslik, style: Theme.of(context).textTheme.titleLarge),
          if (!eylemli) Text(_beklemeMetni(), style: TextStyle(color: r.metinIkincil)),
          const SizedBox(height: 12),
          _hedefIzgara(id, rol),
          const SizedBox(height: 12),
          if (_panelMesaj != null)
            Text(_panelMesaj!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton(
            onPressed: _secim == null || _onayli ? null : _gecenOnayla,
            child: const Text('Onayla'),
          ),
          const SizedBox(height: 8),
          Text('Süre dolunca telefon bir sonraki oyuncuya geçer.',
              textAlign: TextAlign.center, style: TextStyle(color: r.metinIkincil)),
        ],
      ),
    );
  }

  // ---------- Cadı B turu ----------
  void _cadiPanelAc() {
    _cadiZehirModu = false;
    _panelBaslat(_cadiKisiBitti);
    setState(() => _asama = _Asama.cadiPanel);
  }

  void _cadiKisiBitti() {
    _sayac.durdur();
    if (_i + 1 < _sira.length) {
      _i++;
      setState(() => _asama = _Asama.cadiGecis);
    } else {
      _sabahaCik();
    }
  }

  Widget _cadiGovde() {
    final id = _sira[_i];
    final rol = _oyun.roller[id]!;
    final r = context.renkler;
    final kurban = _oyun.kurbanHedefi;
    final cadi = rol == Rol.cadi;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Gece ${_oyun.gece} · ${_oyuncu(id).ad} · ${_sayac.kalanSn} sn',
              style: TextStyle(color: r.metinIkincil)),
          LinearProgressIndicator(value: _sayac.oran),
          const SizedBox(height: 12),
          if (!cadi) ...[
            Text('Gece sessiz…', style: Theme.of(context).textTheme.titleLarge),
            Text(_beklemeMetni(), style: TextStyle(color: r.metinIkincil)),
          ] else ...[
            Text(
                kurban == null
                    ? 'Bu gece kurtlar kimseyi seçmedi.'
                    : 'Kurtlar ${_oyuncu(kurban).ad} adlı kişiyi seçti.',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_cadiZehirModu) ...[
              const Text('Kimi zehirleyeceksin?'),
              const SizedBox(height: 8),
              _hedefIzgara(id, rol, izinli: _oyun.canlilar.where((x) => x != id).toList()),
            ],
            if (_panelMesaj != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_panelMesaj!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            const Spacer(),
            if (!_onayli && !_cadiZehirModu) ...[
              FilledButton(
                onPressed: _oyun.iyilestirmeVar && kurban != null
                    ? () {
                        _oyun.cadiIyilestir(id);
                        setState(() {
                          _onayli = true;
                          _panelMesaj = 'İyileştirdin.';
                        });
                      }
                    : null,
                child: const Text('İyileştir'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _oyun.zehirVar ? () => setState(() => _cadiZehirModu = true) : null,
                child: const Text('Zehirle'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => setState(() {
                  _onayli = true;
                  _panelMesaj = 'Pas geçtin.';
                }),
                child: const Text('Pas'),
              ),
            ] else if (_cadiZehirModu && !_onayli)
              FilledButton(
                onPressed: _secim == null ? null : _zehirOnay,
                child: const Text('Zehirle'),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _zehirOnay() async {
    final id = _sira[_i];
    final hedef = _secim;
    if (hedef == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${_oyuncu(hedef).ad} zehirlensin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Zehirle')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      _oyun.cadiZehirle(id, hedef);
      setState(() {
        _onayli = true;
        _cadiZehirModu = false;
        _panelMesaj = 'Zehirledin.';
      });
    } on KoyHatasi {
      setState(() => _panelMesaj = 'Bu seçim olmaz.');
    }
  }

  // ---------- 3) sabah ----------
  String _sablon(List<String> liste, String ad) {
    if (liste.isEmpty) return '';
    return liste[_rng.nextInt(liste.length)].replaceAll('{ad}', ad);
  }

  void _sabahaCik() {
    final s = _oyun.geceyiCoz();
    final satirlar = <String>[];
    if (s.olumler.isEmpty) {
      final t = _sablon(_sabahSessiz, '');
      satirlar.add(t.isEmpty ? 'Kimse ölmedi.' : t);
    } else {
      for (final o in s.olumler) {
        final ad = _oyuncu(o.id).ad;
        var t = o.neden == OlumNedeni.askZinciri
            ? '$ad, eşinin ardından öldü.'
            : _sablon(_sabahOlum, ad);
        if (t.isEmpty) t = '$ad gece öldü.';
        if (_oyun.ayar.oluncRoluAc) t += ' (${rolAdi[_oyun.roller[o.id]]})';
        satirlar.add(t);
      }
    }
    _sabahSatirlari = satirlar;
    _avciId = s.avciBekliyor;
    _sonrasiOylama = false;
    _yenidenYapildi = false;
    Titresim.orta();
    setState(() => _asama = _Asama.sabah);
  }

  void _sabahDevam() {
    final av = _avciId;
    if (av != null) {
      setState(() => _asama = _Asama.avciGecis);
      return;
    }
    _kazanmaKontrolu(sonra: _sonrasiOylama ? _geceyeGec : _tartismayaGec);
  }

  void _kazanmaKontrolu({required VoidCallback sonra}) {
    if (_oyun.kazanan() != null) {
      setState(() => _asama = _Asama.final_);
    } else {
      sonra();
    }
  }

  // ---------- avcı ----------
  void _avciAc() {
    _panelBaslat(() => _avciVur(null), sn: 15);
    setState(() => _asama = _Asama.avciPanel);
  }

  void _avciVur(int? hedef) {
    _sayac.durdur();
    final av = _avciId!;
    final olumler = _oyun.avciVur(av, hedef);
    final satirlar = [
      for (final o in olumler)
        '${_oyuncu(o.id).ad} vuruldu${o.neden == OlumNedeni.askZinciri ? ' (eşinin ardından)' : ''}.'
            '${_oyun.ayar.oluncRoluAc ? ' (${rolAdi[_oyun.roller[o.id]]})' : ''}',
    ];
    _avciId = null;
    _sabahSatirlari = satirlar.isEmpty ? ['Avcı kimseyi vurmadı.'] : satirlar;
    setState(() => _asama = _Asama.sabah);
  }

  // ---------- 4) tartışma / oylama ----------
  void _tartismayaGec() {
    _tartKalan = _o.ayarInt('tartisma');
    _zaman?.cancel();
    _zaman = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_tartKalan <= 1) {
        t.cancel();
        _oylamayaGec();
      } else {
        setState(() => _tartKalan--);
      }
    });
    setState(() => _asama = _Asama.tartisma);
  }

  void _oylamayaGec({List<int>? adaylar}) {
    _zaman?.cancel();
    _oyAdaylari = adaylar ?? _oyun.canlilar;
    _oyun.oyBaslat();
    _sira = _oyun.canlilar;
    _i = 0;
    setState(() => _asama = _Asama.oyGecis);
  }

  void _oyPanelAc() {
    _panelBaslat(_oyKisiBitti, sn: 8);
    setState(() => _asama = _Asama.oyPanel);
  }

  void _oyKisiBitti() {
    _sayac.durdur();
    final voter = _sira[_i];
    try {
      _oyun.oyVer(voter, _secim);
    } on KoyHatasi {
      // geçersiz seçim: oy yok
    }
    if (_i + 1 < _sira.length) {
      _i++;
      setState(() => _asama = _Asama.oyGecis);
    } else {
      _oylamaSonuc();
    }
  }

  void _oylamaSonuc() {
    final sayim = _oyun.oySayilari();
    final r = _oyun.oylamayiBitir();
    final b = StringBuffer();
    if (_o.ayar('oylama') == 'acik') {
      for (final e in _oyun.oylar.entries) {
        b.writeln('${_oyuncu(e.key).ad} → ${e.value == null ? 'boş' : _oyuncu(e.value!).ad}');
      }
    } else {
      for (final e in sayim.entries) {
        b.writeln('${_oyuncu(e.key).ad}: ${e.value} oy');
      }
    }
    if (r.olumler.isNotEmpty) {
      for (final o in r.olumler) {
        b.writeln(
            '${_oyuncu(o.id).ad} elendi.${_oyun.ayar.oluncRoluAc ? ' (${rolAdi[_oyun.roller[o.id]]})' : ''}');
      }
      _avciId = r.avci;
    } else if (r.esitAdaylar.isNotEmpty && _oyun.ayar.esitOyYenidenOy && !_yenidenYapildi) {
      _yeniden = true;
      b.writeln('Oylar eşit; yalnız eşit adaylar için yeniden oy.');
      _oyAdaylari = r.esitAdaylar;
    } else {
      b.writeln(sayim.isEmpty ? 'Oy verilmedi; kimse elenmedi.' : 'Oylar eşit; kimse elenmedi.');
    }
    if (r.olumler.isNotEmpty) _yeniden = false;
    _oySonucMetni = b.toString();
    _sonrasiOylama = true;
    setState(() => _asama = _Asama.oySonuc);
  }

  void _oySonucDevam() {
    if (_yeniden) {
      _yeniden = false;
      _yenidenYapildi = true;
      _oylamayaGec(adaylar: _oyAdaylari);
      return;
    }
    _yenidenYapildi = false;
    if (_avciId != null) {
      setState(() => _asama = _Asama.avciGecis);
      return;
    }
    _kazanmaKontrolu(sonra: _geceyeGec);
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    final govde = switch (_asama) {
      _Asama.yukleniyor => const Center(child: CircularProgressIndicator()),
      _Asama.rolGecis => GecisEkrani(
          key: ValueKey('rg$_i'),
          oyuncu: _oyuncu(_sira[_i]),
          ipucu: 'Rolünü gör: basılı tut.',
          onHazir: _rolKartGor,
        ),
      _Asama.rolKart => _rolKart(),
      _Asama.geceDuyuru => const Center(
          child: Text('Gece oldu. Köy uyuyor.',
              style: TextStyle(fontSize: 26), textAlign: TextAlign.center)),
      _Asama.geceGecis => GecisEkrani(
          key: ValueKey('gg${_oyun.gece}-$_i'),
          oyuncu: _oyuncu(_sira[_i]),
          ipucu: 'Gece ${_oyun.gece}. Sıra sende.',
          onHazir: _gecePanelAc,
        ),
      _Asama.gecePanel => GizliEkran(child: _geceGovde()),
      _Asama.cadiGecis => GecisEkrani(
          key: ValueKey('cg${_oyun.gece}-$_i'),
          oyuncu: _oyuncu(_sira[_i]),
          ipucu: 'Gece ${_oyun.gece}, ikinci tur.',
          onHazir: _cadiPanelAc,
        ),
      _Asama.cadiPanel => GizliEkran(child: _cadiGovde()),
      _Asama.sabah => _sabah(),
      _Asama.avciGecis => GecisEkrani(
          oyuncu: _oyuncu(_avciId!),
          ipucu: 'Son atış sende!',
          onHazir: _avciAc,
        ),
      _Asama.avciPanel => GizliEkran(child: _avciGovde()),
      _Asama.tartisma => _tartisma(),
      _Asama.oyGecis => GecisEkrani(
          key: ValueKey('og${_oyun.gece}-$_i-$_yenidenYapildi'),
          oyuncu: _oyuncu(_sira[_i]),
          ipucu: 'Oy sırası sende.',
          onHazir: _oyPanelAc,
        ),
      _Asama.oyPanel => GizliEkran(child: _oyGovde()),
      _Asama.oySonuc => _oySonuc(),
      _Asama.final_ => _final(),
    };
    return Container(color: context.renkler.zemin, child: govde);
  }

  Widget _rolKart() {
    final id = _sira[_i];
    final rol = _oyun.roller[id]!;
    final r = context.renkler;
    final esler = rol == Rol.kurt
        ? _oyun.kurtlar.where((x) => x != id).map((x) => _oyuncu(x).ad).toList()
        : <String>[];
    final es = _oyun.ask[id];
    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${_oyuncu(id).ad} · Rolün hazır', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Expanded(
              child: BasiliTutKart(
                kapaliEtiket: 'Basılı tut: rolün',
                azamiAcikSn: 8,
                acik: (c) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: r.yuzey,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: r.mor, width: 2),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                            '${rol == Rol.kurt ? '🐺 ' : ''}${trUpper(rolAdi[rol]!)}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        Text(_rolYazi(rol), textAlign: TextAlign.center),
                        if (esler.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Eş kurt: ${esler.join(', ')}'),
                        ],
                        if (es != null) ...[
                          const SizedBox(height: 12),
                          Text('Eşin: ${_oyuncu(es).ad}'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _rolGordum, child: const Text('Gördüm')),
          ],
        ),
      ),
    );
  }

  Widget _sabah() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.wb_sunny_rounded, size: 72),
          const SizedBox(height: 12),
          Text('Şafak',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          for (final s in _sabahSatirlari)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(s, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
            ),
          const Spacer(),
          const Text('Telefon masada; hep birlikte okuyun.', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _sabahDevam,
            child: const Text('Devam'),
          ),
        ],
      ),
    );
  }

  Widget _avciGovde() {
    final id = _avciId!;
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Son atış! · ${_sayac.kalanSn} sn', style: TextStyle(color: r.metinIkincil)),
          LinearProgressIndicator(value: _sayac.oran),
          const SizedBox(height: 12),
          Text('Kimi vuracaksın?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _hedefIzgara(id, Rol.avci, izinli: _oyun.canlilar.where((x) => x != id).toList()),
          const Spacer(),
          FilledButton(
            onPressed: _secim == null ? null : () => _avciVur(_secim),
            child: const Text('Vur'),
          ),
          OutlinedButton(onPressed: () => _avciVur(null), child: const Text('Vazgeç')),
        ],
      ),
    );
  }

  Widget _tartisma() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text('Tartışma zamanı',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          Text(_tartKalan.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w900)),
          const Text('Konuşma masada; telefonu bırakın.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('Canlı: ${_oyun.canlilar.map((i) => _oyuncu(i).ad).join(', ')}',
              textAlign: TextAlign.center),
          if (_oyun.olu.isNotEmpty)
            Text('Elenenler sessiz izler: ${_oyun.olu.map((i) => _oyuncu(i).ad).join(', ')}',
                textAlign: TextAlign.center),
          const Spacer(),
          FilledButton(onPressed: _oylamayaGec, child: const Text('Oylamaya geç')),
        ],
      ),
    );
  }

  Widget _oyGovde() {
    final id = _sira[_i];
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_oyuncu(id).ad} · ${_sayac.kalanSn} sn', style: TextStyle(color: r.metinIkincil)),
          LinearProgressIndicator(value: _sayac.oran),
          const SizedBox(height: 12),
          Text('Kim elensin?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _hedefIzgara(id, Rol.koylu,
              izinli: _oyAdaylari.where((x) => x != id && _oyun.canli(x)).toList()),
          const Spacer(),
          Text(_secim == null ? 'Boş bırakırsan oy sayılmaz.' : 'Seçimin: ${_oyuncu(_secim!).ad}',
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(onPressed: _oyKisiBitti, child: const Text('Oyu ver')),
        ],
      ),
    );
  }

  Widget _oySonuc() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text('Oylama sonucu',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(_oySonucMetni, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
          const Spacer(),
          FilledButton(onPressed: _oySonucDevam, child: const Text('Devam')),
        ],
      ),
    );
  }

  Widget _final() {
    final k = _oyun.kazanan();
    final yalanci = _oyun.enIyiYalanci();
    final supheci = _oyun.supheci();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(k == Taraf.koy ? 'Köy kazandı!' : 'Kurtlar kazandı!',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(children: [
              for (final p in _p)
                ListTile(
                  leading: OyuncuSimgesi(oyuncu: p, boyut: 36),
                  title: Text('${p.ad}${_oyun.canli(p.id) ? '' : ' ✕'}'),
                  trailing: Text(rolAdi[_oyun.roller[p.id]]!),
                ),
              if (yalanci != null)
                ListTile(title: const Text('En iyi yalancı'), subtitle: Text(_oyuncu(yalanci).ad)),
              if (supheci != null)
                ListTile(title: const Text('Şüpheci'), subtitle: Text(_oyuncu(supheci).ad)),
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
