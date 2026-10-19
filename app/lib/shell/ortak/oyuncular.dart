import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ui-tasarimi.md §4: 12 renk + şekil (kimlik şekil + numara ile verilir).
class OyuncuStili {
  const OyuncuStili(this.ad, this.renk, this.sekil, {this.koyuMetin = false});
  final String ad;
  final Color renk;
  final OyuncuSekli sekil;
  final bool koyuMetin;
}

enum OyuncuSekli {
  daire,
  kare,
  ucgen,
  yildiz,
  dortgen,
  altigen,
  arti,
  damla,
  besgen,
  ay,
  yarimDaire,
  kalp,
}

const oyuncuStilleri = <OyuncuStili>[
  OyuncuStili('Turuncu', Color(0xFFE69F00), OyuncuSekli.daire, koyuMetin: true),
  OyuncuStili('Gök mavisi', Color(0xFF56B4E9), OyuncuSekli.kare, koyuMetin: true),
  OyuncuStili('Yeşil', Color(0xFF009E73), OyuncuSekli.ucgen),
  OyuncuStili('Sarı', Color(0xFFF0E442), OyuncuSekli.yildiz, koyuMetin: true),
  OyuncuStili('Mavi', Color(0xFF0072B2), OyuncuSekli.dortgen),
  OyuncuStili('Kırmızımsı', Color(0xFFD55E00), OyuncuSekli.altigen),
  OyuncuStili('Pembe-mor', Color(0xFFCC79A7), OyuncuSekli.arti),
  OyuncuStili('Gri', Color(0xFF8C8C8C), OyuncuSekli.damla),
  OyuncuStili('Deniz yeşili', Color(0xFF00A7B5), OyuncuSekli.besgen),
  OyuncuStili('Koyu mor', Color(0xFF6A3FB5), OyuncuSekli.ay),
  OyuncuStili('Limon yeşili', Color(0xFF8FBF2A), OyuncuSekli.yarimDaire,
      koyuMetin: true),
  OyuncuStili('Bordo', Color(0xFFA3243B), OyuncuSekli.kalp),
];

class Oyuncu {
  const Oyuncu({required this.id, required this.ad, required this.stilNo});

  /// Oturum içinde tekil (1'den başlar; 13+ oyuncuda numara tekil kalır).
  final int id;
  final String ad;
  final int stilNo;

  OyuncuStili get stil => oyuncuStilleri[stilNo % oyuncuStilleri.length];

  Oyuncu adiDegistir(String yeni) =>
      Oyuncu(id: id, ad: yeni, stilNo: stilNo);

  /// Çipte en çok 12 karakter; ekran okuyucu tam adı okur.
  String get kisaAd => ad.length <= 12 ? ad : '${ad.substring(0, 11)}…';
}

/// Aynı ad ikinci kez girilirse "Ayşe 2" yapar (G2).
String benzersizAd(String ad, Iterable<String> mevcut) {
  final temiz = ad.trim();
  final kume = mevcut.toSet();
  if (!kume.contains(temiz)) return temiz;
  var n = 2;
  while (kume.contains('$temiz $n')) {
    n++;
  }
  return '$temiz $n';
}

/// Şekil + numara içeren avatar (renk yalnız pekiştirici).
class OyuncuSimgesi extends StatelessWidget {
  const OyuncuSimgesi({super.key, required this.oyuncu, this.boyut = 40});
  final Oyuncu oyuncu;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    final stil = oyuncu.stil;
    final metinRenk = stil.koyuMetin ? const Color(0xFF231F3B) : Colors.white;
    return ExcludeSemantics(
      child: SizedBox(
        width: boyut,
        height: boyut,
        child: CustomPaint(
          painter: _SekilBoyayici(stil.sekil, stil.renk),
          child: Center(
            child: Text(
              '${oyuncu.id}',
              style: TextStyle(
                color: metinRenk,
                fontWeight: FontWeight.w800,
                fontSize: boyut * 0.38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SekilBoyayici extends CustomPainter {
  _SekilBoyayici(this.sekil, this.renk);
  final OyuncuSekli sekil;
  final Color renk;

  @override
  void paint(Canvas canvas, Size size) {
    final boya = Paint()..color = renk;
    canvas.drawPath(sekilYolu(sekil, size), boya);
  }

  @override
  bool shouldRepaint(_SekilBoyayici eski) =>
      eski.sekil != sekil || eski.renk != renk;
}

Path _cokgen(Size s, int kose, {double donme = -math.pi / 2}) {
  final c = Offset(s.width / 2, s.height / 2);
  final r = s.shortestSide / 2;
  final p = Path();
  for (var i = 0; i < kose; i++) {
    final a = donme + 2 * math.pi * i / kose;
    final nokta = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    if (i == 0) {
      p.moveTo(nokta.dx, nokta.dy);
    } else {
      p.lineTo(nokta.dx, nokta.dy);
    }
  }
  return p..close();
}

Path sekilYolu(OyuncuSekli sekil, Size s) {
  final w = s.width;
  final h = s.height;
  final c = Offset(w / 2, h / 2);
  final r = s.shortestSide / 2;
  switch (sekil) {
    case OyuncuSekli.daire:
      return Path()..addOval(Rect.fromCircle(center: c, radius: r));
    case OyuncuSekli.kare:
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromCircle(center: c, radius: r * 0.9),
            Radius.circular(r * 0.18)));
    case OyuncuSekli.ucgen:
      return Path()
        ..moveTo(w / 2, h * 0.04)
        ..lineTo(w * 0.97, h * 0.92)
        ..lineTo(w * 0.03, h * 0.92)
        ..close();
    case OyuncuSekli.yildiz:
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + math.pi * i / 5;
        final rr = i.isEven ? r : r * 0.5;
        final n = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
        if (i == 0) {
          p.moveTo(n.dx, n.dy);
        } else {
          p.lineTo(n.dx, n.dy);
        }
      }
      return p..close();
    case OyuncuSekli.dortgen:
      return _cokgen(s, 4);
    case OyuncuSekli.altigen:
      return _cokgen(s, 6, donme: 0);
    case OyuncuSekli.arti:
      final k = r * 0.36;
      return Path()
        ..addRect(Rect.fromCenter(center: c, width: 2 * r, height: 2 * k))
        ..addRect(Rect.fromCenter(center: c, width: 2 * k, height: 2 * r));
    case OyuncuSekli.damla:
      return Path()
        ..moveTo(w / 2, h * 0.02)
        ..cubicTo(w * 0.95, h * 0.5, w * 0.9, h * 0.97, w / 2, h * 0.97)
        ..cubicTo(w * 0.1, h * 0.97, w * 0.05, h * 0.5, w / 2, h * 0.02)
        ..close();
    case OyuncuSekli.besgen:
      return _cokgen(s, 5);
    case OyuncuSekli.ay:
      final dis = Path()..addOval(Rect.fromCircle(center: c, radius: r));
      final ic = Path()
        ..addOval(Rect.fromCircle(
            center: Offset(c.dx + r * 0.45, c.dy - r * 0.2), radius: r * 0.8));
      return Path.combine(PathOperation.difference, dis, ic);
    case OyuncuSekli.yarimDaire:
      return Path()
        ..moveTo(w * 0.04, h * 0.7)
        ..arcToPoint(Offset(w * 0.96, h * 0.7),
            radius: Radius.circular(r * 0.92))
        ..close();
    case OyuncuSekli.kalp:
      return Path()
        ..moveTo(w / 2, h * 0.92)
        ..cubicTo(w * -0.1, h * 0.55, w * 0.15, h * 0.02, w / 2, h * 0.3)
        ..cubicTo(w * 0.85, h * 0.02, w * 1.1, h * 0.55, w / 2, h * 0.92)
        ..close();
  }
}

/// Kısa çip: simge + ad (+ isteğe bağlı alt yazı).
class OyuncuCipi extends StatelessWidget {
  const OyuncuCipi({
    super.key,
    required this.oyuncu,
    this.altYazi,
    this.secili = false,
    this.pasif = false,
    this.onTap,
    this.rozet,
  });

  final Oyuncu oyuncu;
  final String? altYazi;
  final bool secili;
  final bool pasif;
  final VoidCallback? onTap;
  final Widget? rozet;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      button: onTap != null,
      label: '${oyuncu.ad}${altYazi == null ? '' : ', $altYazi'}',
      child: Opacity(
        opacity: pasif ? 0.45 : 1,
        child: Material(
          color: secili
              ? tema.colorScheme.primary.withValues(alpha: 0.18)
              : tema.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: secili
                  ? tema.colorScheme.primary
                  : tema.colorScheme.outlineVariant,
              width: secili ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: pasif ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OyuncuSimgesi(oyuncu: oyuncu, boyut: 36),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(oyuncu.kisaAd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          if (altYazi != null)
                            Text(altYazi!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tema.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (rozet != null) ...[const SizedBox(width: 6), rozet!],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
