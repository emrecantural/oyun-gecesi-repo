import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/titresim.dart';

class Ayarlar {
  const Ayarlar({
    this.onboardingBitti = false,
    this.tema = ThemeMode.system,
    this.titresim = true,
    this.takmaAd = '',
  });

  final bool onboardingBitti;
  final ThemeMode tema;
  final bool titresim;

  /// Odaya girerken önerilen takma ad (boşsa öneri yok).
  final String takmaAd;

  Ayarlar copyWith({
    bool? onboardingBitti,
    ThemeMode? tema,
    bool? titresim,
    String? takmaAd,
  }) =>
      Ayarlar(
        onboardingBitti: onboardingBitti ?? this.onboardingBitti,
        tema: tema ?? this.tema,
        titresim: titresim ?? this.titresim,
        takmaAd: takmaAd ?? this.takmaAd,
      );
}

const _kOnboarding = 'onboarding_bitti';
const _kTema = 'tema';
const _kTitresim = 'titresim';
const _kTakmaAd = 'takma_ad';

/// Açılışta disk okuması başarısız olursa varsayılanlara dönülür.
Future<Ayarlar> ayarlariYukle() async {
  try {
    final prefs = SharedPreferencesAsync();
    final bitti = await prefs.getBool(_kOnboarding) ?? false;
    final tema = await prefs.getString(_kTema);
    final titresim = await prefs.getBool(_kTitresim) ?? true;
    final takmaAd = await prefs.getString(_kTakmaAd) ?? '';
    Titresim.acik = titresim;
    return Ayarlar(
      onboardingBitti: bitti,
      titresim: titresim,
      takmaAd: takmaAd,
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

  Future<void> titresimiAyarla(bool acik) async {
    Titresim.acik = acik;
    state = state.copyWith(titresim: acik);
    try {
      await SharedPreferencesAsync().setBool(_kTitresim, acik);
    } catch (_) {}
  }

  Future<void> takmaAdKaydet(String ad) async {
    final temiz = ad.trim();
    state = state.copyWith(takmaAd: temiz);
    try {
      await SharedPreferencesAsync().setString(_kTakmaAd, temiz);
    } catch (_) {}
  }

  /// Cihazdaki tüm yerel tercihleri ve kimliği siler; karşılama ekranına döner.
  Future<void> yerelVeriyiSil() async {
    try {
      await SharedPreferencesAsync().clear();
    } catch (_) {}
    Titresim.acik = true;
    state = const Ayarlar();
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
