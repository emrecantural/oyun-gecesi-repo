# Oyun Gecesi

Türkçe parti oyunları uygulaması (Android). Tasarım belgeleri: `docs/` (ayrı tasarım paketinden).

- `app/` — Flutter uygulaması. Android platform klasörü depoda tutulmaz; CI `flutter create` + `tool/patch_android.py` ile üretir.
- `server/` — Cloudflare Worker + Durable Object (çevrimiçi oda). Henüz yok.
- `.github/workflows/android.yml` — analiz, test, APK/AAB derleme.

Kurallar: uygulamada yapay zekâ bağlantısı yok; canlı reklam/ödeme yok (geliştirmede Google test kimlikleri); sırlar depoda tutulmaz.
