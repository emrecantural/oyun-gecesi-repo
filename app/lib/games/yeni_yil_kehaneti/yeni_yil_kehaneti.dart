import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../content/icerik_deposu.dart';
import '../../shell/ortak/gizli_bilgi.dart';
import '../../shell/ortak/oturum.dart';
import '../../shell/ortak/oyuncular.dart';
import '../oyun_uygulamasi.dart';
import 'kehanet_mantik.dart';

const _dosya = '23-yeni-yil-kehaneti';
const _anahtar = 'kehanet_kapsul';

final yeniYilKehaneti = OyunUygulamasi(
  id: '23',
  ayarlar: const [
    AyarSatiri(
      anahtar: 'adet',
      baslik: 'Tahmin / kişi',
      secenekler: {'1': '1', '2': '2', '3': '3', '5': '5', '7': '7'},
      varsayilan: '3',
    ),
    AyarSatiri(
      anahtar: 'gorunurluk',
      baslik: 'Görünürlük',
      secenekler: {'grup': 'Grup', 'anonim': 'Anonim'},
      varsayilan: 'grup',
    ),
  ],
  ekran: (context, oturum) => YeniYilKehaneti(oturum: oturum),
);

enum _Asama { yukleniyor, mevcut, tarih, gecis, yaz, bekle, oyla, sonuc }

class YeniYilKehaneti extends ConsumerStatefulWidget {
  const YeniYilKehaneti({super.key, required this.oturum});
  final OyunOturumu oturum;

  @override
  ConsumerState<YeniYilKehaneti> createState() => _KehanetDurum();
}

class _KehanetDurum extends ConsumerState<YeniYilKehaneti> {
  _Asama _asama = _Asama.yukleniyor;
  Kapsul? _k;
  Kapsul? _eski;
  bool _anonim = false;
  DateTime _acilis = varsayilanAcilis(DateTime.now());
  int _uyeIdx = 0;
  int _yuzde = 50;
  String? _hata;
  final _metin = TextEditingController();
  List<String> _ilhamHavuzu = const [];
  int _ilhamSayac = 0;

  // oylama
  List<Tahmin> _kartlar = const [];
  int _kart = 0;
  final _oy = [0, 0, 0];
  final Map<int, Karar> _kararlar = {};

  OyunOturumu get _o => widget.oturum;
  List<Oyuncu> get _p => _o.oyuncular;

  @override
  void initState() {
    super.initState();
    _anonim = _o.ayar('gorunurluk') == 'anonim';
    _baslat();
  }

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  Future<void> _baslat() async {
    try {
      final ham = await SharedPreferencesAsync().getString(_anahtar);
      if (ham != null) {
        _eski = Kapsul.fromJson((jsonDecode(ham) as Map).cast<String, dynamic>());
      }
    } catch (_) {}
    try {
      final tum = await ref.read(icerikProvider(_dosya).future);
      _ilhamHavuzu = tum.map((e) => e.metin).toList();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _asama = _eski != null ? _Asama.mevcut : _Asama.tarih);
  }

  Future<void> _kaydet() async {
    try {
      final k = _k;
      if (k == null) return;
      await SharedPreferencesAsync().setString(_anahtar, jsonEncode(k.toJson()));
    } catch (_) {}
  }

  Future<void> _sil() async {
    try {
      await SharedPreferencesAsync().remove(_anahtar);
    } catch (_) {}
  }

  void _kapsulKur() {
    final tohum = Random.secure().nextInt(0x7FFFFFFF);
    _k = Kapsul(
      uyeler: [for (final p in _p) Uye(id: p.id, ad: p.ad)],
      tahminSayisi: _o.ayarInt('adet'),
      acilis: _acilis,
      tohum: tohum,
    );
    _uyeIdx = 0;
    _asama = _Asama.gecis;
    setState(() {});
  }

  Future<void> _tarihSec() async {
    final simdi = DateTime.now();
    final g = await showDatePicker(
      context: context,
      initialDate: _acilis,
      firstDate: simdi,
      lastDate: DateTime(simdi.year + 3),
    );
    if (g == null || !mounted) return;
    final s = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_acilis));
    if (s == null || !mounted) return;
    setState(() => _acilis = DateTime(g.year, g.month, g.day, s.hour, s.minute));
  }

  bool get _tarihGecerli =>
      _acilis.isAfter(DateTime.now().add(const Duration(hours: 1)));

  String _tarihYaz(DateTime d) {
    const aylar = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    String iki(int n) => n.toString().padLeft(2, '0');
    return '${d.day} ${aylar[d.month - 1]} ${d.year} · ${iki(d.hour)}:${iki(d.minute)}';
  }

  // ---- yazım ----
  void _ilham() {
    if (_ilhamHavuzu.isEmpty) return;
    final k = _k!;
    final uye = k.uyeler[_uyeIdx];
    final sirali = karistir(_ilhamHavuzu, tohumKarma(k.tohum, 'ilham${uye.id}'));
    final i = _ilhamSayac % sirali.length;
    _ilhamSayac++;
    setState(() {
      _metin.text = sirali[i];
      _hata = i == sirali.length - 1 ? 'Hepsini gördün, baştan başlıyoruz.' : null;
    });
  }

  void _tahminEkle() {
    final k = _k!;
    final uye = k.uyeler[_uyeIdx];
    try {
      k.ekle(uye.id, _metin.text, _yuzde);
      _metin.clear();
      _hata = null;
      _yuzde = 50;
      HapticFeedback.selectionClick();
    } on KapsulHatasi catch (e) {
      _hata = switch (e.kod) {
        'E_TEXT_EMPTY' => 'Önce bir tahmin yaz.',
        'E_TEXT_LONG' => 'En fazla 140 karakter.',
        'E_TEXT_BLOCKED' => 'Bu konu kapsülde olmasın. Daha eğlenceli bir tahmin yaz.',
        _ => 'Bu kişi için tahmin sayısı doldu.',
      };
    }
    setState(() {});
  }

  Future<void> _muhurle() async {
    final k = _k!;
    final uye = k.uyeler[_uyeIdx];
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mühürlensin mi?'),
        content: const Text('Mühürledikten sonra değişmez ve silinmez.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Mühürle')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    k.muhurle(uye.id);
    _metin.clear();
    if (_uyeIdx + 1 < k.uyeler.length) {
      _uyeIdx++;
      _asama = _Asama.gecis;
    } else {
      k.kapat();
      await _kaydet();
      _asama = _Asama.bekle;
    }
    setState(() {});
  }

  // ---- açılış ----
  void _acilisBaslat() {
    final k = _k!;
    _kartlar = k.acilisSirasi(DateTime.now());
    _kart = 0;
    _kararlar.clear();
    _oy.fillRange(0, 3, 0);
    _asama = _kartlar.isEmpty ? _Asama.sonuc : _Asama.oyla;
    setState(() {});
  }

  void _kararVer() {
    final t = _kartlar[_kart];
    _kararlar[t.id] = kararVer(_oy[0], _oy[1], _oy[2]);
    _oy.fillRange(0, 3, 0);
    if (_kart + 1 >= _kartlar.length) {
      _asama = _Asama.sonuc;
    } else {
      _kart++;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final govde = switch (_asama) {
      _Asama.yukleniyor => const Center(child: CircularProgressIndicator()),
      _Asama.mevcut => _mevcut(),
      _Asama.tarih => _tarihEkrani(),
      _Asama.gecis => _gecis(),
      _Asama.yaz => _yaz(),
      _Asama.bekle => _bekle(),
      _Asama.oyla => _oyla(),
      _Asama.sonuc => _sonuc(),
    };
    return Container(color: r.zemin, child: govde);
  }

  Widget _not(BuildContext c) => Text('Eğlence amaçlıdır; fal değildir.',
      textAlign: TextAlign.center, style: TextStyle(color: c.renkler.metinIkincil));

  Widget _mevcut() {
    final e = _eski!;
    final vakti = e.acilabilir(DateTime.now());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.auto_awesome_rounded, size: 72, color: context.renkler.mor),
          const SizedBox(height: 16),
          Text('Bu cihazda bir kapsül var',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(vakti ? 'Açılış zamanı geldi.' : 'Açılış: ${_tarihYaz(e.acilis)}',
              textAlign: TextAlign.center),
          const Spacer(),
          FilledButton(
            onPressed: () {
              _k = e;
              setState(() => _asama = e.kapandi ? _Asama.bekle : _Asama.gecis);
              if (!e.kapandi) {
                _uyeIdx = e.uyeler.indexWhere((u) => !u.muhurlu);
                if (_uyeIdx < 0) _uyeIdx = 0;
              }
            },
            child: Text(vakti ? 'Aç' : 'Kapsüle bak'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _yeniKapsulOnay,
            child: const Text('Sil ve yenisini kur'),
          ),
          const SizedBox(height: 8),
          _not(context),
        ],
      ),
    );
  }

  Future<void> _yeniKapsulOnay() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kapsül silinsin mi?'),
        content: const Text('Mühürlü tahminler kalıcı olarak silinir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    await _sil();
    setState(() {
      _eski = null;
      _asama = _Asama.tarih;
    });
  }

  Widget _tarihEkrani() {
    final saat = _acilis.difference(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Kapsül ayarları', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        _not(context),
        const SizedBox(height: 16),
        Text('Açılış: ${_tarihYaz(_acilis)}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ActionChip(
            label: const Text('31 Aralık 23:00'),
            onPressed: () => setState(() => _acilis = varsayilanAcilis(DateTime.now())),
          ),
          ActionChip(label: const Text('Özel…'), onPressed: _tarihSec),
        ]),
        if (!_tarihGecerli)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Açılış en az 1 saat sonrası olmalı.',
                style: TextStyle(color: context.renkler.tehlike)),
          ),
        const SizedBox(height: 16),
        Text(
            '${_p.length} kişi · kişi başı ${_o.ayarInt('adet')} tahmin'
            '${_p.length == 1 ? ' · Kişisel' : ''}'
            '${_anonim ? ' · Anonim' : ''}'),
        Text('Yaklaşık yazım ${_p.length * _o.ayarInt('adet')} dk, '
            'açılış ${((_p.length * _o.ayarInt('adet') * 15) / 60).ceil()} dk.',
            style: TextStyle(color: context.renkler.metinIkincil)),
        if (saat.inDays > 0) Text('Açılışa ${saat.inDays} gün var.'),
        const SizedBox(height: 8),
        Text(
          'Açılış günü hatırlatma bildirimi bu sürümde yok; açılış gününde uygulamayı kendin aç. '
          'Tahminler bu cihazda saklanır.',
          style: TextStyle(color: context.renkler.metinIkincil),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _tarihGecerli ? _kapsulKur : null,
          child: const Text('Devam'),
        ),
      ],
    );
  }

  Widget _gecis() {
    final k = _k!;
    final u = k.uyeler[_uyeIdx];
    final p = _p.firstWhere((p) => p.id == u.id);
    return GecisEkrani(
      oyuncu: p,
      ipucu: 'Tahminlerini yalnız sen göreceksin.',
      onHazir: () => setState(() => _asama = _Asama.yaz),
    );
  }

  Widget _yaz() {
    final k = _k!;
    final u = k.uyeler[_uyeIdx];
    final mevcut = k.taslak(u.id);
    final n = k.tahminSayisi;
    final tamam = mevcut.length == n;
    return GizliEkran(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${u.ad} · ${mevcut.length}/$n tahmin',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final t in mevcut)
            Card(
              child: ListTile(
                title: Text(t.metin),
                subtitle: Text('%${t.yuzde}'),
                trailing: IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => k.sil(t.id)),
                ),
              ),
            ),
          if (!tamam) ...[
            TextField(
              controller: _metin,
              maxLength: 140,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bu yıl biri…',
                border: OutlineInputBorder(),
              ),
            ),
            OutlinedButton(onPressed: _ilham, child: const Text('İlham ver')),
            const SizedBox(height: 8),
            Text('Ne kadar eminsin? %$_yuzde'),
            Row(children: [
              IconButton(
                tooltip: 'Azalt',
                onPressed: _yuzde > 10 ? () => setState(() => _yuzde -= 10) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Slider(
                  value: _yuzde.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 9,
                  label: '%$_yuzde',
                  onChanged: (v) => setState(() => _yuzde = v.round()),
                ),
              ),
              IconButton(
                tooltip: 'Artır',
                onPressed: _yuzde < 100 ? () => setState(() => _yuzde += 10) : null,
                icon: const Icon(Icons.add),
              ),
            ]),
            if (_hata != null)
              Text(_hata!, style: TextStyle(color: context.renkler.tehlike)),
            Text('Eğlenceli tut; ciddi konulardan uzak dur.',
                style: TextStyle(color: context.renkler.metinIkincil)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _tahminEkle, child: const Text('Tahmini ekle')),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Tüm tahminler hazır.'),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: tamam ? _muhurle : null,
            child: Text('Mühürle (${mevcut.length}/$n)'),
          ),
        ],
      ),
    );
  }

  Widget _bekle() {
    final k = _k!;
    final kalan = k.acilis.difference(DateTime.now());
    final vakti = k.acilabilir(DateTime.now());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.lock_clock_rounded, size: 72, color: context.renkler.mor),
          const SizedBox(height: 12),
          Text('Kapsül mühürlendi',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(vakti
              ? 'Zarflar hazır. Herkes toplandı mı?'
              : kalan.inDays > 0
                  ? 'Açılışa ${kalan.inDays} gün'
                  : 'Daha ${max(1, kalan.inHours)} saat var.',
              textAlign: TextAlign.center),
          Text(_tarihYaz(k.acilis), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Mühürlenen: ${k.uyeler.where((u) => u.muhurlu).length} / ${k.uyeler.length}',
              textAlign: TextAlign.center),
          const Spacer(),
          FilledButton(
            onPressed: vakti ? _acilisBaslat : null,
            child: const Text('Açalım'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              ref.read(oturumProvider.notifier).bitir();
              context.go('/');
            },
            child: const Text('Ana sayfa'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _yeniKapsulOnay, child: const Text('Kapsülü sil')),
          _not(context),
        ],
      ),
    );
  }

  String _yazarAdi(Tahmin t) {
    if (_anonim) return 'Yazar: gizli';
    return 'Yazar: ${_k!.uyeler.firstWhere((u) => u.id == t.uyeId).ad}';
  }

  Widget _oyla() {
    final r = context.renkler;
    final t = _kartlar[_kart];
    Widget sayac(int i, String ad) => Expanded(
          child: Column(children: [
            Text(ad, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${_oy[i]}', style: Theme.of(context).textTheme.headlineMedium),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                tooltip: '$ad azalt',
                onPressed: _oy[i] > 0 ? () => setState(() => _oy[i]--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                tooltip: '$ad artır',
                onPressed: () => setState(() => _oy[i]++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kart ${_kart + 1} / ${_kartlar.length}', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: r.yuzey,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: r.mor, width: 2),
            ),
            child: Column(children: [
              Text('%${t.yuzde}', style: TextStyle(color: r.metinIkincil)),
              const SizedBox(height: 8),
              Text(t.metin,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(_yazarAdi(t), style: TextStyle(color: r.metinIkincil)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('El kaldırarak sayın', textAlign: TextAlign.center),
          Row(children: [sayac(0, 'Oldu'), sayac(1, 'Kısmen'), sayac(2, 'Olmadı')]),
          const Spacer(),
          FilledButton(onPressed: _kararVer, child: const Text('Kararı ver')),
        ],
      ),
    );
  }

  Widget _sonuc() {
    final r = context.renkler;
    final k = _k!;
    final puan = <int, double>{};
    final kesin = <int, double>{};
    for (final t in _kartlar) {
      final kr = _kararlar[t.id];
      if (kr == null) continue;
      final pu = kehanetPuani(kr, t.yuzde);
      puan[t.uyeId] = (puan[t.uyeId] ?? 0) + pu;
      if (kr == Karar.oldu) {
        final cesaret = 100 - t.yuzde;
        kesin[t.uyeId] = max(kesin[t.uyeId] ?? 0, cesaret.toDouble());
      }
    }
    final sirali = k.uyeler.where((u) => !u.cekildi).toList()
      ..sort((a, b) => (puan[b.id] ?? 0).compareTo(puan[a.id] ?? 0));
    String? kahin, cesur;
    if (sirali.length > 1 && (puan[sirali.first.id] ?? 0) > 0) {
      kahin = sirali.first.ad;
    }
    if (kesin.isNotEmpty) {
      final id = (kesin.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
      if (id.value > 0 && sirali.length > 1) {
        cesur = k.uyeler.firstWhere((u) => u.id == id.key).ad;
      }
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kehanet sonuçları',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(children: [
              for (var i = 0; i < sirali.length; i++)
                ListTile(
                  leading: Text('${i + 1}', style: const TextStyle(fontSize: 20)),
                  title: Text(sirali[i].ad),
                  trailing: Text((puan[sirali[i].id] ?? 0).toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              if (kahin != null)
                ListTile(
                  leading: Icon(Icons.auto_awesome_rounded, color: r.mor),
                  title: const Text('Yılın Kâhini'),
                  subtitle: Text(kahin),
                ),
              if (cesur != null)
                ListTile(
                  leading: Icon(Icons.bolt_rounded, color: r.uyari),
                  title: const Text('Cesur Kâhin'),
                  subtitle: Text(cesur),
                ),
              const Divider(),
              for (final t in _kartlar)
                ListTile(
                  title: Text(t.metin),
                  subtitle: Text(
                      '${k.uyeler.firstWhere((u) => u.id == t.uyeId).ad} · %${t.yuzde}'),
                  trailing: Text(switch (_kararlar[t.id]) {
                    Karar.oldu => 'Oldu',
                    Karar.kismen => 'Kısmen',
                    Karar.olmadi => 'Olmadı',
                    null => '—',
                  }),
                ),
            ]),
          ),
          FilledButton(
            onPressed: () async {
              await _sil();
              if (!mounted) return;
              ref.read(oturumProvider.notifier).bitir();
              context.go('/');
            },
            child: const Text('Kapsülü sil ve çık'),
          ),
          const SizedBox(height: 8),
          _not(context),
        ],
      ),
    );
  }
}
