import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
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

  void _rastgele() {
    final aday = oyunlar.where((o) => !o.sadeceOda).toList();
    context.push('/oyun/${aday[Random().nextInt(aday.length)].id}');
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final liste = oyunlar
        .where((o) => _filtre == null || o.kategori == _filtre)
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
            tooltip: 'Rastgele oyun',
            icon: const Icon(Icons.casino_rounded),
            onPressed: _rastgele,
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
                      '${oyun.kategori.ad} · ${oyun.kisiAraligi}',
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
