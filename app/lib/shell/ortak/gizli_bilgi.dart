import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../platform/secure_screen.dart';
import 'oyuncular.dart';
import '../../platform/titresim.dart';

/// Gizli bilgi gösteren ekranı sarar: açıkken FLAG_SECURE etkindir.
class GizliEkran extends StatefulWidget {
  const GizliEkran({super.key, required this.child});
  final Widget child;

  @override
  State<GizliEkran> createState() => _GizliEkranDurum();
}

class _GizliEkranDurum extends State<GizliEkran> {
  @override
  void initState() {
    super.initState();
    EkranKorumasi.ac();
  }

  @override
  void dispose() {
    EkranKorumasi.kapat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A16: "Telefon sırası: {ad}" + iki adımlı onay ("Sadece {ad} bakıyor mu?").
class GecisEkrani extends StatefulWidget {
  const GecisEkrani({
    super.key,
    required this.oyuncu,
    required this.onHazir,
    this.onGeri,
    this.geriMetni,
    this.ipucu,
  });

  final Oyuncu oyuncu;
  final VoidCallback onHazir;
  final VoidCallback? onGeri;
  final String? geriMetni;
  final String? ipucu;

  @override
  State<GecisEkrani> createState() => _GecisEkraniDurum();
}

class _GecisEkraniDurum extends State<GecisEkrani> {
  bool _onay = false;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final ad = widget.oyuncu.ad;
    return GizliEkran(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(child: OyuncuSimgesi(oyuncu: widget.oyuncu, boyut: 120)),
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              child: Text(
                'Telefon sırası: $ad',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _onay
                  ? 'Sadece $ad bakıyor mu?'
                  : (widget.ipucu ?? 'Telefonu ona ver. Hazır olunca dokun.'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: r.metinIkincil),
            ),
            const Spacer(),
            if (!_onay)
              FilledButton(
                onPressed: () => setState(() => _onay = true),
                child: const Text('Hazırım'),
              )
            else ...[
              FilledButton(
                onPressed: widget.onHazir,
                child: const Text('Evet, sadece ben'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => setState(() => _onay = false),
                child: const Text('Geri'),
              ),
            ],
            if (widget.onGeri != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onGeri,
                child: Text(widget.geriMetni ?? '$ad değil'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// CardFlip: basılı tut → göster, bırak → 150 ms içinde gizle (A12).
/// Parmak yokken açık kalan kart 3 sn'de, basılıyken [azamiAcikSn] sonra kapanır.
/// Ekran okuyucu açıkken basılı tutma yerine uyarı + "Göster" düğmesi gösterilir
/// (A7); Göster ile açılan kart [srAcikSn] sonra kapanır.
class BasiliTutKart extends StatefulWidget {
  const BasiliTutKart({
    super.key,
    required this.acik,
    this.kapaliEtiket = 'Gizli kart',
    this.ipucu = 'Basılı tuttuğun sürece görünür.',
    this.azamiAcikSn = 20,
    this.srAcikSn = 10,
    this.minBasmaMs = 0,
    this.acildi,
  });

  final WidgetBuilder acik;
  final String kapaliEtiket;
  final String ipucu;
  final int azamiAcikSn;
  final int srAcikSn;
  final int minBasmaMs;

  /// Kart ilk karede göründüğünde bir kez çağrılır.
  final VoidCallback? acildi;

  @override
  State<BasiliTutKart> createState() => _BasiliTutKartDurum();
}

class _BasiliTutKartDurum extends State<BasiliTutKart>
    with WidgetsBindingObserver {
  bool _gorunur = false;
  bool _basili = false;
  Timer? _azami;
  Timer? _bekle;
  Timer? _otoKapat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _gizle();
  }

  void _goster() {
    if (_gorunur) return;
    setState(() => _gorunur = true);
    Titresim.hafif();
    widget.acildi?.call();
    _azami?.cancel();
    _azami = Timer(Duration(seconds: widget.azamiAcikSn), _gizle);
  }

  void _gizle() {
    _azami?.cancel();
    _bekle?.cancel();
    _otoKapat?.cancel();
    _basili = false;
    if (_gorunur && mounted) setState(() => _gorunur = false);
  }

  void _basildi() {
    _basili = true;
    _bekle?.cancel();
    if (widget.minBasmaMs <= 0) {
      _goster();
    } else {
      _bekle = Timer(Duration(milliseconds: widget.minBasmaMs), () {
        if (_basili) _goster();
      });
    }
  }

  void _birakildi() {
    _basili = false;
    _bekle?.cancel();
    // Parmak yokken açık kalma üst sınırı: 3 sn (bırakma kaçırılırsa).
    _otoKapat?.cancel();
    if (_gorunur) {
      _otoKapat = Timer(const Duration(milliseconds: 150), _gizle);
    }
  }

  void _srGoster() {
    _goster();
    _otoKapat?.cancel();
    _otoKapat = Timer(Duration(seconds: widget.srAcikSn), _gizle);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _azami?.cancel();
    _bekle?.cancel();
    _otoKapat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final ekranOkuyucu = MediaQuery.of(context).accessibleNavigation;
    final kart = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _gorunur ? r.yuzey : r.yukseltilmis,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: r.ana, width: 3),
      ),
      child: _gorunur
          ? widget.acik(context)
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_off_rounded,
                      size: 48, color: r.metinIkincil),
                  const SizedBox(height: 8),
                  Text(widget.kapaliEtiket,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(widget.ipucu,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: r.metinIkincil)),
                ],
              ),
            ),
    );
    if (ekranOkuyucu) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_gorunur) ...[
            const Text(
              'Ekran okuyucu bu bilgiyi yüksek sesle okur. Kulaklık tak veya etrafı kontrol et.',
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _srGoster, child: const Text('Göster')),
          ] else
            Semantics(liveRegion: true, child: kart),
        ],
      );
    }
    return Semantics(
      label: '${widget.kapaliEtiket}: göstermek için basılı tut',
      onLongPress: _srGoster,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _basildi(),
        onPointerUp: (_) => _birakildi(),
        onPointerCancel: (_) => _birakildi(),
        child: kart,
      ),
    );
  }
}
