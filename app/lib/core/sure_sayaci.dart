import 'dart:async';

import 'package:flutter/widgets.dart';

/// Yerel oyun süresi (A1): arka plana alınınca duraklar, dönünce kalan
/// süreyle devam eder. Süre mutlak bitiş anıyla değil kalan ms ile tutulur.
class SureSayaci extends ChangeNotifier with WidgetsBindingObserver {
  SureSayaci({this.aralik = const Duration(milliseconds: 100)}) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Duration aralik;
  Timer? _zamanlayici;
  final Stopwatch _saat = Stopwatch();
  int _toplamMs = 0;
  int _kalanOncekiMs = 0;
  bool _calisiyor = false;
  bool _arkaPlanda = false;
  VoidCallback? _bitince;

  bool get calisiyor => _calisiyor;
  int get toplamMs => _toplamMs;

  int get kalanMs {
    final gecen = _calisiyor && !_arkaPlanda ? _saat.elapsedMilliseconds : 0;
    final k = _kalanOncekiMs - gecen;
    return k < 0 ? 0 : k;
  }

  double get oran => _toplamMs == 0 ? 0 : kalanMs / _toplamMs;
  int get kalanSn => (kalanMs / 1000).ceil();

  void baslat(int ms, {VoidCallback? bitince}) {
    durdur();
    _toplamMs = ms;
    _kalanOncekiMs = ms;
    _bitince = bitince;
    _calisiyor = true;
    _saat
      ..reset()
      ..start();
    _zamanlayici = Timer.periodic(aralik, (_) => _tik());
    notifyListeners();
  }

  void _tik() {
    if (_arkaPlanda) return;
    if (kalanMs <= 0) {
      final cb = _bitince;
      durdur();
      cb?.call();
      return;
    }
    notifyListeners();
  }

  void durdur() {
    _zamanlayici?.cancel();
    _zamanlayici = null;
    _saat.stop();
    _calisiyor = false;
    _bitince = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_calisiyor) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_arkaPlanda) {
        _kalanOncekiMs = kalanMs;
        _saat
          ..stop()
          ..reset();
        _arkaPlanda = true;
      }
    } else if (state == AppLifecycleState.resumed && _arkaPlanda) {
      _arkaPlanda = false;
      _saat
        ..reset()
        ..start();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zamanlayici?.cancel();
    super.dispose();
  }
}
