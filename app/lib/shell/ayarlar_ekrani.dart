import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/premium.dart';
import '../app/settings.dart';
import '../monetization/reklam_servisi.dart';
import '../monetization/satin_alma.dart';
import 'kural_kartlari.dart';

class AyarlarEkrani extends ConsumerWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = ref.watch(ayarlarProvider.select((a) => a.tema));
    final premium = ref.watch(premiumProvider);
    final satin = ref.watch(satinAlmaProvider);
    final reklam = ref.watch(reklamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      bottomNavigationBar: const ReklamBandi(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tema', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
              ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
            ],
            selected: {tema},
            onSelectionChanged: (s) =>
                ref.read(ayarlarProvider.notifier).temaSec(s.first),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Titreşim'),
            value: ref.watch(ayarlarProvider.select((a) => a.titresim)),
            onChanged: (v) =>
                ref.read(ayarlarProvider.notifier).titresimiAyarla(v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kural kartlarını yeniden göster'),
            onTap: () async {
              await kurallariSifirla();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kural kartları yeniden gösterilecek.')),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          Text('Premium', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: satin,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (premium)
                  const Text('Premium açık: tüm içerik ve reklamsız deneyim.')
                else ...[
                  const Text(
                    'Tek seferlik ödeme: tüm içerik açılır, reklamlar kalkar.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: satin.satinAlinabilir &&
                            satin.durum != SatinAlmaDurumu.mesgul
                        ? satin.satinAl
                        : null,
                    child: Text(
                      satin.fiyat == null
                          ? 'Premium (şu an kullanılamıyor)'
                          : 'Premium’a geç · ${satin.fiyat}',
                    ),
                  ),
                ],
                TextButton(
                  onPressed: satin.mevcut &&
                          satin.durum != SatinAlmaDurumu.mesgul
                      ? satin.geriYukle
                      : null,
                  child: const Text('Satın almayı geri yükle'),
                ),
                if (satin.mesaj != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(satin.mesaj!, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
          if (reklam.gizlilikSecenekleriGerekli) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: reklam.gizlilikSecenekleriniAc,
              child: const Text('Reklam gizlilik seçenekleri'),
            ),
          ],
          const SizedBox(height: 24),
          Text('Gizlilik ve yardım',
              style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Gizlilik'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/gizlilik'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Yerel verilerimi sil'),
            onTap: () => _sil(context, ref),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Hakkında ve lisanslar'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Oyun Gecesi',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sil(BuildContext context, WidgetRef ref) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yerel veriler silinsin mi?'),
        content: const Text(
          'Tercihlerin ve cihaz kimliğin silinir, karşılama ekranına dönersin. Premium satın alımın Google Play hesabında durur; “Satın almayı geri yükle” ile geri getirebilirsin.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (onay == true) {
      await ref.read(ayarlarProvider.notifier).yerelVeriyiSil();
    }
  }
}
