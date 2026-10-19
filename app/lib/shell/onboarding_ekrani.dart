import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/settings.dart';
import '../app/theme.dart';

/// M01–M02a: üç kartlık karşılama, ardından gizlilik bilgisi.
/// Analitik toplanmadığı için onay kutusu yoktur.
class OnboardingEkrani extends ConsumerStatefulWidget {
  const OnboardingEkrani({super.key});

  @override
  ConsumerState<OnboardingEkrani> createState() => _OnboardingDurum();
}

class _Kart {
  const _Kart(this.ikon, this.baslik, this.metin);
  final IconData ikon;
  final String baslik;
  final String metin;
}

const _kartlar = [
  _Kart(Icons.celebration_rounded, 'Oyun Gecesi',
      'Arkadaşlarınla tek telefonda ya da odada oynayacağın parti oyunları.'),
  _Kart(Icons.phone_android_rounded, 'Telefonu elden ele ver',
      'Ya da herkes kendi telefonundan odaya katılsın.'),
  _Kart(Icons.touch_app_rounded, 'Sen seç, gerisini biz yönetelim',
      'Kaç kişi olduğunu söyle, uygun oyunları göstersin; kurallar her oyunda kısaca anlatılır.'),
];

class _OnboardingDurum extends ConsumerState<OnboardingEkrani> {
  final _sayfa = PageController();
  int _i = 0;

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  void _bitir() => ref.read(ayarlarProvider.notifier).onboardingiBitir();

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final son = _i == _kartlar.length; // son sayfa: gizlilik bilgisi
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: son
                    ? const SizedBox(height: 48)
                    : TextButton(
                        onPressed: () => _sayfa.jumpToPage(_kartlar.length),
                        child: const Text('Atla'),
                      ),
              ),
              Expanded(
                child: PageView(
                  controller: _sayfa,
                  onPageChanged: (v) => setState(() => _i = v),
                  children: [
                    for (final k in _kartlar)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(k.ikon, size: 96, color: r.ana),
                          const SizedBox(height: 24),
                          Text(k.baslik,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Text(k.metin,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: r.metinIkincil)),
                        ],
                      ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.privacy_tip_rounded, size: 96, color: r.ana),
                        const SizedBox(height: 24),
                        Text('Gizlilik',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Text(
                          'Hesap yok, analitik yok. Tercihlerin cihazında kalır; çevrimiçi odada takma adın ve rastgele cihaz kimliğin paylaşılır. Ücretsiz sürümde reklam gösterilir. Ayrıntılar Ayarlar > Gizlilik’te.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: r.metinIkincil),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var k = 0; k <= _kartlar.length; k++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: k == _i ? r.ana : r.metinIkincil.withAlpha(90),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: son
                    ? _bitir
                    : () => _sayfa.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                child: Text(son ? 'Başla' : 'Devam'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
