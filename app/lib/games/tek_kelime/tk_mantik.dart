import '../../core/tr_text.dart';

/// Normalleştirme: foldTr + yalnız a-z0-9.
String tkNorm(String s) => foldTr(s).replaceAll(RegExp(r'[^a-z0-9]'), '');

// foldTr sonrası ekler (i/ı → i, ü/u → u ...). Uzundan kısaya denenir.
const _ekler = [
  'lardan', 'lerden', 'larin', 'lerin', 'lara', 'lere', 'lari', 'leri',
  'lar', 'ler', 'mak', 'mek', 'dan', 'den', 'tan', 'ten', 'nin', 'nun',
  'lik', 'luk', 'siz', 'suz', 'ici', 'ma', 'me', 'da', 'de', 'ta', 'te',
  'ci', 'cu', 'si', 'su', 'in', 'un', 'yi', 'yu', 'a', 'e', 'i', 'u',
];

/// En uzun ek eşleşmesini kırpar; kök ≥ 2 harf kalmalı.
String tkKok(String norm) {
  for (final ek in _ekler) {
    if (norm.endsWith(ek) && norm.length - ek.length >= 2) {
      return norm.substring(0, norm.length - ek.length);
    }
  }
  return norm;
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var onceki = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final su = List<int>.filled(b.length + 1, 0);
    su[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final m = a[i - 1] == b[j - 1] ? 0 : 1;
      su[j] = [onceki[j] + 1, su[j - 1] + 1, onceki[j - 1] + m]
          .reduce((x, y) => x < y ? x : y);
    }
    onceki = su;
  }
  return onceki[b.length];
}

/// Aynı say: norm eşit, kökler eşit ya da (≥4 harf iken) Levenshtein ≤ 1.
bool tkAyni(String a, String b) {
  final na = tkNorm(a), nb = tkNorm(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  if (tkKok(na) == tkKok(nb)) return true;
  if (na.length >= 4 && nb.length >= 4 && levenshtein(na, nb) <= 1) return true;
  return false;
}

/// Şüpheli: aynı değil ama ortak ilk ≥ 4 harf.
bool tkSupheli(String a, String b) {
  if (tkAyni(a, b)) return false;
  final na = tkNorm(a), nb = tkNorm(b);
  if (na.length < 4 || nb.length < 4) return false;
  return na.substring(0, 4) == nb.substring(0, 4);
}

enum IpucuHatasi { bos, sayiVeyaHarf, kelimeninKendisi, yasakKok, cokKelime, uzun }

/// Yazma anı doğrulaması. [yasakKokler]: CSV `ek` köklerinden.
IpucuHatasi? tkIpucuDogrula(String ham, String kelime, List<String> yasakKokler) {
  final t = ham.trim();
  if (t.isEmpty) return IpucuHatasi.bos;
  if (t.contains(RegExp(r'\s'))) return IpucuHatasi.cokKelime;
  if (t.length > 24) return IpucuHatasi.uzun;
  if (t.contains(RegExp(r'[0-9]')) || tkNorm(t).length < 2) return IpucuHatasi.sayiVeyaHarf;
  if (tkAyni(t, kelime)) return IpucuHatasi.kelimeninKendisi;
  for (final k in yasakKokler) {
    if (k.trim().isNotEmpty && tkAyni(t, k)) return IpucuHatasi.yasakKok;
  }
  return null;
}

bool tkTahminDogru(String tahmin, String kelime) => tkAyni(tahmin, kelime);

class Ipucu {
  Ipucu(this.yazarId, this.ham);
  final int yazarId;
  final String ham;
  bool silindi = false;
}

class EleGrubu {
  EleGrubu(this.idx, this.durum);
  final List<int> idx; // ipucu indeksleri
  String durum; // auto | suspect
  bool aynidir = false; // şüpheli için oyuncu kararı
}

/// Otomatik eleme: aynı olanlar (grup) silinir; şüpheliler karar bekler.
List<EleGrubu> tkEle(List<Ipucu> ipuclari) {
  final n = ipuclari.length;
  final ebeveyn = List<int>.generate(n, (i) => i);
  int bul(int x) => ebeveyn[x] == x ? x : ebeveyn[x] = bul(ebeveyn[x]);
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      if (tkAyni(ipuclari[i].ham, ipuclari[j].ham)) ebeveyn[bul(j)] = bul(i);
    }
  }
  final gruplar = <int, List<int>>{};
  for (var i = 0; i < n; i++) {
    gruplar.putIfAbsent(bul(i), () => []).add(i);
  }
  final sonuc = <EleGrubu>[];
  final tekler = <int>[];
  for (final g in gruplar.values) {
    if (g.length >= 2) {
      sonuc.add(EleGrubu(g, 'auto'));
      for (final i in g) {
        ipuclari[i].silindi = true;
      }
    } else {
      tekler.add(g.first);
    }
  }
  final kullanildi = <int>{};
  for (var a = 0; a < tekler.length; a++) {
    if (kullanildi.contains(tekler[a])) continue;
    final grup = [tekler[a]];
    for (var b = a + 1; b < tekler.length; b++) {
      if (!kullanildi.contains(tekler[b]) &&
          tkSupheli(ipuclari[tekler[a]].ham, ipuclari[tekler[b]].ham)) {
        grup.add(tekler[b]);
      }
    }
    if (grup.length >= 2) {
      kullanildi.addAll(grup);
      sonuc.add(EleGrubu(grup, 'suspect'));
    }
  }
  return sonuc;
}

/// Şüpheli grup kararı uygulanır: aynıysa silinir.
void tkSupheliUygula(List<Ipucu> ipuclari, List<EleGrubu> gruplar) {
  for (final g in gruplar.where((g) => g.durum == 'suspect' && g.aynidir)) {
    for (final i in g.idx) {
      ipuclari[i].silindi = true;
    }
  }
}

enum KartSonucu { dogru, yanlis, pas, atlandi }

class TekKelimeOyunu {
  TekKelimeOyunu({
    required this.oyuncuIdleri,
    required this.kartSayisi,
    this.pasHakki = 1,
  }) : _pasKalan = pasHakki;

  final List<int> oyuncuIdleri;
  final int kartSayisi;
  final int pasHakki;
  int _pasKalan;
  final List<KartSonucu> sonuclar = [];
  int _tahminciSirasi = 0;

  int get pasKalan => _pasKalan;
  int get tahminciId => oyuncuIdleri[_tahminciSirasi % oyuncuIdleri.length];
  int get dogruSayisi => sonuclar.where((s) => s == KartSonucu.dogru).length;

  /// Kullanılan kart (doğru/yanlış/pas/atlanan) toplamı.
  int get ilerleme => sonuclar.length;
  bool get bitti => sonuclar.length >= kartSayisi;

  bool pasKullanabilir() => _pasKalan > 0;

  /// Sonucu işler. Yanlışta sonraki kart da atılır. Tüm ipuçları silindiyse
  /// [otomatikPas] ile hak harcanmadan pas yazılır.
  void kartiBitir(KartSonucu s, {bool otomatikPas = false}) {
    if (bitti) return;
    switch (s) {
      case KartSonucu.dogru:
        sonuclar.add(KartSonucu.dogru);
      case KartSonucu.yanlis:
        sonuclar.add(KartSonucu.yanlis);
        if (!bitti) sonuclar.add(KartSonucu.atlandi);
      case KartSonucu.pas:
        if (!otomatikPas) {
          if (_pasKalan <= 0) throw StateError('PASS_EXHAUSTED');
          _pasKalan--;
        }
        sonuclar.add(KartSonucu.pas);
      case KartSonucu.atlandi:
        sonuclar.add(KartSonucu.atlandi);
    }
    _tahminciSirasi++;
  }

  static String derece(int dogru, int toplam) {
    final oran = toplam == 0 ? 0 : dogru / toplam;
    if (dogru >= toplam && toplam > 0) return 'Mükemmel!';
    if (oran >= 10 / 13) return 'Harika';
    if (oran >= 7 / 13) return 'İyi takım';
    return 'Daha çok çalışın';
  }
}
