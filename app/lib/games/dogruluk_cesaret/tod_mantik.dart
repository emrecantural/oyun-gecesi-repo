import 'dart:math';

import '../../shell/ortak/oyuncular.dart';

enum TodTur { dogruluk, cesaret }

enum TodAsama { siraSec, secim, kart, yap, bitti }

enum TodSonuc { tamam, pas, joker, alternatif, gecildi }

enum TodSira { sise, sirayla, kura }

class TodKart {
  const TodKart({
    required this.id,
    required this.tur,
    required this.metin,
    required this.grup,
    required this.fiziksel,
  });
  final String id;
  final TodTur tur;
  final String metin;
  final bool grup;
  final bool fiziksel;
}

/// Kart kaynağı: tür için sıradaki kart; [alternatif] true ise (Pas hakkı yokken)
/// fiziksel olmayan ve tek kişilik hafif kart istenir. Bulunamazsa null.
typedef TodKartCek = TodKart? Function(TodTur tur, {bool alternatif});

class TodAyar {
  const TodAyar({
    required this.sira,
    required this.pas,
    required this.joker,
    required this.gorevSn,
    required this.kartHedefi,
  });
  final TodSira sira;
  final int pas;
  final int joker;

  /// 0 = süre kapalı.
  final int gorevSn;

  /// 0 = sınırsız.
  final int kartHedefi;
}

class TodOyuncuDurumu {
  TodOyuncuDurumu(this.oyuncu, {required int pas, required int joker})
      : pasKalan = pas,
        jokerKalan = joker;
  final Oyuncu oyuncu;
  int pasKalan;
  int jokerKalan;
  int dogruluk = 0;
  int cesaret = 0;
  int tamamlanan = 0;
}

class TodKayit {
  const TodKayit(this.oyuncuId, this.kartId, this.tur, this.sonuc);
  final int oyuncuId;
  final String kartId;
  final TodTur tur;
  final TodSonuc sonuc;
}

/// 06 Doğruluk mu Cesaret mi — saf oyun mantığı.
class TodOyunu {
  TodOyunu({
    required List<Oyuncu> oyuncular,
    required this.ayar,
    required this.kartCek,
    Random? rastgele,
  })  : _rng = rastgele ?? Random(),
        durumlar = [
          for (final o in oyuncular)
            TodOyuncuDurumu(o, pas: ayar.pas, joker: ayar.joker),
        ];

  final TodAyar ayar;
  final TodKartCek kartCek;
  final Random _rng;
  final List<TodOyuncuDurumu> durumlar;
  final List<TodKayit> gecmis = [];

  TodAsama asama = TodAsama.siraSec;
  int? siraId;
  int? gorevSahibiId;
  TodKart? kart;
  TodTur? secilenTur;
  int oynanan = 0;
  int _sirayIndex = -1;
  final List<int> _torba = [];

  TodOyuncuDurumu durum(int id) => durumlar.firstWhere((d) => d.oyuncu.id == id);
  Oyuncu get siradaki => durum(siraId!).oyuncu;
  Oyuncu get gorevSahibi => durum(gorevSahibiId ?? siraId!).oyuncu;
  bool get devredildi => gorevSahibiId != null && gorevSahibiId != siraId;
  int get tamamlananToplam => durumlar.fold(0, (a, d) => a + d.tamamlanan);

  /// SIRA_SEC: sıradaki oyuncuyu belirler (şişe sonucu önce RNG ile seçilir).
  int siraCek() {
    if (asama != TodAsama.siraSec) throw StateError('NOT_IN_PHASE');
    final idler = durumlar.map((d) => d.oyuncu.id).toList();
    int sec;
    switch (ayar.sira) {
      case TodSira.sirayla:
        _sirayIndex = (_sirayIndex + 1) % idler.length;
        sec = idler[_sirayIndex];
      case TodSira.kura:
        if (_torba.isEmpty) _torba.addAll(idler..shuffle(_rng));
        sec = _torba.removeAt(0);
        if (sec == siraId && idler.length > 1 && _torba.isNotEmpty) {
          // Torba yenilenince aynı kişi art arda gelmesin.
          final yedek = _torba.removeAt(0);
          _torba.add(sec);
          sec = yedek;
        }
      case TodSira.sise:
        if (idler.length == 2 && siraId != null) {
          sec = idler.firstWhere((i) => i != siraId);
        } else {
          do {
            sec = idler[_rng.nextInt(idler.length)];
          } while (sec == siraId && idler.length > 1);
        }
    }
    siraId = sec;
    gorevSahibiId = null;
    kart = null;
    secilenTur = null;
    asama = TodAsama.secim;
    return sec;
  }

  /// SECIM: Doğruluk/Cesaret (süre dolunca UI Doğruluk seçer).
  void sec(TodTur tur) {
    if (asama != TodAsama.secim) throw StateError('NOT_IN_PHASE');
    final k = kartCek(tur);
    if (k == null) throw StateError('DECK_EMPTY');
    final d = durum(siraId!);
    if (tur == TodTur.dogruluk) {
      d.dogruluk++;
    } else {
      d.cesaret++;
    }
    secilenTur = tur;
    kart = k;
    asama = ayar.gorevSn > 0 ? TodAsama.kart : TodAsama.yap;
  }

  /// KART: görev süresi için Başla.
  void basla() {
    if (asama != TodAsama.kart) throw StateError('NOT_IN_PHASE');
    asama = TodAsama.yap;
  }

  bool get jokerKullanilabilir {
    if (asama != TodAsama.yap && asama != TodAsama.kart) return false;
    final k = kart;
    if (k == null || secilenTur != TodTur.cesaret || k.grup) return false;
    if (devredildi) return false;
    return durum(siraId!).jokerKalan > 0 && jokerAdaylari.isNotEmpty;
  }

  List<Oyuncu> get jokerAdaylari => [
        for (final d in durumlar)
          if (d.oyuncu.id != siraId) d.oyuncu,
      ];

  /// Pas: hak varsa aynı türde yeni kart; yoksa "Yapamıyorum" alternatifi.
  void pas() {
    if (asama != TodAsama.yap && asama != TodAsama.kart) {
      throw StateError('NOT_IN_PHASE');
    }
    final d = durum(siraId!);
    final eski = kart!;
    if (d.pasKalan > 0) {
      final yeni = kartCek(secilenTur!);
      if (yeni == null) throw StateError('DECK_EMPTY');
      d.pasKalan--;
      gecmis.add(TodKayit(d.oyuncu.id, eski.id, secilenTur!, TodSonuc.pas));
      kart = yeni;
    } else {
      final karsi = secilenTur == TodTur.cesaret ? TodTur.dogruluk : TodTur.cesaret;
      final yeni = kartCek(karsi, alternatif: karsi == TodTur.cesaret) ??
          kartCek(TodTur.dogruluk);
      if (yeni == null) throw StateError('DECK_EMPTY');
      gecmis.add(
          TodKayit(d.oyuncu.id, eski.id, secilenTur!, TodSonuc.alternatif));
      secilenTur = yeni.tur;
      kart = yeni;
    }
  }

  void joker(int hedefId) {
    if (!jokerKullanilabilir) throw StateError('NO_JOKER_LEFT');
    if (hedefId == siraId || !durumlar.any((d) => d.oyuncu.id == hedefId)) {
      throw StateError('NO_TARGET');
    }
    durum(siraId!).jokerKalan--;
    gorevSahibiId = hedefId;
    gecmis.add(TodKayit(siraId!, kart!.id, secilenTur!, TodSonuc.joker));
  }

  /// Tamam: görev sahibi (devralan olabilir) tamamladı.
  void tamam() {
    if (asama != TodAsama.yap) throw StateError('NOT_IN_PHASE');
    final sahip = durum(gorevSahibiId ?? siraId!);
    sahip.tamamlanan++;
    gecmis.add(TodKayit(sahip.oyuncu.id, kart!.id, secilenTur!, TodSonuc.tamam));
    _turBitti();
  }

  /// Geç: yalnız devralan için; hak harcamaz, tamamlanmış sayılmaz.
  void gec() {
    if (asama != TodAsama.yap || !devredildi) throw StateError('NOT_IN_PHASE');
    gecmis.add(TodKayit(gorevSahibiId!, kart!.id, secilenTur!, TodSonuc.gecildi));
    _turBitti();
  }

  void _turBitti() {
    oynanan++;
    if (ayar.kartHedefi > 0 && oynanan >= ayar.kartHedefi) {
      asama = TodAsama.bitti;
    } else {
      asama = TodAsama.siraSec;
    }
  }

  void bitir() => asama = TodAsama.bitti;

  /// Oyuncu ayrılır; sıra ondaysa yeniden çekilir. Kalan <2 ise `false` (DURAKLAT).
  bool oyuncuCikar(int id) {
    durumlar.removeWhere((d) => d.oyuncu.id == id);
    _torba.remove(id);
    if (siraId == id || gorevSahibiId == id) {
      siraId = null;
      gorevSahibiId = null;
      kart = null;
      asama = TodAsama.siraSec;
    }
    return durumlar.length >= 2;
  }

  List<Oyuncu> get enCesurlar => _enCok((d) => d.cesaret);
  List<Oyuncu> get durustler => _enCok((d) => d.dogruluk);

  List<Oyuncu> _enCok(int Function(TodOyuncuDurumu) f) {
    final enCok = durumlar.fold<int>(0, (a, d) => max(a, f(d)));
    if (enCok == 0) return const [];
    return [for (final d in durumlar) if (f(d) == enCok) d.oyuncu];
  }
}
