import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/settings.dart';
import '../app/theme.dart';

/// M01–M02a: karşılama ve gizlilik bilgisi. Analitik kutusu varsayılan KAPALI.
class OnboardingEkrani extends ConsumerStatefulWidget {
  const OnboardingEkrani({super.key});

  @override
  ConsumerState<OnboardingEkrani> createState() => _OnboardingEkraniState();
}

class _OnboardingEkraniState extends ConsumerState<OnboardingEkrani> {
  bool _analitik = false;

  @override
  Widget build(BuildContext context) {
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
              Card(
                child: CheckboxListTile(
                  value: _analitik,
                  onChanged: (v) => setState(() => _analitik = v ?? false),
                  title: const Text('Anonim kullanım ve hata verisi paylaş'),
                  subtitle: const Text(
                    'İsteğe bağlı. Kapalıysa hiçbir analitik verisi toplanmaz. Ayarlardan değiştirebilirsin.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
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
