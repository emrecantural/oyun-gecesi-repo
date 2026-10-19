import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../games/oyun_uygulamalari.dart';
import '../games/registry.dart';
import '../monetization/reklam_servisi.dart';

/// Yılbaşı vitrini: 20 Aralık – 2 Ocak arası öne çıkan oyunlar.
bool yilbasiDonemi(DateTime simdi) =>
    (simdi.month == 12 && simdi.day >= 20) || (simdi.month == 1 && simdi.day <= 2);

const yilbasiOyunlari = ['01', '24', '10'];

Color _kategoriRengi(OyunRenkleri r, OyunKategori k) => switch (k) {
      OyunKategori.parti => r.ana,
      OyunKategori.konusma => r.ikincil,
      OyunKategori.kelime => r.vurgu,
      OyunKategori.bilgi => r.mor,
      OyunKategori.cekilis => r.nane,
    };

/// Zemin rengine göre okunur metin rengi.
Color _uzerindeMetin(Color zemin) =>
    zemin.computeLuminance() > 0.45 ? const Color(0xFF231F3B) : Colors.white;

class OyunlarEkrani extends StatefulWidget {
  const OyunlarEkrani({super.key});

  @override
  State<OyunlarEkrani> createState() => _OyunlarDurum();
}

class _OyunlarDurum extends State<OyunlarEkrani> {
  OyunKategori? _filtre;
  int? _enFazlaDk;

  void _hizliBaslat() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _HizliBaslat(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final liste = oyunlar
        .where((o) => _filtre == null || o.kategori == _filtre)
        .where((o) => _enFazlaDk == null || o.sureDk <= _enFazlaDk!)
        .toList();
    final vitrin = yilbasiDonemi(DateTime.now())
        ? [for (final id in yilbasiOyunlari) ?oyunBul(id)]
        : const <OyunBilgisi>[];
    final genis = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      bottomNavigationBar: const ReklamBandi(),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Oyun Gecesi',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                        IconButton(
                          tooltip: 'Ayarlar',
                          icon: const Icon(Icons.settings_rounded),
                          onPressed: () => context.push('/ayarlar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Kahraman(
                      onHizli: _hizliBaslat,
                      onKatil: () => context.push('/katil'),
                    ),
                    if (vitrin.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _YilbasiBandi(oyunlar: vitrin),
                    ],
                    const SizedBox(height: 20),
                    Text('Oyunlar',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FiltreKapsul(
                            etiket: 'Tümü',
                            renk: r.metin,
                            secili: _filtre == null,
                            onTap: () => setState(() => _filtre = null),
                          ),
                          for (final k in OyunKategori.values)
                            _FiltreKapsul(
                              etiket: k.ad,
                              renk: _kategoriRengi(r, k),
                              secili: _filtre == k,
                              onTap: () => setState(() => _filtre = k),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (etiket, dk) in const <(String, int?)>[
                            ('Her süre', null),
                            ('≤ 10 dk', 10),
                            ('≤ 20 dk', 20),
                          ])
                            _FiltreKapsul(
                              etiket: etiket,
                              renk: r.metinIkincil,
                              secili: _enFazlaDk == dk,
                              onTap: () => setState(() => _enFazlaDk = dk),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (liste.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Bu filtreyle oyun yok.', textAlign: TextAlign.center),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: genis ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 168,
                  ),
                  itemCount: liste.length,
                  itemBuilder: (context, i) => _OyunKutusu(oyun: liste[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Kahraman extends StatelessWidget {
  const _Kahraman({required this.onHizli, required this.onKatil});
  final VoidCallback onHizli;
  final VoidCallback onKatil;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [r.ana, r.mor],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bu gece ne oynuyoruz?',
              style: TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Kaç kişi olduğunu söyle, sana uygun oyunları bulalım.',
              style: TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF231F3B),
                ),
                onPressed: onHizli,
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Hızlı başlat'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                ),
                onPressed: onKatil,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Odaya katıl'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _YilbasiBandi extends StatelessWidget {
  const _YilbasiBandi({required this.oyunlar});
  final List<OyunBilgisi> oyunlar;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: r.yukseltilmis,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: r.vurgu, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yılbaşı gecesi için',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in oyunlar)
                ActionChip(
                  avatar: Icon(o.ikon, size: 18),
                  label: Text(o.ad),
                  onPressed: () => context.push('/oyun/${o.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FiltreKapsul extends StatelessWidget {
  const _FiltreKapsul({
    required this.etiket,
    required this.renk,
    required this.secili,
    required this.onTap,
  });
  final String etiket;
  final Color renk;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: secili,
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: secili ? renk : r.yuzey,
                border: Border.all(color: renk, width: 2),
              ),
              child: Text(
                etiket,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: secili ? _uzerindeMetin(renk) : r.metin,
                ),
              ),
            ),
          ),
      ),
    );
  }
}

class _OyunKutusu extends StatelessWidget {
  const _OyunKutusu({required this.oyun});
  final OyunBilgisi oyun;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final renk = _kategoriRengi(r, oyun.kategori);
    final yazi = _uzerindeMetin(renk);
    return Material(
      borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          color: renk,
          child: InkWell(
            onTap: () => context.push('/oyun/${oyun.id}'),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  bottom: -18,
                  child: Icon(oyun.ikon, size: 110, color: yazi.withAlpha(36)),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: yazi.withAlpha(40),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(oyun.ikon, color: yazi, size: 26),
                          ),
                          const Spacer(),
                          if (oyun.sadeceOda)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: yazi.withAlpha(40),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Oda',
                                  style: TextStyle(
                                      color: yazi,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        oyun.ad,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: yazi, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${oyun.kisiAraligi} · ${oyun.sureYazi}',
                        style: TextStyle(color: yazi, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

/// M05: kaç kişisiniz? → tek cihazda oynanabilen uygun oyunlar.
class _HizliBaslat extends StatefulWidget {
  const _HizliBaslat();

  @override
  State<_HizliBaslat> createState() => _HizliBaslatDurum();
}

class _HizliBaslatDurum extends State<_HizliBaslat> {
  int _kisi = 4;

  @override
  Widget build(BuildContext context) {
    final uygun = [
      for (final o in oyunlar)
        if (!o.sadeceOda &&
            oyunUygulamasi(o.id) != null &&
            o.min <= _kisi &&
            _kisi <= o.yerelMax)
          o,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Kaç kişisiniz?',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Azalt',
                  onPressed: _kisi > 1 ? () => setState(() => _kisi--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 96,
                  child: Text('$_kisi',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall),
                ),
                IconButton.filledTonal(
                  tooltip: 'Artır',
                  onPressed: _kisi < 30 ? () => setState(() => _kisi++) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (uygun.isEmpty)
              const Text(
                'Bu kişi sayısı için tek cihazda oynanacak oyun yok. Tombala ve Köy ve Kurtlar gibi oyunlar için “Oda kur”u dene.',
                textAlign: TextAlign.center,
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in uygun)
                      ListTile(
                        leading: Icon(o.ikon),
                        title: Text(o.ad),
                        subtitle: Text('${o.kisa} · ${o.sureYazi}'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/oyun/${o.id}');
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
