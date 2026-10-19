import 'dart:async';

import 'package:flutter/material.dart';
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
import 'tk_mantik.dart';

const _dosya = '11-tek-kelime';

final tekKelime = OyunUygulamasi(
  id: '11',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'kart',
      baslik: 'Kart sayısı',
      secenekler: {'8': '8', '13': '13'},
      varsayilan: '13',
    ),
    AyarSatiri(
      anahtar: 'yaz',
      baslik: 'Yazma süresi',
      secenekler: {'20': '20 sn', '30': '30 sn', '45': '45 sn'},
      varsayilan: '30',
    ),
    AyarSatiri(
      anahtar: 'pas',
      baslik: 'Pas hakkı',
      secenekler: {'0': 'Yok', '1': '1'},
      varsayilan: '1',
    ),
    AyarSatiri(
      anahtar: 'zorluk',
      baslik: 'Zorluk',
      secenekler: {'orta': 'Orta', 'kolay': 'Kolay', 'zor': 'Zor'},
      varsayilan: 'orta',
    ),
  ],
  ekran: (context, oturum) => TekKelimeEkrani(oturum: oturum),
);

enum _Asama { yukleniyor, tahminciKapi, yazGecis, yaz, ele, tahminGecis, tahmin, reveal, final_ }

class TekKelimeEkrani extends ConsumerStatefulWidget {
  const TekKelimeEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<TekKelimeEkrani> createState() => _TkDurum();
}

class _TkDurum extends ConsumerState<TekKelimeEkrani> {
  final _gecmis = GecmisDeposu();
  final _sayac = SureSayaci();
  final _giris = TextEditingController();
  late TekKelimeOyunu _oyun;
  Deste<IcerikOgesi>? _deste;
  _Asama _asama = _Asama.yukleniyor;
  String? _hata;
  String? _uyari;
  String? _bilgi;
  int _yenilenme = 0;

  IcerikOgesi? _kart;
  List<String> _yasak = const [];
  List<int> _yazarlar = const [];
  int _yi = 0;
  final List<Ipucu> _ipuclari = [];
  List<EleGrubu> _gruplar = const [];
  Timer? _eleZamani;
  int _eleKalan = 15;
  String _tahminMetni = '';
  KartSonucu? _kartSonucu;

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _p => _o.oyuncular;
  Oyuncu _oyuncu(int id) => _p.firstWhere((p) => p.id == id);

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
    _eleZamani?.cancel();
    _sayac.removeListener(_yenile);
    _sayac.dispose();
    _giris.dispose();
    super.dispose();
  }

  Future<void> _kur() async {
    _oyun = TekKelimeOyunu(
      oyuncuIdleri: [for (final p in _p) p.id],
      kartSayisi: _o.ayarInt('kart'),
      pasHakki: _o.ayarInt('pas'),
    );
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      final bildirilen = await _gecmis.bildirilenler('11');
      final gorulen = await _gecmis.gorulenler('11');
      final z = _o.ayar('zorluk');
      var havuz = tum
          .where((o) => o.tur == 'kelime' && o.seviye == z && !bildirilen.contains(o.id))
          .toList();
      if (havuz.length < _oyun.kartSayisi + 2) {
        havuz = tum
            .where((o) => o.tur == 'kelime' && !bildirilen.contains(o.id))
            .toList();
      }
      if (havuz.length < _oyun.kartSayisi) {
        if (mounted) setState(() => _hata = 'Yeterli kelime yok.');
        return;
      }
      _deste = Deste(havuz, idOf: (o) => o.id, gorulmus: gorulen);
      _kartAc();
    } catch (_) {
      if (mounted) setState(() => _hata = 'Kelimeler yüklenemedi.');
    }
  }

  void _kartAc() {
    if (_oyun.bitti) {
      setState(() => _asama = _Asama.final_);
      return;
    }
    final d = _deste!;
    final k = d.cek();
    if (k == null) {
      setState(() => _asama = _Asama.final_);
      return;
    }
    _gecmis.gorulenleriKaydet('11', d.gorulen);
    if (d.yenilenme > _yenilenme) {
      _yenilenme = d.yenilenme;
      _bilgi = ref.read(premiumProvider)
          ? 'Havuz yenilendi.'
          : 'Ücretsiz kelimeler bitti. Premium\'da tam içerik var.';
    }
    _kart = k;
    _yasak = k.ek.split(RegExp(r'[|,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    _yazarlar = [for (final p in _p) if (p.id != _oyun.tahminciId) p.id];
    _yi = 0;
    _ipuclari.clear();
    _gruplar = const [];
    _giris.clear();
    _uyari = null;
    setState(() => _asama = _Asama.tahminciKapi);
  }

  void _yazBasla() {
    _giris.clear();
    _uyari = null;
    _sayac.baslat(_o.ayarInt('yaz') * 1000, bitince: () => _gonder(zamanDoldu: true));
    setState(() => _asama = _Asama.yaz);
  }

  void _gonder({bool zamanDoldu = false}) {
    if (_asama != _Asama.yaz) return;
    final h = tkIpucuDogrula(_giris.text, _kart!.metin, _yasak);
    if (h != null && !zamanDoldu) {
      setState(() => _uyari = switch (h) {
            IpucuHatasi.bos => 'Bir ipucu yaz.',
            IpucuHatasi.sayiVeyaHarf => 'Sayı ve tek harf olmaz.',
            IpucuHatasi.kelimeninKendisi => 'Kelimenin kendisi ya da aynı kökü olmaz.',
            IpucuHatasi.yasakKok => 'Bu kök yasak.',
            IpucuHatasi.cokKelime => 'Tek kelime yaz.',
            IpucuHatasi.uzun => 'Çok uzun.',
          });
      return;
    }
    _sayac.durdur();
    if (h == null) _ipuclari.add(Ipucu(_yazarlar[_yi], _giris.text.trim()));
    _giris.clear();
    if (_yi + 1 < _yazarlar.length) {
      _yi++;
      setState(() => _asama = _Asama.yazGecis);
    } else {
      _eleBasla();
    }
  }

  void _eleBasla() {
    _gruplar = tkEle(_ipuclari);
    if (_ipuclari.every((i) => i.silindi) || _ipuclari.isEmpty) {
      _kartSonucu = null;
      _tahminMetni = '';
      _otomatikPas();
      return;
    }
    _eleKalan = 15;
    _eleZamani?.cancel();
    _eleZamani = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_eleKalan <= 1) {
        t.cancel();
        _eleTamam();
      } else {
        setState(() => _eleKalan--);
      }
    });
    setState(() => _asama = _Asama.ele);
  }

  void _eleTamam() {
    _eleZamani?.cancel();
    if (_asama != _Asama.ele) return;
    tkSupheliUygula(_ipuclari, _gruplar);
    if (_ipuclari.every((i) => i.silindi)) {
      _otomatikPas();
      return;
    }
    setState(() => _asama = _Asama.tahminGecis);
  }

  void _otomatikPas() {
    _oyun.kartiBitir(KartSonucu.pas, otomatikPas: true);
    _kartSonucu = KartSonucu.pas;
    _tahminMetni = '';
    setState(() => _asama = _Asama.reveal);
  }

  void _tahminBasla() {
    _giris.clear();
    _sayac.baslat(30000, bitince: () => _tahminEt(bos: true));
    setState(() => _asama = _Asama.tahmin);
  }

  void _tahminEt({bool bos = false}) {
    if (_asama != _Asama.tahmin) return;
    _sayac.durdur();
    final t = _giris.text.trim();
    if (bos || t.isEmpty) {
      // süre doldu: pas sayılır, hak harcanmaz
      _oyun.kartiBitir(KartSonucu.pas, otomatikPas: true);
      _kartSonucu = KartSonucu.pas;
      _tahminMetni = '';
    } else {
      _tahminMetni = t;
      final ok = tkTahminDogru(t, _kart!.metin);
      _oyun.kartiBitir(ok ? KartSonucu.dogru : KartSonucu.yanlis);
      _kartSonucu = ok ? KartSonucu.dogru : KartSonucu.yanlis;
    }
    setState(() => _asama = _Asama.reveal);
  }

  void _pas() {
    if (!_oyun.pasKullanabilir()) return;
    _sayac.durdur();
    _oyun.kartiBitir(KartSonucu.pas);
    _kartSonucu = KartSonucu.pas;
    _tahminMetni = '';
    setState(() => _asama = _Asama.reveal);
  }

  Future<void> _bildir() async {
    final k = _kart;
    if (k == null) return;
    await _gecmis.bildir('11', k.id);
    if (mounted) setState(() => _bilgi = 'Teşekkürler, bildirildi.');
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    final govde = switch (_asama) {
      _Asama.yukleniyor => const Center(child: CircularProgressIndicator()),
      _Asama.tahminciKapi => _tahminciKapi(),
      _Asama.yazGecis => GecisEkrani(
          oyuncu: _oyuncu(_yazarlar[_yi]),
          ipucu: 'Tahminci ${_oyuncu(_oyun.tahminciId).ad} arkasını dönmüş olmalı.',
          onHazir: _yazBasla,
        ),
      _Asama.yaz => _yaz(),
      _Asama.ele => _ele(),
      _Asama.tahminGecis => GecisEkrani(
          oyuncu: _oyuncu(_oyun.tahminciId),
          ipucu: 'Tahminci sensin: telefonu al.',
          onHazir: _tahminBasla,
        ),
      _Asama.tahmin => _tahmin(),
      _Asama.reveal => _reveal(),
      _Asama.final_ => _final(),
    };
    return Container(color: context.renkler.zemin, child: govde);
  }

  Widget _serit() {
    final r = context.renkler;
    return Wrap(spacing: 4, children: [
      for (var i = 0; i < _oyun.kartSayisi; i++)
        Text(
          i < _oyun.sonuclar.length
              ? switch (_oyun.sonuclar[i]) {
                  KartSonucu.dogru => '✓',
                  KartSonucu.yanlis => '✕',
                  _ => '–',
                }
              : '·',
          style: TextStyle(color: r.metinIkincil),
        ),
    ]);
  }

  Widget _tahminciKapi() {
    final t = _oyuncu(_oyun.tahminciId);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_bilgi != null) Text(_bilgi!, textAlign: TextAlign.center),
          _serit(),
          const Spacer(),
          Center(child: OyuncuSimgesi(oyuncu: t, boyut: 96)),
          const SizedBox(height: 16),
          Text('Tahminci: ${t.ad}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${t.ad}, arkanı dön, telefona bakma.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.renkler.metinIkincil)),
          const Spacer(),
          FilledButton(
            onPressed: () => setState(() => _asama = _Asama.yazGecis),
            child: const Text('Tamam, döndü'),
          ),
        ],
      ),
    );
  }

  Widget _yaz() {
    final r = context.renkler;
    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${_oyuncu(_yazarlar[_yi]).ad} · ${_sayac.kalanSn} sn',
                style: TextStyle(color: r.metinIkincil)),
            LinearProgressIndicator(value: _sayac.oran),
            const SizedBox(height: 16),
            Text('Gizli kelime',
                textAlign: TextAlign.center, style: TextStyle(color: r.metinIkincil)),
            Text(_kart!.metin,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(
              controller: _giris,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _gonder(),
              decoration: InputDecoration(
                labelText: 'Tek kelimelik ipucu',
                border: const OutlineInputBorder(),
                errorText: _uyari,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _gonder, child: const Text('Gönder')),
          ],
        ),
      ),
    );
  }

  Widget _ele() {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Eleme · $_eleKalan sn', textAlign: TextAlign.center),
          const Text('Tahminci bakmasın.', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(children: [
              for (var i = 0; i < _ipuclari.length; i++)
                ListTile(
                  title: Text(
                    _ipuclari[i].ham,
                    style: TextStyle(
                      decoration:
                          _ipuclari[i].silindi ? TextDecoration.lineThrough : null,
                      color: _ipuclari[i].silindi ? r.tehlike : null,
                      fontSize: 20,
                    ),
                  ),
                  subtitle: _ipuclari[i].silindi ? const Text('Silindi') : null,
                ),
              for (final g in _gruplar.where((g) => g.durum == 'suspect'))
                SwitchListTile(
                  title: Text(
                      'Aynı mı? ${g.idx.map((i) => _ipuclari[i].ham).join(' / ')}'),
                  subtitle: const Text('Açık: aynı say ve sil'),
                  value: g.aynidir,
                  onChanged: (v) => setState(() => g.aynidir = v),
                ),
            ]),
          ),
          FilledButton(onPressed: _eleTamam, child: const Text('Eleme tamam')),
        ],
      ),
    );
  }

  Widget _tahmin() {
    final kalan = _ipuclari.where((i) => !i.silindi).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_sayac.kalanSn} sn'),
          LinearProgressIndicator(value: _sayac.oran),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final i in kalan)
              Chip(label: Text(i.ham, style: const TextStyle(fontSize: 20))),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _giris,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _tahminEt(),
            decoration: const InputDecoration(
                labelText: 'Kelime hangisi?', border: OutlineInputBorder()),
          ),
          const Spacer(),
          FilledButton(onPressed: _tahminEt, child: const Text('Tahmin et')),
          if (_o.ayarInt('pas') > 0)
            TextButton(
              onPressed: _oyun.pasKullanabilir() ? _pas : null,
              child: Text('Pas (${_oyun.pasKalan})'),
            ),
        ],
      ),
    );
  }

  Widget _reveal() {
    final r = context.renkler;
    final s = _kartSonucu;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _serit(),
          const Spacer(),
          Text(_kart!.metin,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (_tahminMetni.isNotEmpty)
            Text('Tahmin: $_tahminMetni', textAlign: TextAlign.center),
          Text(
            switch (s) {
              KartSonucu.dogru => '✓ Doğru!',
              KartSonucu.yanlis => '✕ Yanlış. Sonraki kart da atıldı.',
              _ => 'Pas',
            },
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: s == KartSonucu.dogru ? r.nane : r.tehlike),
          ),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
            for (final i in _ipuclari)
              Chip(
                label: Text(i.ham,
                    style: TextStyle(
                        decoration: i.silindi ? TextDecoration.lineThrough : null)),
              ),
          ]),
          const Spacer(),
          TextButton(onPressed: _bildir, child: const Text('Bu kelimeyi bildir')),
          FilledButton(
            onPressed: _kartAc,
            child: Text(_oyun.bitti ? 'Sonuç' : 'Sonraki kart'),
          ),
        ],
      ),
    );
  }

  Widget _final() {
    final dogru = _oyun.dogruSayisi;
    final toplam = _oyun.kartSayisi;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text('$dogru / $toplam',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)),
          Text(TekKelimeOyunu.derece(dogru, toplam),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
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
