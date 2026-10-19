import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../room/oda_ekranlari.dart';
import '../room/oda_servisi.dart';
import '../shell/ayarlar_ekrani.dart';
import '../shell/gizlilik_ekrani.dart';
import '../shell/oyun_detay_ekrani.dart';
import '../shell/oyunlar_ekrani.dart';
import '../shell/onboarding_ekrani.dart';
import '../shell/oyna_ekrani.dart';
import '../shell/oyun_ayar_ekrani.dart';
import '../shell/oyuncu_kurulum_ekrani.dart';
import 'settings.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Yalnızca onboarding durumu yönlendirmeyi etkiler; tema değişince yeniden kurulmaz.
  final bitti = ref.watch(ayarlarProvider.select((a) => a.onboardingBitti));
  return GoRouter(
    initialLocation: bitti ? '/' : '/onboarding',
    redirect: (context, state) {
      final onboarding = state.matchedLocation == '/onboarding';
      if (!bitti && !onboarding) return '/onboarding';
      if (bitti && onboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingEkrani()),
      GoRoute(path: '/', builder: (_, _) => const OyunlarEkrani()),
      GoRoute(
        path: '/oyun/:id',
        builder: (_, state) =>
            OyunDetayEkrani(oyunId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'oyuncular',
            builder: (_, state) =>
                OyuncuKurulumEkrani(oyunId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'ayar',
            builder: (_, state) =>
                OyunAyarEkrani(oyunId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'oda',
            builder: (_, state) =>
                OdaKurEkrani(oyunId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'oyna',
            builder: (_, state) =>
                OynaEkrani(oyunId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: '/katil', builder: (_, _) => const OdaKatilEkrani()),
      GoRoute(
        path: '/oda/:kod',
        builder: (_, state) {
          final giris = state.extra;
          if (giris is OdaGirisi) return OdaEkrani(giris: giris);
          // Doğrudan adres / süreç yeniden başladı: kodla katılma ekranına dön.
          return const OdaKatilEkrani();
        },
      ),
      GoRoute(path: '/ayarlar', builder: (_, _) => const AyarlarEkrani()),
      GoRoute(path: '/gizlilik', builder: (_, _) => const GizlilikEkrani()),
    ],
  );
});
