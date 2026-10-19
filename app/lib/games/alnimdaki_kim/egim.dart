import 'dart:math';

enum EgimOlayi { dogru, pas }

/// 29 eğim algılama (alnimdaki-kim tam tasarım §3). Saf mantık: ivmeölçer örneklerini işler.
/// θ = atan2(z, √(x²+y²)); kararlı 1 sn'de θ0 alınır. θ ≤ θ0−35° (öne) ≥600 ms → doğru;
/// θ ≥ θ0+35° (arkaya) ≥600 ms → pas. Tetik sonrası ≥1 sn bekleme ve θ0±15° içine ≥300 ms dönüş şartı.
class EgimTespitcisi {
  EgimTespitcisi({
    this.esik = 35,
    this.tutmaMs = 600,
    this.beklemeMs = 1000,
    this.donusMs = 300,
    this.donusEsik = 15,
    this.kararliMs = 1000,
    this.kararliSapma = 4,
  });

  final double esik;
  final int tutmaMs;
  final int beklemeMs;
  final int donusMs;
  final double donusEsik;
  final int kararliMs;
  final double kararliSapma;

  double? _teta0;
  int? _kalBasi;
  double _kalMin = 0;
  double _kalMax = 0;
  double _kalToplam = 0;
  int _kalSayi = 0;

  int _yon = 0; // -1 öne, +1 arkaya
  int? _tutBasi;
  bool _kilitli = false;
  int _sonTetik = 0;
  int? _donusBasi;

  bool get hazir => _teta0 != null;
  double? get teta0 => _teta0;

  static double aci(double x, double y, double z) => atan2(z, sqrt(x * x + y * y)) * 180 / pi;

  /// Bir ivmeölçer örneği (m/s²) ve zaman damgası (ms). Tetik varsa döner.
  EgimOlayi? isle(double x, double y, double z, int tMs) {
    final teta = aci(x, y, z);
    final t0 = _teta0;
    if (t0 == null) {
      _kalibreEt(teta, tMs);
      return null;
    }
    final goreli = teta - t0;
    if (_kilitli) {
      if (goreli.abs() <= donusEsik) {
        _donusBasi ??= tMs;
        if (tMs - _donusBasi! >= donusMs && tMs - _sonTetik >= beklemeMs) {
          _kilitli = false;
          _donusBasi = null;
        }
      } else {
        _donusBasi = null;
      }
      return null;
    }
    final yon = goreli <= -esik ? -1 : (goreli >= esik ? 1 : 0);
    if (yon == 0) {
      _yon = 0;
      _tutBasi = null;
      return null;
    }
    if (yon != _yon) {
      _yon = yon;
      _tutBasi = tMs;
      return null;
    }
    if (tMs - _tutBasi! >= tutmaMs) {
      _kilitli = true;
      _sonTetik = tMs;
      _donusBasi = null;
      _yon = 0;
      _tutBasi = null;
      return yon < 0 ? EgimOlayi.dogru : EgimOlayi.pas;
    }
    return null;
  }

  void _kalibreEt(double teta, int tMs) {
    final basi = _kalBasi;
    if (basi == null) {
      _kalYenidenBaslat(teta, tMs);
      return;
    }
    final min = teta < _kalMin ? teta : _kalMin;
    final max = teta > _kalMax ? teta : _kalMax;
    if (max - min > kararliSapma) {
      _kalYenidenBaslat(teta, tMs);
      return;
    }
    _kalMin = min;
    _kalMax = max;
    _kalToplam += teta;
    _kalSayi++;
    if (tMs - basi >= kararliMs) _teta0 = _kalToplam / _kalSayi;
  }

  void _kalYenidenBaslat(double teta, int tMs) {
    _kalBasi = tMs;
    _kalMin = teta;
    _kalMax = teta;
    _kalToplam = teta;
    _kalSayi = 1;
  }
}
