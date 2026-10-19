/// Tırnak ve virgül destekleyen küçük CSV ayrıştırıcı (RFC 4180 alt kümesi).
/// İlk satır başlıktır; her satır başlık→değer haritasına çevrilir.
List<Map<String, String>> csvAyristir(String metin) {
  final satirlar = _hucreler(metin);
  if (satirlar.isEmpty) return const [];
  final baslik = satirlar.first.map((h) => h.trim()).toList();
  final sonuc = <Map<String, String>>[];
  for (final s in satirlar.skip(1)) {
    if (s.length == 1 && s.first.trim().isEmpty) continue;
    final harita = <String, String>{};
    for (var i = 0; i < baslik.length; i++) {
      harita[baslik[i]] = i < s.length ? s[i] : '';
    }
    sonuc.add(harita);
  }
  return sonuc;
}

List<List<String>> _hucreler(String girdi) {
  final metin = girdi.startsWith('﻿') ? girdi.substring(1) : girdi;
  final satirlar = <List<String>>[];
  var satir = <String>[];
  final hucre = StringBuffer();
  var tirnakta = false;

  void hucreBitir() {
    satir.add(hucre.toString());
    hucre.clear();
  }

  void satirBitir() {
    hucreBitir();
    satirlar.add(satir);
    satir = <String>[];
  }

  for (var i = 0; i < metin.length; i++) {
    final c = metin[i];
    if (tirnakta) {
      if (c == '"') {
        if (i + 1 < metin.length && metin[i + 1] == '"') {
          hucre.write('"');
          i++;
        } else {
          tirnakta = false;
        }
      } else {
        hucre.write(c);
      }
    } else if (c == '"') {
      tirnakta = true;
    } else if (c == ',') {
      hucreBitir();
    } else if (c == '\n') {
      satirBitir();
    } else if (c == '\r') {
      // \r\n çiftinde \n işler.
    } else {
      hucre.write(c);
    }
  }
  if (hucre.isNotEmpty || satir.isNotEmpty) satirBitir();
  return satirlar;
}
