import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../shell/ortak/oyuncular.dart';
import 'oda_istemci.dart';

/// Odadaki oyuncuyu yerel oyuncu simgesine çevirir.
Oyuncu simgeOyuncu(OdaIstemcisi i, String id) {
  final liste = i.oyuncular;
  for (var n = 0; n < liste.length; n++) {
    if (liste[n].id == id) {
      return Oyuncu(id: n + 1, ad: liste[n].takmaAd, stilNo: liste[n].stil % oyuncuStilleri.length);
    }
  }
  return const Oyuncu(id: 0, ad: '?', stilNo: 0);
}

String oyuncuAdi(OdaIstemcisi i, String? id) {
  if (id == null) return '—';
  return i.oyuncu(id)?.takmaAd ?? '?';
}

/// Sunucu saatine göre kalan süreyi sayar (faz bitişi yoksa gizlenir).
class GeriSayim extends StatefulWidget {
  const GeriSayim({super.key, required this.istemci});
  final OdaIstemcisi istemci;

  @override
  State<GeriSayim> createState() => _GeriSayimDurum();
}

class _GeriSayimDurum extends State<GeriSayim> {
  Timer? _z;

  @override
  void initState() {
    super.initState();
    _z = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _z?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.istemci.kalanMs;
    if (k == null) return const SizedBox.shrink();
    final sn = (k / 1000).ceil();
    final r = context.renkler;
    return Semantics(
      label: '$sn saniye kaldı',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: r.yukseltilmis,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$sn sn', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Oyuncu seçme ızgarası (oylama, hedef seçimi).
class OyuncuSecici extends StatelessWidget {
  const OyuncuSecici({
    super.key,
    required this.istemci,
    required this.idler,
    required this.secili,
    required this.onSec,
    this.etkin = true,
  });
  final OdaIstemcisi istemci;
  final List<String> idler;
  final String? secili;
  final void Function(String id) onSec;
  final bool etkin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final id in idler)
          Semantics(
            button: true,
            selected: id == secili,
            label: oyuncuAdi(istemci, id),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: etkin ? () => onSec(id) : null,
              child: Container(
                width: 92,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: id == secili ? r.ana : r.yukseltilmis,
                    width: id == secili ? 3 : 1.5,
                  ),
                  color: id == secili ? r.yukseltilmis : r.yuzey,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OyuncuSimgesi(oyuncu: simgeOyuncu(istemci, id), boyut: 44),
                    const SizedBox(height: 4),
                    Text(
                      oyuncuAdi(istemci, id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Sonuç/final satırı: oyuncu + değer.
class SonucSatiri extends StatelessWidget {
  const SonucSatiri({
    super.key,
    required this.istemci,
    required this.id,
    required this.metin,
    this.oran,
    this.vurgu = false,
  });
  final OdaIstemcisi istemci;
  final String id;
  final String metin;
  final double? oran;
  final bool vurgu;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          OyuncuSimgesi(oyuncu: simgeOyuncu(istemci, id), boyut: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oyuncuAdi(istemci, id),
                  style: TextStyle(fontWeight: vurgu ? FontWeight.w800 : FontWeight.w600),
                ),
                if (oran != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(
                      value: oran,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: vurgu ? r.ana : r.ikincil,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(metin, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

const rozetAdlari = {
  'favorite': 'Favori',
  'honest': 'Dürüst',
  'generous': 'Cömert',
  'lucky': 'Şanslı',
  'lastMinute': 'Son dakika',
  'bestLiar': 'En iyi yalancı',
  'skeptic': 'Şüpheci',
};

/// `[{badge, playerIds}]` listesini gösterir.
class RozetListesi extends StatelessWidget {
  const RozetListesi({super.key, required this.istemci, required this.rozetler});
  final OdaIstemcisi istemci;
  final List<dynamic> rozetler;

  @override
  Widget build(BuildContext context) {
    if (rozetler.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in rozetler)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${rozetAdlari[(b as Map)['badge']] ?? b['badge']}: '
              '${((b['playerIds'] as List?) ?? const []).map((x) => oyuncuAdi(istemci, x as String)).join(', ')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
      ],
    );
  }
}
