import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../games/oyun_uygulamalari.dart';
import '../games/registry.dart';
import '../monetization/reklam_servisi.dart';
import '../room/oda_ekranlari.dart';

/// M06: oyun detayı.
class OyunDetayEkrani extends StatelessWidget {
  const OyunDetayEkrani({super.key, required this.oyunId});
  final String oyunId;

  @override
  Widget build(BuildContext context) {
    final oyun = oyunBul(oyunId);
    if (oyun == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Oyun bulunamadı.')),
      );
    }
    final r = context.renkler;
    return Scaffold(
      appBar: AppBar(title: Text(oyun.ad)),
      bottomNavigationBar: const ReklamBandi(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Icon(oyun.ikon, size: 88, color: r.ana)),
              const SizedBox(height: 24),
              Text(oyun.kisa,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  Chip(label: Text(oyun.kategori.ad)),
                  Chip(label: Text(oyun.kisiAraligi)),
                  if (oyun.sadeceOda) const Chip(label: Text('Sadece oda')),
                ],
              ),
              const Spacer(),
              if (oyunUygulamasi(oyun.id) != null && !oyun.sadeceOda)
                FilledButton(
                  onPressed: () => context.push('/oyun/${oyun.id}/oyuncular'),
                  child: const Text('Bu cihazda oyna'),
                ),
              if (odaOyunlari.contains(oyun.id)) ...[
                if (oyunUygulamasi(oyun.id) != null && !oyun.sadeceOda)
                  const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => context.push('/oyun/${oyun.id}/oda'),
                  child: const Text('Oda kur (herkes kendi telefonunda)'),
                ),
              ],
              if (oyunUygulamasi(oyun.id) == null && !odaOyunlari.contains(oyun.id))
                const FilledButton(
                  onPressed: null,
                  child: Text('Yakında'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
