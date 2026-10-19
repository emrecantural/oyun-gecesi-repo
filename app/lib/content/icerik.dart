import '../core/csv.dart';

/// İçerik CSV'sindeki bir satır (icerik/README.md şeması).
class IcerikOgesi {
  const IcerikOgesi({
    required this.id,
    required this.oyun,
    required this.tur,
    required this.seviye,
    required this.metin,
    required this.ek,
    required this.fiziksel,
    required this.grup,
    required this.risk,
    required this.durum,
    this.ucretsiz = false,
  });

  final String id;
  final String oyun;
  final String tur;
  final String seviye;
  final String metin;
  final String ek;
  final bool fiziksel;
  final bool grup;
  final String risk;
  final String durum;

  /// Paket planına göre (D-045) ücretsiz havuzda mı?
  final bool ucretsiz;

  /// `ek` alanını dikey çizgi (|) ile böler (Blöf, Bilgi Yarışması vb.).
  List<String> get ekParcalar =>
      ek.isEmpty ? const [] : ek.split('|').map((e) => e.trim()).toList();

  IcerikOgesi ucretsizIsaretli(bool deger) => IcerikOgesi(
        id: id,
        oyun: oyun,
        tur: tur,
        seviye: seviye,
        metin: metin,
        ek: ek,
        fiziksel: fiziksel,
        grup: grup,
        risk: risk,
        durum: durum,
        ucretsiz: deger,
      );
}

/// CSV metnini öğelere çevirir. [taslakDahil] false ise yalnız `onayli` kalır.
/// Ücretsiz bölme: her grupta (varsayılan `seviye`) id sırasının ilk
/// `min(n, max(5, ⌈0,4·n⌉))` öğesi (paket-plani.md).
List<IcerikOgesi> icerikAyristir(
  String csv, {
  required bool taslakDahil,
  String Function(IcerikOgesi)? grupAnahtari,
}) {
  final satirlar = csvAyristir(csv);
  final hepsi = <IcerikOgesi>[];
  for (final s in satirlar) {
    final durum = (s['durum'] ?? '').trim();
    if (durum == 'reddedildi') continue;
    if (!taslakDahil && durum != 'onayli') continue;
    final id = (s['id'] ?? '').trim();
    final metin = (s['metin'] ?? '').trim();
    if (id.isEmpty || metin.isEmpty) continue;
    hepsi.add(IcerikOgesi(
      id: id,
      oyun: (s['oyun'] ?? '').trim(),
      tur: (s['tur'] ?? '').trim(),
      seviye: (s['seviye'] ?? '').trim(),
      metin: metin,
      ek: (s['ek'] ?? '').trim(),
      fiziksel: (s['fiziksel'] ?? '').trim() == '1',
      grup: (s['grup'] ?? '').trim() == '1',
      risk: (s['risk'] ?? '').trim(),
      durum: durum,
    ));
  }
  return ucretsizBol(hepsi, grupAnahtari: grupAnahtari);
}

int ucretsizSayisi(int n) {
  if (n <= 0) return 0;
  final hedef = (0.4 * n).ceil();
  final alt = hedef < 5 ? 5 : hedef;
  return n < alt ? n : alt;
}

List<IcerikOgesi> ucretsizBol(
  List<IcerikOgesi> liste, {
  String Function(IcerikOgesi)? grupAnahtari,
}) {
  final anahtar = grupAnahtari ?? (IcerikOgesi o) => o.seviye;
  final gruplar = <String, List<IcerikOgesi>>{};
  for (final o in liste) {
    gruplar.putIfAbsent(anahtar(o), () => []).add(o);
  }
  final ucretsizIdler = <String>{};
  for (final g in gruplar.values) {
    for (final o in g.take(ucretsizSayisi(g.length))) {
      ucretsizIdler.add(o.id);
    }
  }
  return [
    for (final o in liste) o.ucretsizIsaretli(ucretsizIdler.contains(o.id)),
  ];
}
