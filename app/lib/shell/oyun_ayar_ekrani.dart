import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../games/oyun_uygulamalari.dart';
import '../games/oyun_uygulamasi.dart';
import '../games/registry.dart';
import 'ortak/oturum.dart';

/// G4: oyun ayarları. Seçimler cihazda oturum süresince tutulur.
class OyunAyarEkrani extends ConsumerStatefulWidget {
  const OyunAyarEkrani({super.key, required this.oyunId});
  final String oyunId;

  @override
  ConsumerState<OyunAyarEkrani> createState() => _OyunAyarEkraniState();
}

class _OyunAyarEkraniState extends ConsumerState<OyunAyarEkrani> {
  late final Map<String, String> _secim;
  bool _gelismisAcik = false;

  OyunUygulamasi? get _uyg => oyunUygulamasi(widget.oyunId);

  @override
  void initState() {
    super.initState();
    _secim = {
      for (final a in _uyg?.ayarlar ?? const <AyarSatiri>[])
        a.anahtar: a.varsayilan,
    };
  }

  void _baslat() {
    final OyunBilgisi? oyun = oyunBul(widget.oyunId);
    if (oyun == null) return;
    ref.read(oturumProvider.notifier).baslat(OyunOturumu(
          oyun: oyun,
          oyuncular: ref.read(masaProvider),
          ayarlar: Map.of(_secim),
        ));
    context.go('/oyun/${widget.oyunId}/oyna');
  }

  Widget _satir(AyarSatiri a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.baslik, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in a.secenekler.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _secim[a.anahtar] == e.key,
                  onSelected: (_) => setState(() => _secim[a.anahtar] = e.key),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uyg = _uyg;
    final ana = uyg?.ayarlar.where((a) => !a.gelismis).toList() ?? const [];
    final gelismis = uyg?.ayarlar.where((a) => a.gelismis).toList() ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final a in ana) _satir(a),
                  if (gelismis.isNotEmpty)
                    ExpansionTile(
                      title: const Text('Gelişmiş'),
                      initiallyExpanded: _gelismisAcik,
                      onExpansionChanged: (v) => _gelismisAcik = v,
                      tilePadding: EdgeInsets.zero,
                      children: [for (final a in gelismis) _satir(a)],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: uyg == null ? null : _baslat,
                  child: const Text('Başlat'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
