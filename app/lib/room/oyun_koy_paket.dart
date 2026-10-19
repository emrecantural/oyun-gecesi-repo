import 'package:flutter/material.dart';

import 'oda_istemci.dart';

const rolSirasi = ['kurt', 'kahin', 'doktor', 'cadi', 'avci', 'asik', 'koylu'];
const rolEtiketi = {
  'kurt': 'Kurt',
  'kahin': 'Kâhin',
  'doktor': 'Doktor',
  'cadi': 'Cadı',
  'avci': 'Avcı',
  'asik': 'Âşık',
  'koylu': 'Köylü',
};

/// Sunucudaki varsayılan rol paketiyle aynı tablo (server/src/games/koyMotoru.ts).
Map<String, int> varsayilanPaket(int n) {
  final kurt = n <= 11 ? 2 : (n <= 15 ? 3 : (n <= 19 ? 4 : 5));
  final avci = n >= 8 ? 1 : 0;
  final asik = n >= 10 ? 2 : 0;
  final cadi = n >= 12 ? 1 : 0;
  final koylu = n - kurt - 1 - 1 - avci - asik - cadi;
  return {'kurt': kurt, 'kahin': 1, 'doktor': 1, 'cadi': cadi, 'avci': avci, 'asik': asik, 'koylu': koylu};
}

/// Kurucu için rol paketi düzenleyici (toplam oyuncu sayısına eşit olmalı).
Future<void> rolPaketiAc(BuildContext context, OdaIstemcisi i, int oyuncuSayisi) {
  final mevcut = (i.acik['rolePack'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt()));
  final paket = <String, int>{...(mevcut ?? varsayilanPaket(oyuncuSayisi < 6 ? 6 : oyuncuSayisi))};
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) {
        final toplam = rolSirasi.fold<int>(0, (t, r) => t + (paket[r] ?? 0));
        final tamam = toplam == oyuncuSayisi;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              Text('Rol paketi ($oyuncuSayisi oyuncu)', style: Theme.of(c).textTheme.titleMedium),
              for (final r in rolSirasi)
                Row(
                  children: [
                    Expanded(child: Text(rolEtiketi[r]!)),
                    IconButton(
                      tooltip: '${rolEtiketi[r]} azalt',
                      onPressed: (paket[r] ?? 0) > 0 ? () => setS(() => paket[r] = paket[r]! - 1) : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    SizedBox(width: 28, child: Text('${paket[r] ?? 0}', textAlign: TextAlign.center)),
                    IconButton(
                      tooltip: '${rolEtiketi[r]} artır',
                      onPressed: (paket[r] ?? 0) < 20 ? () => setS(() => paket[r] = (paket[r] ?? 0) + 1) : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              Text(
                tamam ? 'Toplam $toplam ✓' : 'Toplam $toplam; $oyuncuSayisi olmalı',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: tamam
                    ? () {
                        i.gonder('setRolePack', {'pack': paket});
                        Navigator.pop(c);
                      }
                    : null,
                child: const Text('Kaydet'),
              ),
              TextButton(
                onPressed: () {
                  i.gonder('setRolePack', {'pack': null});
                  Navigator.pop(c);
                },
                child: const Text('Varsayılana dön'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
