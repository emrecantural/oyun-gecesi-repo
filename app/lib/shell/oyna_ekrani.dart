import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../games/oyun_uygulamalari.dart';
import 'ortak/oturum.dart';

/// Oyun kabuğu: çıkışta onay ister (geri tuşu / öngörülü geri dahil).
class OynaEkrani extends ConsumerWidget {
  const OynaEkrani({super.key, required this.oyunId});
  final String oyunId;

  Future<void> _cik(BuildContext context, WidgetRef ref) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkılsın mı?'),
        content: const Text('Çıkarsan oyun kaybolur.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Çık')),
        ],
      ),
    );
    if (onay == true && context.mounted) {
      ref.read(oturumProvider.notifier).bitir();
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oturum = ref.watch(oturumProvider);
    final uyg = oyunUygulamasi(oyunId);
    if (oturum == null || uyg == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Oyun bulunamadı.')),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cik(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Çık',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _cik(context, ref),
          ),
          title: Text(oturum.oyun.ad),
        ),
        body: SafeArea(child: uyg.ekran(context, oturum)),
      ),
    );
  }
}
