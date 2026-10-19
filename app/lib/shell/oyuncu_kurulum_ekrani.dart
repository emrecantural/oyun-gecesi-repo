import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../games/registry.dart';
import 'ortak/oturum.dart';
import 'ortak/oyuncular.dart';

/// G2: oyuncuları tanımla.
class OyuncuKurulumEkrani extends ConsumerWidget {
  const OyuncuKurulumEkrani({super.key, required this.oyunId});
  final String oyunId;

  Future<void> _adSor(BuildContext context, WidgetRef ref, {Oyuncu? oyuncu}) async {
    final kontrol = TextEditingController(text: oyuncu?.ad ?? '');
    final sonuc = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(oyuncu == null ? 'Oyuncu ekle' : 'Adı değiştir'),
        content: TextField(
          controller: kontrol,
          autofocus: true,
          maxLength: 12,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Ad'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, kontrol.text),
              child: const Text('Tamam')),
        ],
      ),
    );
    if (sonuc == null) return;
    final notifier = ref.read(masaProvider.notifier);
    if (oyuncu == null) {
      notifier.ekle(sonuc);
    } else {
      notifier.adDegistir(oyuncu.id, sonuc);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oyun = oyunBul(oyunId);
    final oyuncular = ref.watch(masaProvider);
    if (oyun == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Oyun bulunamadı.')));
    }
    final n = oyuncular.length;
    final yeter = n >= oyun.min;
    final dolu = n >= oyun.yerelMax;
    final r = context.renkler;
    final neden = n < oyun.min
        ? 'En az ${oyun.min} oyuncu gerekli.'
        : (n > oyun.yerelMax ? 'Bu oyun en fazla ${oyun.yerelMax} kişiyle oynanır.' : null);

    return Scaffold(
      appBar: AppBar(
        title: Text('Kimler oynuyor?  $n / ${oyun.min}–${oyun.yerelMax}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final o in oyuncular)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          minTileHeight: 64,
                          leading: OyuncuSimgesi(oyuncu: o, boyut: 40),
                          title: Text(o.ad,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 18)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '${o.ad} adını değiştir',
                                icon: const Icon(Icons.edit_rounded),
                                onPressed: () =>
                                    _adSor(context, ref, oyuncu: o),
                              ),
                              IconButton(
                                tooltip: '${o.ad} oyuncusunu kaldır',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => ref
                                    .read(masaProvider.notifier)
                                    .sil(o.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!dolu)
                    OutlinedButton.icon(
                      onPressed: () => _adSor(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Oyuncu ekle'),
                    ),
                  if (n >= 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: () =>
                            ref.read(masaProvider.notifier).karistir(),
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Sırayı karıştır'),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (neden != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(neden,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: r.metinIkincil)),
                    ),
                  FilledButton(
                    onPressed: yeter && n <= oyun.yerelMax
                        ? () => context.push('/oyun/$oyunId/ayar')
                        : null,
                    child: const Text('Devam'),
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
