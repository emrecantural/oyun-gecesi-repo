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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyunlar',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Hızlı başlat',
            icon: const Icon(Icons.bolt_rounded),
            onPressed: _hizliBaslat,
          ),
          IconButton(
            tooltip: 'Odaya katıl',
            icon: const Icon(Icons.login_rounded),
            onPressed: () => context.push('/katil'),
          ),
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/ayarlar'),
          ),
        ],
      ),
      bottomNavigationBar: const ReklamBandi(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vitrin.isNotEmpty) ...[
            Card(
              color: r.yukseltilmis,
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                        for (final o in vitrin)
                          ActionChip(
                            avatar: Icon(o.ikon, size: 18),
                            label: Text(o.ad),
                            onPressed: () => context.push('/oyun/${o.id}'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tümü'),
                  selected: _filtre == null,
                  onSelected: (_) => setState(() => _filtre = null),
                ),
                for (final k in OyunKategori.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(k.ad),
                    selected: _filtre == k,
                    onSelected: (_) => setState(() => _filtre = k),
                  ),
                ],
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
                ]) ...[
                  ChoiceChip(
                    label: Text(etiket),
                    selected: _enFazlaDk == dk,
                    onSelected: (_) => setState(() => _enFazlaDk = dk),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _filtre == null
                ? 'Tüm oyunlar (${liste.length})'
                : '${_filtre!.ad} (${liste.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final o in liste) ...[
            _OyunKarti(oyun: o),
            const SizedBox(height: 12),
          ],
        ],
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

class _OyunKarti extends StatelessWidget {
  const _OyunKarti({required this.oyun});
  final OyunBilgisi oyun;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/oyun/${oyun.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: r.yukseltilmis,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(oyun.ikon, color: r.ana, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(oyun.ad,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(oyun.kisa,
                        style: TextStyle(color: r.metinIkincil)),
                    const SizedBox(height: 4),
                    Text(
                      '${oyun.kategori.ad} · ${oyun.kisiAraligi} · ${oyun.sureYazi}',
                      style: TextStyle(color: r.metinIkincil, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: r.metinIkincil),
            ],
          ),
        ),
      ),
    );
  }
}
