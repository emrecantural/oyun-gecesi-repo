import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/settings.dart';
import 'monetization/reklam_servisi.dart';
import 'monetization/oda_gecisi.dart';
import 'monetization/satin_alma.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ilk = await ayarlariYukle();
  final kap = ProviderContainer(
    overrides: [
      ayarlarProvider.overrideWith(() => AyarlarNotifier(ilk)),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: kap,
      child: const OyunGecesiApp(),
    ),
  );
  // Satın alma hakkı önce okunur; rıza ve reklam SDK'sı arka planda başlar, oyun beklemez.
  unawaited(kap.read(odaGecisiProvider).baslat());
  unawaited(kap.read(satinAlmaProvider).baslat().then((_) => kap.read(reklamProvider).baslat()));
}
