import 'package:flutter/services.dart';

/// Titreşim geri bildirimi; Ayarlar'daki anahtar [acik] değerini değiştirir.
class Titresim {
  Titresim._();

  static bool acik = true;

  static void hafif() {
    if (acik) HapticFeedback.lightImpact();
  }

  static void orta() {
    if (acik) HapticFeedback.mediumImpact();
  }

  static void agir() {
    if (acik) HapticFeedback.heavyImpact();
  }

  static void secim() {
    if (acik) HapticFeedback.selectionClick();
  }
}
