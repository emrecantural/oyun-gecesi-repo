import 'package:flutter/material.dart';

/// Uygulamanın gerçekte yaptığı veri işlemlerinin özeti (hukuki metin değildir;
/// mağaza gizlilik politikası URL'si ayrıca yayımlanır).
class GizlilikEkrani extends StatelessWidget {
  const GizlilikEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final baslik = Theme.of(context).textTheme.titleMedium;
    Widget blok(String b, String m) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b, style: baslik?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(m),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          blok('Hesap yok',
              'Üyelik, e-posta ya da telefon numarası istenmez. Kişi listesine, konuma, mikrofona veya kameraya erişilmez.'),
          blok('Cihazında kalanlar',
              'Tema, titreşim, takma ad önerisi, kural kartı tercihleri ve rastgele üretilen bir cihaz kimliği yalnızca bu cihazda saklanır. Tek cihazlı oyunlardaki seçimler ve roller cihazdan çıkmaz.'),
          blok('Çevrimiçi oda',
              'Odaya girerken takma adın ve rastgele cihaz kimliğin sunucuya gider; oda kapanınca oda verisi silinir. Gizli roller yalnızca ilgili oyuncunun cihazına gönderilir.'),
          blok('4 saatlik oda geçişi',
              'Satın alma Google Play üzerinden yapılır. Sunucuya kartın ya da hesabın değil, yalnızca satın alma jetonu ve cihaz kimliğinden türetilmiş bir tanım gider.'),
          blok('Reklamlar',
              'Ücretsiz sürümde Google AdMob reklamları gösterilir. Kişiselleştirme için onay penceresi çıkar; “Reklam gizlilik seçenekleri” ile kararını değiştirebilirsin. Premium reklamları kaldırır.'),
          blok('Analitik',
              'Bu sürümde kullanım ya da çökme analitiği toplanmaz.'),
          blok('Verilerini silmek',
              'Ayarlar > “Yerel verilerimi sil” cihazdaki tercihleri ve cihaz kimliğini temizler. Sunucuda saklanan oda verisi oda kapanınca zaten silinir.'),
        ],
      ),
    );
  }
}
