import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/premium.dart';
import '../../app/theme.dart';
import '../../core/sure_sayaci.dart';
import '../../core/tr_text.dart';
import '../../shell/ortak/gizli_bilgi.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'casus_mantik.dart';
import 'mekan_deposu.dart';
import '../../platform/titresim.dart';

final kimCasus = OyunUygulamasi(
  id: '02',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'sure',
      baslik: 'Tur süresi',
      secenekler: {'5': '5 dk', '8': '8 dk', '10': '10 dk', '12': '12 dk'},
      varsayilan: '8',
    ),
    AyarSatiri(
      anahtar: 'tur',
      baslik: 'Tur sayısı',
      secenekler: {'1': '1', '2': '2', '3': '3', '4': '4', '5': '5'},
      varsayilan: '3',
    ),
    AyarSatiri(
      anahtar: 'rol',
      baslik: 'Rol kartları (masumlara mekân içi rol)',
      secenekler: {'evet': 'Açık', 'hayir': 'Kapalı'},
      varsayilan: 'evet',
    ),
    AyarSatiri(
      anahtar: 'kategori',
      baslik: 'Casus kategori ipucu',
      secenekler: {'hayir': 'Kapalı', 'evet': 'Açık'},
      varsayilan: 'hayir',
    ),
    AyarSatiri(
      anahtar: 'sira',
      baslik: 'Soru sırası',
      secenekler: {'serbest': 'Serbest', 'kura': 'Kura'},
      varsayilan: 'serbest',
      gelismis: true,
    ),
  ],
  ekran: (context, oturum) => KimCasusEkrani(oturum: oturum),
);

enum _Ui {
  kartGecis,
  kartGoster,
  masa,
  suclaKim, // suçlayan seç
  suclaKime, // şüpheli seç
  oyGecis,
  oyVer,
  aciGecis,
  aciOy,
  iddiaKim,
  iddiaGizli,
  tahmin,
  reveal,
  skor,
  bitti,
}

class KimCasusEkrani extends ConsumerStatefulWidget {
  const KimCasusEkrani({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<KimCasusEkrani> createState() => _CasusDurum();
}

class _CasusDurum extends ConsumerState<KimCasusEkrani> {
  final _sayac = SureSayaci();
  final _tahminSayac = SureSayaci();
  CasusOyunu? _oyun;
  List<Mekan> _mekanlar = const [];
  _Ui _ui = _Ui.kartGecis;
  int _i = 0; // sıradaki oyuncu (kart/oy dağıtımı)
  int? _suclayan;
  int _kalanMs = 0;
  final Set<int> _ustuCizili = {};
  int? _tahminSecimi;
  int? _iddiaEden;
  String? _hata;
  List<int> _oySirasi = const [];

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _p => _o.oyuncular;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final m = await ref.read(mekanlarProvider.future);
      if (m.isEmpty) {
        setState(() => _hata = 'Mekân bulunamadı.');
        return;
      }
      _mekanlar = m;
      _oyunuKur();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _hata = 'Mekânlar yüklenemedi.');
    }
  }

  void _oyunuKur() {
    _oyun = CasusOyunu(
      oyuncuSayisi: _p.length,
      mekanlar: _mekanlar,
      ayar: CasusAyar(
        sureMs: _o.ayarInt('sure') * 60000,
        turSayisi: _o.ayarInt('tur'),
        rolKartlari: _o.ayar('rol') == 'evet',
        kategoriIpucu: _o.ayar('kategori') == 'evet',
        kura: _o.ayar('sira') == 'kura',
      ),
    );
    _turBaslat();
  }

  void _turBaslat() {
    _oyun!.turBaslat();
    _kalanMs = _oyun!.ayar.sureMs;
    _ustuCizili.clear();
    _i = 0;
    _ui = _Ui.kartGecis;
  }

  @override
  void dispose() {
    _sayac.dispose();
    _tahminSayac.dispose();
    super.dispose();
  }

  // --- Zaman ---

  void _masayaGec() {
    _ui = _Ui.masa;
    _sayac.baslat(_kalanMs, bitince: _sureBitti);
    setState(() {});
  }

  void _masadanCik() {
    _kalanMs = _sayac.kalanMs;
    _sayac.durdur();
  }

  void _sureBitti() {
    _oyun!.sureBitti();
    _kalanMs = 0;
    _oySirasi = [for (var i = 0; i < _p.length; i++) i];
    _i = 0;
    setState(() => _ui = _Ui.aciGecis);
  }

  // --- Akış ---

  void _tahmineGec() {
    _tahminSecimi = null;
    _ui = _Ui.tahmin;
    _tahminSayac.baslat(30000, bitince: () {
      if (_oyun!.asama == CasusAsama.tahmin) {
        _oyun!.tahminSuresiBitti();
        setState(() => _ui = _Ui.reveal);
      }
    });
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    if (_hata != null) return Center(child: Text(_hata!));
    final oyun = _oyun;
    if (oyun == null) return const Center(child: CircularProgressIndicator());
    return ListenableBuilder(
      listenable: Listenable.merge([_sayac, _tahminSayac]),
      builder: (context, _) {
        switch (_ui) {
          case _Ui.kartGecis:
            return GecisEkrani(
              oyuncu: _p[_i],
              onHazir: () => setState(() => _ui = _Ui.kartGoster),
              ipucu: 'Kartını göreceksin. Hazır olunca dokun.',
            );
          case _Ui.kartGoster:
            return _kartGoster();
          case _Ui.masa:
            return _masa();
          case _Ui.suclaKim:
            return _kisiSec(
              baslik: 'Kim suçlayacak?',
              uygun: (i) => !oyun.suclamaKullanan.contains(i),
              secildi: (i) => setState(() {
                _suclayan = i;
                _ui = _Ui.suclaKime;
              }),
              vazgec: () => _masayaDon(),
            );
          case _Ui.suclaKime:
            return _kisiSec(
              baslik: '${_p[_suclayan!].ad}, kimi suçluyorsun?',
              uygun: (i) => i != _suclayan,
              secildi: (i) {
                oyun.suclaBaslat(_suclayan!, i);
                _oySirasi = oyun.oyVerecekler;
                _i = 0;
                setState(() => _ui = _Ui.oyGecis);
              },
              vazgec: () => _masayaDon(),
            );
          case _Ui.oyGecis:
            return GecisEkrani(
              oyuncu: _p[_oySirasi[_i]],
              onHazir: () => setState(() => _ui = _Ui.oyVer),
              ipucu: 'Gizli oyunu vereceksin.',
            );
          case _Ui.oyVer:
            return _oyVer();
          case _Ui.aciGecis:
            return GecisEkrani(
              oyuncu: _p[_oySirasi[_i]],
              onHazir: () => setState(() => _ui = _Ui.aciOy),
              ipucu: 'Süre bitti. Casus sence kim?',
            );
          case _Ui.aciOy:
            return _kisiSec(
              baslik: '${_p[_oySirasi[_i]].ad}, casus kim?',
              uygun: (i) => i != _oySirasi[_i],
              secildi: _aciOyVer,
              gizli: true,
            );
          case _Ui.iddiaKim:
            return _kisiSec(
              baslik: 'Kim "Mekânı biliyorum" diyor?',
              uygun: (_) => true,
              secildi: (i) {
                _iddiaEden = i;
                if (oyun.casusIddiasi(i)) {
                  _masadanCik();
                  _tahmineGec();
                } else {
                  setState(() => _ui = _Ui.iddiaGizli);
                }
              },
              vazgec: _masayaDon,
            );
          case _Ui.iddiaGizli:
            return GizliEkran(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${_p[_iddiaEden!].ad}, casus değilsin.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: _masayaDon, child: const Text('Tamam')),
                  ],
                ),
              ),
            );
          case _Ui.tahmin:
            return _tahmin();
          case _Ui.reveal:
            return _reveal();
          case _Ui.skor:
            return _skor();
          case _Ui.bitti:
            return _final();
        }
      },
    );
  }

  void _masayaDon() {
    // Suçlama/iddia iptal: durumu masaya döndür.
    final oyun = _oyun!;
    if (oyun.asama == CasusAsama.suclama) {
      // Başlamış suçlamadan dönülemez; oylar tamamlanır.
      return;
    }
    _masayaGec();
  }

  // --- Ekranlar ---

  Widget _kartGoster() {
    final oyun = _oyun!;
    final o = _p[_i];
    final k = oyun.kartiGor(_i);
    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${o.ad}, kartın hazır',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            BasiliTutKart(
              kapaliEtiket: 'Gizli kart',
              ipucu: 'Kartı görmek için basılı tut',
              acik: (ctx) => SizedBox(
                height: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: k.casus
                      ? [
                          const Text('CASUSSUN!',
                              style: TextStyle(
                                  fontSize: 36, fontWeight: FontWeight.w900)),
                          if (k.kategori != null) ...[
                            const SizedBox(height: 12),
                            Text('Kategori: ${kategoriAdi(k.kategori!)}',
                                style: const TextStyle(fontSize: 20)),
                          ],
                        ]
                      : [
                          Text('Mekân: ${k.mekan}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w900)),
                          if (k.rol != null) ...[
                            const SizedBox(height: 8),
                            Text('Rolün: ${k.rol}',
                                style: const TextStyle(fontSize: 20)),
                          ],
                          if (k.ipucu != null) ...[
                            const SizedBox(height: 8),
                            Text('Örnek soru: ${k.ipucu}',
                                textAlign: TextAlign.center),
                          ],
                        ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                if (_i + 1 < _p.length) {
                  setState(() {
                    _i++;
                    _ui = _Ui.kartGecis;
                  });
                } else {
                  oyun.rolDagitimiBitti();
                  _masayaGec();
                }
              },
              child: const Text('Hazırım'),
            ),
          ],
        ),
      ),
    );
  }

  String _sureMetni(int ms) {
    final sn = (ms / 1000).ceil();
    return '${(sn ~/ 60).toString().padLeft(2, '0')}:${(sn % 60).toString().padLeft(2, '0')}';
  }

  Widget _masa() {
    final oyun = _oyun!;
    final r = context.renkler;
    final kura = oyun.ayar.kura;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('Tur ${oyun.tur}/${oyun.ayar.turSayisi}',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(_sureMetni(_sayac.kalanMs),
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _sayac.kalanSn <= 30 ? r.tehlike : r.metin)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Soran: ', style: TextStyle(fontSize: 18)),
            OyuncuSimgesi(oyuncu: _p[oyun.soranIdx], boyut: 32),
            const SizedBox(width: 8),
            Text(_p[oyun.soranIdx].ad,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          if (!kura) ...[
            Text('Kime sorulacak?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _p.length; i++)
                      if (i != oyun.soranIdx)
                        OyuncuCipi(
                          oyuncu: _p[i],
                          altYazi:
                              oyun.soruSorulabilir(oyun.soranIdx, i) ? null : 'Geri soru yok',
                          pasif: !oyun.soruSorulabilir(oyun.soranIdx, i),
                          onTap: () => setState(() => oyun.sor(i)),
                        ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Spacer(),
            FilledButton(
              onPressed: () => setState(oyun.kuraSoran),
              child: const Text('Sıradaki soran (kura)'),
            ),
            const Spacer(),
          ],
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _masadanCik();
                  setState(() => _ui = _Ui.suclaKim);
                },
                child: const Text('Suçla'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _mekanListesi,
                child: const Text('Mekân listesi'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              _masadanCik();
              setState(() => _ui = _Ui.iddiaKim);
            },
            child: const Text('Mekânı biliyorum'),
          ),
          TextButton(
            onPressed: () {
              _masadanCik();
              _oyun!.turuBitirPuansiz();
              setState(() => _ui = _Ui.reveal);
            },
            child: const Text('Turu bitir (puansız)'),
          ),
        ],
      ),
    );
  }

  Future<void> _mekanListesi() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mekânlar (dokun: üstünü çiz)',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _mekanlar.length; i++)
                          FilterChip(
                            label: Text(
                              _ustuCizili.contains(i)
                                  ? '✕ ${_mekanlar[i].ad}'
                                  : _mekanlar[i].ad,
                              style: TextStyle(
                                decoration: _ustuCizili.contains(i)
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            selected: _ustuCizili.contains(i),
                            showCheckmark: false,
                            onSelected: (_) => set(() {
                              if (!_ustuCizili.remove(i)) _ustuCizili.add(i);
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!ref.read(premiumProvider))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Premium\'da +19 mekân'),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _kisiSec({
    required String baslik,
    required bool Function(int) uygun,
    required void Function(int) secildi,
    VoidCallback? vazgec,
    bool gizli = false,
  }) {
    final govde = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(baslik, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _p.length; i++)
                    OyuncuCipi(
                      oyuncu: _p[i],
                      pasif: !uygun(i),
                      onTap: () => secildi(i),
                    ),
                ],
              ),
            ),
          ),
          if (vazgec != null)
            TextButton(onPressed: vazgec, child: const Text('Vazgeç')),
        ],
      ),
    );
    return gizli ? GizliEkran(child: govde) : govde;
  }

  Widget _oyVer() {
    final oyun = _oyun!;
    final voter = _oySirasi[_i];
    final sup = _p[oyun.suclananIdx!];
    void ver(bool evet) {
      Titresim.hafif();
      oyun.suclamaOyu(voter, evet);
      if (oyun.asama == CasusAsama.suclama) {
        setState(() {
          _i++;
          _ui = _Ui.oyGecis;
        });
      } else if (oyun.asama == CasusAsama.soruCevap) {
        _kalanMs = _kalanMs == 0 ? 1000 : _kalanMs;
        _masayaGec();
      } else if (oyun.asama == CasusAsama.tahmin) {
        _tahmineGec();
      } else {
        setState(() => _ui = _Ui.reveal);
      }
    }

    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(trUpper(_p[voter].ad),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${sup.ad} casus mu?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            FilledButton(onPressed: () => ver(true), child: const Text('Evet')),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: () => ver(false), child: const Text('Hayır')),
          ],
        ),
      ),
    );
  }

  void _aciOyVer(int suspect) {
    final oyun = _oyun!;
    final voter = _oySirasi[_i];
    oyun.aciOy(voter, suspect);
    if (oyun.asama == CasusAsama.aciKOylama) {
      setState(() {
        _i++;
        _ui = _Ui.aciGecis;
      });
    } else if (oyun.asama == CasusAsama.tahmin) {
      _tahmineGec();
    } else {
      setState(() => _ui = _Ui.reveal);
    }
  }

  Widget _tahmin() {
    final oyun = _oyun!;
    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text('Mekân neresi?',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Text('${_tahminSayac.kalanSn} sn',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _mekanlar.length; i++)
                      ChoiceChip(
                        label: Text(_mekanlar[i].ad),
                        selected: _tahminSecimi == i,
                        onSelected: (_) => setState(() => _tahminSecimi = i),
                      ),
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: _tahminSecimi == null
                  ? null
                  : () {
                      _tahminSayac.durdur();
                      oyun.tahminEt(_tahminSecimi!);
                      setState(() => _ui = _Ui.reveal);
                    },
              child: Text(_tahminSecimi == null
                  ? 'Mekânı seç'
                  : '${_mekanlar[_tahminSecimi!].ad} mı? Onayla'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reveal() {
    final oyun = _oyun!;
    final r = context.renkler;
    final baslik = switch (oyun.sonuc) {
      TurSonucu.casusYakalanmadi => 'Casus kazandı!',
      TurSonucu.yakalandiMekanDogru => 'Casus yakalandı ama mekânı bildi.',
      TurSonucu.yakalandiMekanYanlis => 'Casus yakalandı! Masumlar kazandı.',
      TurSonucu.iddiaDogru => 'Casus mekânı doğru bildi!',
      TurSonucu.iddiaYanlis => 'Casus yanlış bildi! Masumlar kazandı.',
      null => 'Tur bitti.',
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(baslik,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text('Mekân ${oyun.mekan.ad} idi.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: r.ana)),
          Text('Casus: ${_p[oyun.casusIdx].ad}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          FilledButton(
            onPressed: () => setState(() => _ui = _Ui.skor),
            child: const Text('Puanlar'),
          ),
        ],
      ),
    );
  }

  Widget _skor() {
    final oyun = _oyun!;
    final sirali = List.generate(_p.length, (i) => i)
      ..sort((a, b) => oyun.puanlar[b].compareTo(oyun.puanlar[a]));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Puanlar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final i in sirali)
                  Card(
                    child: ListTile(
                      minTileHeight: 56,
                      leading: OyuncuSimgesi(oyuncu: _p[i], boyut: 36),
                      title: Text(_p[i].ad),
                      trailing: Text(
                        '${oyun.puanlar[i]}'
                        '${oyun.sonPuanArtisi.length > i && oyun.sonPuanArtisi[i] > 0 ? '  (+${oyun.sonPuanArtisi[i]})' : ''}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              if (oyun.sonTurMu) {
                oyun.sonrakiTurVeyaFinal();
                setState(() => _ui = _Ui.bitti);
              } else {
                setState(_turBaslat);
              }
            },
            child: Text(oyun.sonTurMu ? 'Final' : 'Sonraki tur'),
          ),
        ],
      ),
    );
  }

  Widget _final() {
    final oyun = _oyun!;
    final r = context.renkler;
    final sirali = List.generate(_p.length, (i) => i)
      ..sort((a, b) => oyun.puanlar[b].compareTo(oyun.puanlar[a]));
    final dedektif = oyun.enIyiDedektif;
    final yalanci = oyun.enIyiYalanci;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.emoji_events_rounded, size: 72, color: r.vurgu),
          Text('Gecenin dedektifi: ${_p[sirali.first].ad}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          Expanded(
            child: ListView(children: [
              for (var s = 0; s < sirali.length; s++)
                ListTile(
                  leading: Text('${s + 1}.',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  title: Text(_p[sirali[s]].ad),
                  trailing: Text('${oyun.puanlar[sirali[s]]}'),
                ),
              if (dedektif != null)
                ListTile(
                    leading: const Icon(Icons.search_rounded),
                    title: Text('En iyi dedektif: ${_p[dedektif].ad}')),
              if (yalanci != null)
                ListTile(
                    leading: const Icon(Icons.theater_comedy_rounded),
                    title: Text('En iyi yalancı: ${_p[yalanci].ad}')),
            ]),
          ),
          FilledButton(
            onPressed: () => setState(_oyunuKur),
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
