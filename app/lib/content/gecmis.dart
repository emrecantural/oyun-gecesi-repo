import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cihazda 30 gün saklanan "görülen kart" ve kalıcı "bildirilen kart" listesi (A2).
class GecmisDeposu {
  GecmisDeposu({SharedPreferencesAsync? prefs, DateTime Function()? simdi})
      : _prefs = prefs,
        _simdi = simdi ?? DateTime.now;

  final SharedPreferencesAsync? _prefs;
  final DateTime Function() _simdi;
  static const _gun = 30;

  SharedPreferencesAsync get _p => _prefs ?? SharedPreferencesAsync();

  int get _bugun => _simdi().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  Future<Set<String>> gorulenler(String oyun) async {
    try {
      final ham = await _p.getString('gorulen_$oyun');
      if (ham == null) return {};
      final harita = (jsonDecode(ham) as Map).cast<String, dynamic>();
      return {
        for (final e in harita.entries)
          if (_bugun - (e.value as int) <= _gun) e.key,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> gorulenleriKaydet(String oyun, Set<String> idler) async {
    try {
      final harita = {for (final id in idler) id: _bugun};
      await _p.setString('gorulen_$oyun', jsonEncode(harita));
    } catch (_) {}
  }

  Future<Set<String>> bildirilenler(String oyun) async {
    try {
      final liste = await _p.getStringList('bildirilen_$oyun');
      return liste?.toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<void> bildir(String oyun, String id) async {
    try {
      final var_ = await bildirilenler(oyun);
      var_.add(id);
      await _p.setStringList('bildirilen_$oyun', var_.toList());
    } catch (_) {}
  }
}
