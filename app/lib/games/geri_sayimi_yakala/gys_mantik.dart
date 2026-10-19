import 'dart:math';

/// 18 Geri Sayımı Yakala — saf puanlama mantığı.

class GysSira {
  const GysSira({
    required this.oyuncuId,
    required this.sapmaMs,
    required this.sira,
    required this.puan,
  });
  final int oyuncuId;

  /// Hedefe göre işaretli sapma (ms): negatif = erken, pozitif = geç.
  /// Dokunmayan için null.
  final double? sapmaMs;

  /// 1'den başlar; dokunmayan için 0.
  final int sira;
  final int puan;

  bool get uyudu => sapmaMs == null;
}

const _puanTablosu = [5, 3, 2];

/// Dokunuş sapmalarını sıralar ve puanlar.
/// Sıralama: 1.→5, 2.→3, 3.→2, diğerleri 1, dokunmayan 0.
/// Beraberlik: aynı grubun ilk elemanından [esikMs] veya daha az uzak olanlar
/// aynı sırayı/puanı alır; sonraki grup, önceki grup boyu kadar sıra atlar.
List<GysSira> turPuanla({
  required Map<int, double?> sapmalar,
  double esikMs = 16,
}) {
  final dokunanlar = [
    for (final e in sapmalar.entries)
      if (e.value != null) (id: e.key, dev: e.value!),
  ]..sort((a, b) => a.dev.abs().compareTo(b.dev.abs()));

  final sonuc = <GysSira>[];
  var i = 0;
  while (i < dokunanlar.length) {
    final lider = dokunanlar[i].dev.abs();
    var j = i;
    while (j < dokunanlar.length && dokunanlar[j].dev.abs() - lider <= esikMs) {
      j++;
    }
    final sira = i + 1;
    final puan = sira <= _puanTablosu.length ? _puanTablosu[sira - 1] : 1;
    for (var k = i; k < j; k++) {
      sonuc.add(GysSira(
        oyuncuId: dokunanlar[k].id,
        sapmaMs: dokunanlar[k].dev,
        sira: sira,
        puan: puan,
      ));
    }
    i = j;
  }
  for (final e in sapmalar.entries) {
    if (e.value == null) {
      sonuc.add(GysSira(oyuncuId: e.key, sapmaMs: null, sira: 0, puan: 0));
    }
  }
  return sonuc;
}

/// Beraberlik eşiği: ≥2× dokunma örnekleme aralığı, en az 5 ms.
double beraberlikEsigi(double ornekAraligiMs) => max(5, 2 * ornekAraligiMs);

class GysOyuncuToplam {
  GysOyuncuToplam(this.oyuncuId);
  final int oyuncuId;
  int puan = 0;
  int dokunulanTur = 0;
  double toplamMutlakSapma = 0;
  double enBuyukErken = 0; // pozitif sayı: ms erken

  double? get ortalamaSapma =>
      dokunulanTur == 0 ? null : toplamMutlakSapma / dokunulanTur;
}

class GysOyunu {
  GysOyunu({required List<int> oyuncuIdleri, required this.turSayisi, this.esikMs = 16})
      : toplamlar = {for (final id in oyuncuIdleri) id: GysOyuncuToplam(id)};

  final int turSayisi;
  final double esikMs;
  final Map<int, GysOyuncuToplam> toplamlar;
  final List<List<GysSira>> turlar = [];

  bool get bitti => turlar.length >= turSayisi;

  List<GysSira> turBitir(Map<int, double?> sapmalar) {
    final sonuc = turPuanla(sapmalar: sapmalar, esikMs: esikMs);
    for (final s in sonuc) {
      final t = toplamlar[s.oyuncuId]!;
      t.puan += s.puan;
      if (s.sapmaMs != null) {
        t.dokunulanTur++;
        t.toplamMutlakSapma += s.sapmaMs!.abs();
        if (s.sapmaMs! < 0 && -s.sapmaMs! > t.enBuyukErken) {
          t.enBuyukErken = -s.sapmaMs!;
        }
      }
    }
    turlar.add(sonuc);
    return sonuc;
  }

  /// Puana göre sıralı (eşit puan: ortalama sapması düşük önde).
  List<GysOyuncuToplam> get siralama {
    final l = toplamlar.values.toList()
      ..sort((a, b) {
        final p = b.puan.compareTo(a.puan);
        if (p != 0) return p;
        return (a.ortalamaSapma ?? double.infinity)
            .compareTo(b.ortalamaSapma ?? double.infinity);
      });
    return l;
  }

  /// Zaman Ustası: en düşük ortalama sapma, en az yarı tur dokunmuş.
  int? get zamanUstasi {
    final adaylar = toplamlar.values
        .where((t) => t.dokunulanTur * 2 >= max(1, turlar.length) && t.dokunulanTur > 0)
        .toList()
      ..sort((a, b) => a.ortalamaSapma!.compareTo(b.ortalamaSapma!));
    return adaylar.isEmpty ? null : adaylar.first.oyuncuId;
  }

  /// Kuş Gibi: en büyük erken sapma.
  int? get kusGibi {
    final adaylar = toplamlar.values.where((t) => t.enBuyukErken > 0).toList()
      ..sort((a, b) => b.enBuyukErken.compareTo(a.enBuyukErken));
    return adaylar.isEmpty ? null : adaylar.first.oyuncuId;
  }
}
