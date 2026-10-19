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
- İçerik: 2.874 satırın tamamı 2026-10-19'da editör (kullanıcı) tarafından onay masasında toplu onaylandı (ret ve düzeltme yok); `durum=onayli`, `editor=emrecantural`. Release AAB artık içerik taşır. Hukuk/telif ve doğruluk (özellikle 15 Bilgi Yarışması) taraması ayrıca yapılmadı.
- Sunucu: Play satın alma doğrulaması yok → oda kurma `GECIS_KAPISI=acik` ile açılır, yoksa `402 NO_ROOM_RIGHT`; `/v1/passes/redeem` 501. Takma ad yasaklı listesi yer tutucudur.
- 07 oda: kurucunun premium bildirimi istemci tarafında doğrulanır (kabul edilen risk). Tombala sesli okuma yok.
- İstemci: oda panelleri cihazda denenmedi (03 oda rol paketi düzenleyicisi var, yerel PASS modunda yok); 24 Gizli Hediye eşleşmeyi cihaza yazmaz (D-053); 23 Yeni Yıl Kehaneti çıkarıldı, yerine 20 Hafıza Düellosu (tek cihaz) geldi (D-052); yazı tipi ve ses varlıkları yok.
- Para kazanma: AdMob test kimlikleri, UMP rızası, Premium satın alma (ürün Play'de tanımlı değil), geçiş reklamı sıklık kuralları kodda; 4 saatlik oda geçişi: istemci satın alma + sunucu defteri/Play doğrulaması kodda, ama hiç gerçek Play hesabıyla denenmedi ve hizmet hesabı tanımlanana dek sunucu 501 döner. Premium iade tespiti yok.
- Yayın: imzalama anahtarı yok (release AAB hata ayıklama imzalı); mağaza gönderimi yapılmadı.
