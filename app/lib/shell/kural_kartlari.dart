import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/registry.dart';

/// Oyun başına kısa kural kartları (tasarım belgelerindeki akışın özeti).
const kuralKartlari = <String, List<String>>{
  '01': [
    'Oda sahibi sayıları çeker; her çekilen sayı herkesin ekranında görünür.',
    'Kendi kartındaki sayıyı işaretle; ekran bunu çoğu zaman senin yerine yapar.',
    'Çinko ve tombala ödüllerini ilk dolduran alır.',
  ],
  '02': [
    'Telefon masada ortada durur; herkes sırayla basılı tutarak rolünü gizlice görür.',
    'Masumlar mekânı bilir, casus bilmez.',
    'Sırayla soru sorun. Süre bitince oylayın: casus yakalanırsa masumlar kazanır.',
  ],
  '03': [
    'Herkes gizli bir rol alır: köylü, kurt ya da özel roller.',
    'Gece kurtlar birini seçer; gündüz herkes tartışıp birini oylar.',
    'Kurtlar bitince köy, kurtlar köylülerle eşitlenince kurtlar kazanır.',
  ],
  '05': [
    'Ekranda bir "Hiç yapmadım ki…" cümlesi çıkar.',
    'Yaptıysan parmağını indir (ya da kendi adına dokun).',
    'Parmağı en erken bitenler elenir; kalan kazanır.',
  ],
  '06': [
    'Sıran gelince Doğruluk ya da Cesaret seç.',
    'Kartı sesli oku, soruyu yanıtla ya da görevi yap.',
    'Pas ve joker hakların sınırlıdır; herkes sırayla oynar.',
  ],
  '07': [
    'Ekranda "En olası kim…" sorusu çıkar.',
    'Herkes masadan birini seçer; oylar birlikte açılır.',
    'En çok oyu alan kişi turun "en olası"sı olur.',
  ],
  '09': [
    'Takımlara ayrılın; anlatıcı telefonu görür, takım arkadaşları görmez.',
    'Anlatıcı konuşmadan, sadece mimikle anlatır; süre içinde mümkün olduğunca çok bildir.',
    'Pas hakkı sınırlı. Rakip takımdan biri hakemlik yapar.',
  ],
  '10': [
    'Anlatıcı hedef kelimeyi anlatır ama yasaklı kelimeleri söylemez.',
    'Takım arkadaşları tahmin eder; hakem yasaklı kelime kaçarsa işaretler.',
    'Süre bitince en çok doğruyu bulan takım kazanır.',
  ],
  '11': [
    'Tahminci gizli kelimeyi görmez; diğerleri sırayla tek kelimelik ipucu yazar.',
    'Aynı olan ipuçları silinir.',
    'Kalan ipuçlarıyla tahmin et; ortak skoru birlikte yükseltirsiniz.',
  ],
  '13': [
    'Bir kategori seçilir; sırası gelen o kategoriden bir kelime söyler.',
    'Sonraki oyuncu önceki kelimenin son harfiyle başlayan yeni kelime bulur.',
    'Süresi dolan ya da tekrar edenin canı gider; en son kalan kazanır.',
  ],
  '14': [
    'Odak kişi bir soruyu kendi adına yanıtlar, telefon kapalı ekranda elden ele gider.',
    'Diğerleri onun cevabını tahmin eder.',
    'Cevaplar birlikte açılır; en çok doğru tahmin eden puan alır.',
  ],
  '15': [
    'Her soruda dört şık var; süre içinde yanıtla.',
    'Doğru ve hızlı yanıt daha çok puan getirir.',
    'Sonunda sıralama gösterilir.',
  ],
  '18': [
    'Sayaç görünürken geri sayar, sonra gizlenir.',
    'Kendi bölgene sayaç sıfıra ulaştığını düşündüğün anda bas.',
    'Hedefe en yakın basan turu kazanır.',
  ],
  '20': [
    'Kartlar kısa süre açık gösterilir, sonra kapanır.',
    'Sırayla iki kart aç; eşleşirse çifti alır ve devam edersin.',
    'En çok çifti toplayan kazanır.',
  ],
  '24': [
    'Katılımcıların adlarını gir, istersen bütçe ve hariç tutma ekle.',
    'Çekiliş yapılınca herkes sırayla, basılı tutarak yalnız kendi eşleşmesini görür.',
    'Sonuç kaydedilmez; çekiliş geri alınamaz.',
  ],
  '25': [
    'Takımlara ayrılın; anlatıcı şarkı adını görür.',
    'Sadece mırıldanır, ıslık çalar ya da tempo tutar; söz yok.',
    'Takım adı bulursa puan alır; pas hakkı sınırlıdır.',
  ],
  '27': [
    'İki kişilik, sakin bir oyun: telefon iki kişi arasında gider.',
    'Sıradaki kartı açar, soruyu sesli sorar ya da cevaplar; cevaplar uygulamaya yazılmaz.',
    'Puan ve süre yok; istediğiniz an bitirebilirsiniz.',
  ],
  '29': [
    'Tutan telefonu alnına tutar; kelimeyi göremez.',
    'Diğerleri konuşarak ipucu verir, kelimeyi söylemez.',
    'Süre içinde en çok kelimeyi bulan kazanır.',
  ],
};

String _anahtar(String id) => 'kural_gizli_$id';

Future<bool> kuralGizliMi(String id) async {
  try {
    return await SharedPreferencesAsync().getBool(_anahtar(id)) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> kurallariSifirla() async {
  try {
    final p = SharedPreferencesAsync();
    for (final o in oyunlar) {
      await p.remove(_anahtar(o.id));
    }
  } catch (_) {}
}

/// Kural kartlarını gösterir. `true` dönerse kullanıcı devam etmek istedi.
/// [oyunaGec] doğruysa birincil düğme "Anladım, oyna" olur ve "Bir daha gösterme" sunulur.
Future<bool> kuralSheetiGoster(BuildContext context, OyunBilgisi oyun,
    {bool oyunaGec = false}) async {
  final adimlar = kuralKartlari[oyun.id];
  if (adimlar == null) return true;
  var birDahaGosterme = false;
  final sonuc = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${oyun.ad} · Nasıl oynanır?',
                  style: Theme.of(c)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              for (var i = 0; i < adimlar.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 14, child: Text('${i + 1}')),
                      const SizedBox(width: 12),
                      Expanded(child: Text(adimlar[i])),
                    ],
                  ),
                ),
              if (oyunaGec)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Bir daha gösterme'),
                  value: birDahaGosterme,
                  onChanged: (v) => setState(() => birDahaGosterme = v ?? false),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(oyunaGec ? 'Anladım, oyna' : 'Kapat'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (oyunaGec && sonuc == true && birDahaGosterme) {
    try {
      await SharedPreferencesAsync().setBool(_anahtar(oyun.id), true);
    } catch (_) {}
  }
  return sonuc == true;
}
