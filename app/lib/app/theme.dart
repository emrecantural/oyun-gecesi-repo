import 'package:flutter/material.dart';

/// design.md §2 renk tokenları (açık / koyu).
@immutable
class OyunRenkleri extends ThemeExtension<OyunRenkleri> {
  const OyunRenkleri({
    required this.zemin,
    required this.yuzey,
    required this.yukseltilmis,
    required this.ana,
    required this.ikincil,
    required this.vurgu,
    required this.nane,
    required this.mor,
    required this.metin,
    required this.metinIkincil,
    required this.tehlike,
    required this.uyari,
  });

  final Color zemin;
  final Color yuzey;
  final Color yukseltilmis;
  final Color ana;
  final Color ikincil;
  final Color vurgu;
  final Color nane;
  final Color mor;
  final Color metin;
  final Color metinIkincil;
  final Color tehlike;
  final Color uyari;

  static const acik = OyunRenkleri(
    zemin: Color(0xFFFFF8EF),
    yuzey: Color(0xFFFFFFFF),
    yukseltilmis: Color(0xFFFFF1DC),
    ana: Color(0xFFFF5A4E),
    ikincil: Color(0xFF2F6BFF),
    vurgu: Color(0xFFFFC233),
    nane: Color(0xFF22C9A0),
    mor: Color(0xFF8A5CFF),
    metin: Color(0xFF231F3B),
    metinIkincil: Color(0xFF6B6787),
    tehlike: Color(0xFFE5384B),
    uyari: Color(0xFFFF9F1C),
  );

  static const koyu = OyunRenkleri(
    zemin: Color(0xFF14122B),
    yuzey: Color(0xFF1F1C3D),
    yukseltilmis: Color(0xFF2A2650),
    ana: Color(0xFFFF7A70),
    ikincil: Color(0xFF6E97FF),
    vurgu: Color(0xFFFFD466),
    nane: Color(0xFF4FE0BB),
    mor: Color(0xFFA88BFF),
    metin: Color(0xFFFFF8EF),
    metinIkincil: Color(0xFFB6B1D6),
    tehlike: Color(0xFFFF6B7A),
    uyari: Color(0xFFFFB84D),
  );

  @override
  OyunRenkleri copyWith({
    Color? zemin,
    Color? yuzey,
    Color? yukseltilmis,
    Color? ana,
    Color? ikincil,
    Color? vurgu,
    Color? nane,
    Color? mor,
    Color? metin,
    Color? metinIkincil,
    Color? tehlike,
    Color? uyari,
  }) {
    return OyunRenkleri(
      zemin: zemin ?? this.zemin,
      yuzey: yuzey ?? this.yuzey,
      yukseltilmis: yukseltilmis ?? this.yukseltilmis,
      ana: ana ?? this.ana,
      ikincil: ikincil ?? this.ikincil,
      vurgu: vurgu ?? this.vurgu,
      nane: nane ?? this.nane,
      mor: mor ?? this.mor,
      metin: metin ?? this.metin,
      metinIkincil: metinIkincil ?? this.metinIkincil,
      tehlike: tehlike ?? this.tehlike,
      uyari: uyari ?? this.uyari,
    );
  }

  @override
  OyunRenkleri lerp(ThemeExtension<OyunRenkleri>? other, double t) {
    if (other is! OyunRenkleri) return this;
    return OyunRenkleri(
      zemin: Color.lerp(zemin, other.zemin, t)!,
      yuzey: Color.lerp(yuzey, other.yuzey, t)!,
      yukseltilmis: Color.lerp(yukseltilmis, other.yukseltilmis, t)!,
      ana: Color.lerp(ana, other.ana, t)!,
      ikincil: Color.lerp(ikincil, other.ikincil, t)!,
      vurgu: Color.lerp(vurgu, other.vurgu, t)!,
      nane: Color.lerp(nane, other.nane, t)!,
      mor: Color.lerp(mor, other.mor, t)!,
      metin: Color.lerp(metin, other.metin, t)!,
      metinIkincil: Color.lerp(metinIkincil, other.metinIkincil, t)!,
      tehlike: Color.lerp(tehlike, other.tehlike, t)!,
      uyari: Color.lerp(uyari, other.uyari, t)!,
    );
  }
}

extension OyunRenkleriErisim on BuildContext {
  OyunRenkleri get renkler => Theme.of(this).extension<OyunRenkleri>()!;
}

ThemeData _tema(OyunRenkleri r, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: r.ana,
    brightness: brightness,
  ).copyWith(
    primary: r.ana,
    secondary: r.ikincil,
    tertiary: r.vurgu,
    surface: r.yuzey,
    onSurface: r.metin,
    error: r.tehlike,
    // Birincil düğme üstü metin: açık temada beyaz, koyu temada koyu zemin.
    onPrimary: brightness == Brightness.light ? Colors.white : r.zemin,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: r.zemin,
    extensions: [r],
    appBarTheme: AppBarTheme(
      backgroundColor: r.zemin,
      foregroundColor: r.metin,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: r.yuzey,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    textTheme: Typography.material2021().black.apply(
          bodyColor: r.metin,
          displayColor: r.metin,
        ),
    visualDensity: VisualDensity.standard,
  );
}

ThemeData acikTema() => _tema(OyunRenkleri.acik, Brightness.light);
ThemeData koyuTema() => _tema(OyunRenkleri.koyu, Brightness.dark);
