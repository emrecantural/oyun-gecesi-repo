import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyungecesi/app/app.dart';
import 'package:oyungecesi/app/settings.dart';
import 'package:oyungecesi/games/registry.dart';

void main() {
  test('oyun kayıtları tutarlı', () {
    expect(oyunlar.length, 18);
    expect(oyunlar.map((o) => o.id).toSet().length, 18);
    for (final o in oyunlar) {
      expect(o.min <= o.max, isTrue, reason: o.ad);
    }
  });

  testWidgets('onboarding sonrası oyun listesi açılır', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OyunGecesiApp()));
    await tester.pumpAndSettle();
    expect(find.text('Oyun Gecesi'), findsOneWidget);
    await tester.tap(find.text('Başla'));
    await tester.pumpAndSettle();
    expect(find.text('Oyunlar'), findsOneWidget);
    expect(find.text('Tombala'), findsOneWidget);
  });

  testWidgets('onboarding bitmişse doğrudan liste', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ayarlarProvider.overrideWith(
          () => AyarlarNotifier(const Ayarlar(onboardingBitti: true)),
        ),
      ],
      child: const OyunGecesiApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Oyunlar'), findsOneWidget);
  });
}
