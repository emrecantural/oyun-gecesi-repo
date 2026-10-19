import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'zarf.dart';

/// Taşıma soyutlaması (LAN'ı v1.1'de eklemek için yer tutar; şimdilik tek gerçekleme).
abstract class OdaTasimasi {
  /// Bağlanır; [gelen] her metin çerçevesi için, [kapandi] bağlantı koptuğunda çağrılır.
  Future<void> baglan(
    Uri url, {
    required void Function(String ham) gelen,
    required void Function(int? kod, String? neden) kapandi,
  });
  void gonder(String ham);
  Future<void> kapat();
}

enum BaglantiDurumu { bosta, baglaniyor, bagli, yenidenBaglaniyor, kapali }

class OdaOyuncusu {
  const OdaOyuncusu({
    required this.id,
    required this.takmaAd,
    required this.rol,
    required this.stil,
    required this.bagli,
    required this.hazir,
    required this.host,
  });
  final String id;
  final String takmaAd;
  final String rol;
  final int stil;
  final bool bagli;
  final bool hazir;
  final bool host;

  factory OdaOyuncusu.json(Map<String, dynamic> m) => OdaOyuncusu(
        id: m['id'] as String,
        takmaAd: m['nickname'] as String,
        rol: m['role'] as String? ?? 'player',
        stil: (m['color'] as num?)?.toInt() ?? 0,
        bagli: m['connected'] as bool? ?? true,
        hazir: m['ready'] as bool? ?? false,
        host: m['host'] as bool? ?? false,
      );
}

/// Kapanış nedenleri: bunlarda yeniden bağlanılmaz.
const _sonlandiranHatalar = {'SUPERSEDED', 'PLAYER_KICKED', 'ROOM_NOT_FOUND', 'UPGRADE_REQUIRED', 'LEFT'};

typedef ZamanDilimi = int Function();

/// Oda istemcisi: katılım, yeniden bağlanma + resume, anlık görüntü ve olay akışı.
class OdaIstemcisi extends ChangeNotifier {
  OdaIstemcisi({
    required OdaTasimasi Function() tasimaUret,
    Random? rng,
    ZamanDilimi? simdi,
    this.pingAraligi = const Duration(seconds: 25),
    this.sessizlikSiniri = const Duration(seconds: 45),
    this.geriCekilmeler = const [1, 2, 4, 8],
  })  : _tasimaUret = tasimaUret,
        _rng = rng ?? Random(),
        _simdi = simdi ?? (() => DateTime.now().millisecondsSinceEpoch);

  final OdaTasimasi Function() _tasimaUret;
  final Random _rng;
  final ZamanDilimi _simdi;
  final Duration pingAraligi;
  final Duration sessizlikSiniri;
  final List<int> geriCekilmeler;

  OdaTasimasi? _tasima;
  Uri? _url;
  String? _kod;
  String _takmaAd = '';
  String _installId = '';
  String _istenenRol = 'player';
  String? _resumeToken;
  bool _kullaniciKapatti = false;
  int _deneme = 0;
  Timer? _pingZamani;
  Timer? _yenidenZamani;
  int _sonGelenMs = 0;
  final _olaylar = StreamController<SunucuMesaji>.broadcast();

  BaglantiDurumu durum = BaglantiDurumu.bosta;
  String? sonHata;
  String? kapanisNedeni;

  String? get kod => _kod;
  String? get resumeToken => _resumeToken;
  String oyuncuId = '';
  String hostId = '';
  String rol = 'player';
  String oyunId = '';
  String faz = 'LOBBY';
  int? bitis;
  int seq = 0;
  Map<String, dynamic> ayarlar = const {};
  Map<String, dynamic> acik = const {};
  Map<String, dynamic>? ozel;

  /// Son gelen oyun mesajları (anahtar: `t`; 'private' için `kind`). Ekranlar bunları okur.
  final Map<String, Map<String, dynamic>> son = {};
  List<OdaOyuncusu> oyuncular = const [];
  int ekranSayisi = 0;
  int _sapma = 0;

  Stream<SunucuMesaji> get olaylar => _olaylar.stream;

  bool get hostMu => oyuncuId.isNotEmpty && oyuncuId == hostId;

  /// Sunucu saatine göre şimdi (epoch ms).
  int get sunucuSimdi => _simdi() + _sapma;

  /// Bitişe kalan ms (sunucu saatine göre); bitiş yoksa null.
  int? get kalanMs {
    final b = bitis;
    if (b == null) return null;
    final k = b - sunucuSimdi;
    return k < 0 ? 0 : k;
  }

  OdaOyuncusu? oyuncu(String id) {
    for (final o in oyuncular) {
      if (o.id == id) return o;
    }
    return null;
  }

  // ------------------------------------------------------------------ bağlantı
  Future<void> katil({
    required Uri wsUrl,
    required String kod,
    required String takmaAd,
    required String installId,
    String istenenRol = 'player',
    String? resumeToken,
  }) async {
    _url = wsUrl;
    _kod = kod;
    _takmaAd = takmaAd;
    _installId = installId;
    _istenenRol = istenenRol;
    _resumeToken = resumeToken;
    _kullaniciKapatti = false;
    _deneme = 0;
    kapanisNedeni = null;
    sonHata = null;
    await _baglan(ilk: true);
  }

  Future<void> _baglan({required bool ilk}) async {
    durum = ilk ? BaglantiDurumu.baglaniyor : BaglantiDurumu.yenidenBaglaniyor;
    notifyListeners();
    final eski = _tasima;
    _tasima = null;
    unawaited(eski?.kapat());
    final t = _tasimaUret();
    _tasima = t;
    try {
      await t.baglan(
        _url!,
        gelen: (ham) => _geldi(t, ham),
        kapandi: (kod, neden) => _koptu(t, kod, neden),
      );
    } catch (_) {
      if (identical(_tasima, t)) _koptu(t, null, 'baglanamadi');
      return;
    }
    if (!identical(_tasima, t)) return;
    _sonGelenMs = _simdi();
    final token = _resumeToken;
    if (token != null) {
      t.gonder(_ham('resume', {'resumeToken': token, 'lastSeq': seq}));
    } else {
      t.gonder(_ham('join', {
        'code': _kod,
        'nickname': _takmaAd,
        'role': _istenenRol,
        'installId': _installId,
      }));
    }
    _pingBaslat();
  }

  String _ham(String t, Map<String, dynamic> p) => istemciMesaji(t, p, yeniUlid(_rng, zamanMs: _simdi()));

  void _pingBaslat() {
    _pingZamani?.cancel();
    _pingZamani = Timer.periodic(pingAraligi, (_) {
      final t = _tasima;
      if (t == null) return;
      if (_simdi() - _sonGelenMs > sessizlikSiniri.inMilliseconds) {
        _koptu(t, null, 'sessizlik');
        return;
      }
      t.gonder('ping');
    });
  }

  void _geldi(OdaTasimasi t, String ham) {
    if (!identical(_tasima, t)) return;
    _sonGelenMs = _simdi();
    final m = mesajCoz(ham);
    if (m == null) return; // "pong"
    if (m.now > 0) _sapma = m.now - _simdi();
    _isle(m);
    _olaylar.add(m);
  }

  void _isle(SunucuMesaji m) {
    switch (m.t) {
      case 'welcome':
        oyuncuId = m.p['playerId'] as String;
        final tok = m.p['resumeToken'];
        if (tok is String) _resumeToken = tok;
        hostId = m.p['hostId'] as String? ?? '';
        rol = m.p['role'] as String? ?? 'player';
        ayarlar = (m.p['settings'] as Map<String, dynamic>?) ?? const {};
        final s = (m.p['snapshot'] as Map<String, dynamic>?) ?? const {};
        oyunId = s['game'] as String? ?? oyunId;
        faz = s['phase'] as String? ?? 'LOBBY';
        bitis = (s['endsAt'] as num?)?.toInt();
        acik = (s['public'] as Map<String, dynamic>?) ?? const {};
        ozel = s['private'] as Map<String, dynamic>?;
        son.clear();
        _ozelTohumla();
        _rosterAl(s['roster'] as Map<String, dynamic>?);
        seq = m.seq;
        durum = BaglantiDurumu.bagli;
        _deneme = 0;
      case 'state':
        faz = m.p['phase'] as String? ?? faz;
        bitis = (m.p['endsAt'] as num?)?.toInt();
        acik = (m.p['public'] as Map<String, dynamic>?) ?? acik;
        seq = m.seq;
      case 'roster':
        _rosterAl(m.p);
        seq = m.seq;
      case 'settings':
        ayarlar = (m.p['settings'] as Map<String, dynamic>?) ?? ayarlar;
        seq = m.seq;
      case 'hostChanged':
        hostId = m.p['hostId'] as String? ?? hostId;
        seq = m.seq;
      case 'private':
        final k = m.p['kind'];
        if (k is String) son[k] = m.p;
      case 'error':
        sonHata = m.p['code'] as String?;
        if (_sonlandiranHatalar.contains(sonHata) || durum != BaglantiDurumu.bagli) {
          // Katılım reddi veya kesin son: yeniden denemeden kapat.
          kapanisNedeni = sonHata;
          _kullaniciKapatti = true;
          durum = BaglantiDurumu.kapali;
          unawaited(_tasima?.kapat());
        }
      case 'closed':
        kapanisNedeni = m.p['reason'] as String? ?? 'closed';
        _kullaniciKapatti = true;
        durum = BaglantiDurumu.kapali;
      case 'ack':
        break;
      default:
        son[m.t] = m.p;
        seq = m.seq > seq ? m.seq : seq;
    }
    notifyListeners();
  }

  /// Anlık görüntüdeki özel durumu, canlı mesajlarla aynı anahtarlara döker.
  void _ozelTohumla() {
    final o = ozel;
    if (o == null) return;
    if (o['kind'] == 'cards') son['cards'] = o;
    for (final k in const ['nightPrompt', 'witchInfo']) {
      final v = o[k];
      if (v is Map<String, dynamic>) son[k] = v;
    }
    if (o['wolfBoard'] is Map<String, dynamic>) {
      son['wolfBoard'] = {'kind': 'wolfBoard', 'votes': o['wolfBoard']};
    }
    if (o['role'] is String) {
      son['roleAssigned'] = {
        'kind': 'roleAssigned',
        'role': o['role'],
        'allies': o['allies'] ?? const [],
        'loverId': o['loverId'],
      };
    }
    final gecmis = o['seerResults'];
    if (gecmis is List && gecmis.isNotEmpty) {
      son['seerHistory'] = {'results': gecmis};
    }
  }

  void _rosterAl(Map<String, dynamic>? r) {
    if (r == null) return;
    final liste = (r['players'] as List?) ?? const [];
    oyuncular = [for (final x in liste) OdaOyuncusu.json(x as Map<String, dynamic>)];
    ekranSayisi = (r['displays'] as num?)?.toInt() ?? 0;
  }

  void _koptu(OdaTasimasi t, int? kod, String? neden) {
    if (!identical(_tasima, t)) return;
    _tasima = null;
    _pingZamani?.cancel();
    if (_kullaniciKapatti || durum == BaglantiDurumu.kapali) {
      durum = BaglantiDurumu.kapali;
      notifyListeners();
      return;
    }
    if (_resumeToken == null && durum != BaglantiDurumu.bagli) {
      // Katılım tamamlanmadan koptu: yeniden denemek yerine hata ver.
      durum = BaglantiDurumu.kapali;
      sonHata ??= 'baglanamadi';
      notifyListeners();
      return;
    }
    durum = BaglantiDurumu.yenidenBaglaniyor;
    notifyListeners();
    final bekle = geriCekilmeler[_deneme < geriCekilmeler.length ? _deneme : geriCekilmeler.length - 1];
    _deneme++;
    final sapma = 1 + (_rng.nextDouble() * 0.4 - 0.2);
    _yenidenZamani?.cancel();
    _yenidenZamani = Timer(Duration(milliseconds: (bekle * 1000 * sapma).round()), () {
      if (_kullaniciKapatti) return;
      unawaited(_baglan(ilk: false));
    });
  }

  /// Uygulama öne geldiğinde hemen yeniden dene (arka planda soket kopmuş olabilir).
  void onePlana() {
    if (durum == BaglantiDurumu.yenidenBaglaniyor && _tasima == null && !_kullaniciKapatti) {
      _yenidenZamani?.cancel();
      unawaited(_baglan(ilk: false));
    }
  }

  // ------------------------------------------------------------------ gönderme
  /// Mesaj gönderir ve kullanılan `id`'yi döndürür (yeniden gönderimde aynı id kullanılabilir).
  String? gonder(String t, [Map<String, dynamic> p = const {}, String? id]) {
    final tasima = _tasima;
    if (tasima == null || durum != BaglantiDurumu.bagli) return null;
    final i = id ?? yeniUlid(_rng, zamanMs: _simdi());
    tasima.gonder(istemciMesaji(t, p, i));
    return i;
  }

  Future<void> ayril() async {
    if (_tasima != null && durum == BaglantiDurumu.bagli) {
      gonder('leave');
    }
    await kapat();
  }

  Future<void> kapat() async {
    _kullaniciKapatti = true;
    _pingZamani?.cancel();
    _yenidenZamani?.cancel();
    final t = _tasima;
    _tasima = null;
    durum = BaglantiDurumu.kapali;
    notifyListeners();
    await t?.kapat();
  }

  @override
  void dispose() {
    _kullaniciKapatti = true;
    _pingZamani?.cancel();
    _yenidenZamani?.cancel();
    final t = _tasima;
    _tasima = null;
    unawaited(t?.kapat());
    unawaited(_olaylar.close());
    super.dispose();
  }
}
