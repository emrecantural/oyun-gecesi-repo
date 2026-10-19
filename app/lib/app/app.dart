import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'settings.dart';
import 'theme.dart';

class OyunGecesiApp extends ConsumerWidget {
  const OyunGecesiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final tema = ref.watch(ayarlarProvider.select((a) => a.tema));
    return MaterialApp.router(
      title: 'Oyun Gecesi',
      debugShowCheckedModeBanner: false,
      theme: acikTema(),
      darkTheme: koyuTema(),
      themeMode: tema,
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
