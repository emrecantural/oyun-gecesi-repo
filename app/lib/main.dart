import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ilk = await ayarlariYukle();
  runApp(
    ProviderScope(
      overrides: [
        ayarlarProvider.overrideWith(() => AyarlarNotifier(ilk)),
      ],
      child: const OyunGecesiApp(),
    ),
  );
}
