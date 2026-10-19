import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/settings.dart';
import '../app/theme.dart';

/// M01–M02a: karşılama ve gizlilik bilgisi. Toplanmayan veri için onay kutusu yoktur.
class OnboardingEkrani extends ConsumerWidget {
  const OnboardingEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.renkler;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.celebration_rounded, size: 96, color: r.ana),
              const SizedBox(height: 24),
              Text(
                'Oyun Gecesi',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Arkadaşlarınla tek telefonda ya da odada oynayacağın parti oyunları.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: r.metinIkincil),
              ),
              const Spacer(),
              Text(
                'Hesap yok, analitik yok. Tercihlerin cihazında kalır; çevrimiçi odada takma adın ve rastgele cihaz kimliğin paylaşılır. Ayrıntılar Ayarlar > Gizlilik’te.',
                textAlign: TextAlign.center,
                style: TextStyle(color: r.metinIkincil),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(ayarlarProvider.notifier).onboardingiBitir(),
                child: const Text('Başla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
