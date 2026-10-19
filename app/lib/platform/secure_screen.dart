import 'package:flutter/services.dart';

/// Android FLAG_SECURE: ekran görüntüsü / son uygulamalar önizlemesini engeller.
/// Kanal adı patch_android.py ile üretilen MainActivity'de tanımlıdır.
/// Birden çok gizli ekran üst üste açılırsa sayaçla yönetilir.
class EkranKorumasi {
  EkranKorumasi._();
  static const _kanal = MethodChannel('oyungecesi/secure_screen');
  static int _sayi = 0;

  static Future<void> ac() async {
    _sayi++;
    if (_sayi == 1) await _gonder('enable');
  }

  static Future<void> kapat() async {
    if (_sayi == 0) return;
    _sayi--;
    if (_sayi == 0) await _gonder('disable');
  }

  static Future<void> _gonder(String yontem) async {
    try {
      await _kanal.invokeMethod<void>(yontem);
    } on MissingPluginException {
      // Test ortamı veya platform kanalı yok: sessizce geç.
    } on PlatformException {
      // Koruma açılamadı; oyun akışı bozulmasın.
    }
  }
}
