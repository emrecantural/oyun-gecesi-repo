import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Ayarlar {
  const Ayarlar({this.onboardingBitti = false, this.tema = ThemeMode.system});

  final bool onboardingBitti;
  final ThemeMode tema;

  Ayarlar copyWith({bool? onboardingBitti, ThemeMode? tema}) => Ayarlar(
        onboardingBitti: onboardingBitti ?? this.onboardingBitti,
        tema: tema ?? this.tema,
      );
}

const _kOnboarding = 'onboarding_bitti';
const _kTema = 'tema';

/// Açılışta disk okuması başarısız olursa varsayılanlara dönülür.
Future<Ayarlar> ayarlariYukle() async {
  try {
    final prefs = SharedPreferencesAsync();
    final bitti = await prefs.getBool(_kOnboarding) ?? false;
    final tema = await prefs.getString(_kTema);
    return Ayarlar(
      onboardingBitti: bitti,
      tema: ThemeMode.values.firstWhere(
        (m) => m.name == tema,
        orElse: () => ThemeMode.system,
      ),
    );
  } catch (_) {
    return const Ayarlar();
  }
}

class AyarlarNotifier extends Notifier<Ayarlar> {
  AyarlarNotifier([this._ilk = const Ayarlar()]);
  final Ayarlar _ilk;

  @override
  Ayarlar build() => _ilk;

  Future<void> onboardingiBitir() async {
    state = state.copyWith(onboardingBitti: true);
    try {
      await SharedPreferencesAsync().setBool(_kOnboarding, true);
    } catch (_) {}
  }

  Future<void> temaSec(ThemeMode mod) async {
    state = state.copyWith(tema: mod);
    try {
      await SharedPreferencesAsync().setString(_kTema, mod.name);
    } catch (_) {}
  }
}

final ayarlarProvider =
    NotifierProvider<AyarlarNotifier, Ayarlar>(AyarlarNotifier.new);
