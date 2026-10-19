import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../games/registry.dart';

class OyunlarEkrani extends StatelessWidget {
  const OyunlarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyunlar',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: oyunlar.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _OyunKarti(oyun: oyunlar[i]),
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
