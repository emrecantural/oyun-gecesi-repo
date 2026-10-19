# Oyun Gecesi

Türkçe parti oyunları uygulaması (Android). Tasarım belgeleri ayrı tasarım paketindedir.

- `app/` — Flutter uygulaması. Android platform klasörü depoda tutulmaz; CI `flutter create` + `tool/patch_android.py` ile üretir.
- `server/` — Cloudflare Worker + Durable Object (çevrimiçi oda: 01 Tombala, 03 Köy ve Kurtlar, 07 En Olası Kim). `npm test`, `npm run tip`.
- `golden/` — Dart ve TypeScript motorlarının ikisinin de koştuğu ortak test vektörleri.
- `.github/workflows/` — `android.yml` (analiz, test, debug APK, release AAB), `sunucu.yml` (tsc + testler).

Kurallar: uygulamada yapay zekâ bağlantısı yok; canlı reklam/ödeme yok (Google test kimlikleri); sırlar depoda tutulmaz.

## Durum (dürüst özet)

Doğrulanan: Android CI (analiz, birim/widget testleri, debug APK, release AAB) ve sunucu CI (tsc + testler) yeşil.
**Doğrulanmayan:** hiçbir şey gerçek cihazda/emülatörde çalıştırılmadı; sunucu Cloudflare'a dağıtılmadı; görünüm gözle denetlenmedi.

Bilinen eksikler:
- İçerik CSV'lerindeki tüm satırlar `taslak`; editör onayı olmadan release AAB içerik taşımaz.
- Sunucu: Play satın alma doğrulaması yok → oda kurma `GECIS_KAPISI=acik` ile açılır, yoksa `402 NO_ROOM_RIGHT`; `/v1/passes/redeem` 501. Takma ad yasaklı listesi yer tutucudur.
- 07 oda: kurucunun premium bildirimi istemci tarafında doğrulanır (kabul edilen risk). Tombala sesli okuma yok.
- İstemci: oda panelleri cihazda denenmedi (03 oda rol paketi düzenleyicisi var, yerel PASS modunda yok); 29'da eğim sensörü, 15'te SHARED modu, 23/24'te bildirim ve şifreli depolama yok; yazı tipi ve ses varlıkları yok.
- Para kazanma: AdMob test kimlikleri, UMP rızası, Premium satın alma (ürün Play'de tanımlı değil), geçiş reklamı sıklık kuralları kodda; 4 saatlik oda geçişi satın alma istemcisi yok (sunucu doğrulaması yokken eklenmedi). Premium iade tespiti yok.
- Yayın: imzalama anahtarı yok (release AAB hata ayıklama imzalı); mağaza gönderimi yapılmadı.
