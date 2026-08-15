# ⚽ Maç Tahmin — Online Maç İstatistik & Tahmin Uygulaması

Futbol maçlarını takip eden, geçmiş verilerden istatistiksel değerlendirme
üreten, karanlık temalı bir Android uygulaması. **0 TL maliyetle**
(ücretsiz katmanlar) çalışacak şekilde tasarlanmıştır.

> ⚠️ Bu uygulama **kesin sonuç veya kazanç garantisi vermez**. Tüm
> tahminler "istatistiksel değerlendirme" ve "olasılık" olarak sunulur.

---

## 1. Teknoloji Stack'i

| Katman | Teknoloji | Neden |
|---|---|---|
| Mobil | Flutter / Dart | Bilgisayarsız, tablet üzerinden GitHub Actions ile derlenebilir |
| Backend | Supabase (Postgres + Auth + Edge Functions) | Firebase Spark planı dış API çağrısına izin vermiyor, Supabase free tier'da izin veriyor |
| Veri API | API-Football (api-sports.io) | Korner/kart/hakem istatistiği veren tek kapsamlı ücretsiz seçenek |
| CI/CD | GitHub Actions | Ücretsiz APK build (public repo: sınırsız dakika) |

---

## 2. Proje Yapısı

```
futbol-tahmin-app/
├── mobile/                  # Flutter uygulaması
│   ├── lib/
│   │   ├── config/          # Supabase bağlantı ayarları
│   │   ├── services/        # Auth, veri, chatbot servisleri
│   │   ├── models/          # Veri modelleri
│   │   ├── screens/         # Tüm ekranlar (kullanıcı + admin)
│   │   └── widgets/         # Ortak bileşenler
│   ├── pubspec.yaml
│   └── .env.example
├── supabase/
│   ├── migrations/          # SQL şema, RLS, fonksiyonlar, cron
│   └── functions/           # Edge Functions (API-Football entegrasyonu)
└── .github/workflows/       # Otomatik APK build
```

---

## 3. Supabase Kurulumu

1. [supabase.com](https://supabase.com) → ücretsiz hesap aç → **New Project**.
2. Proje oluşunca **Project Settings > API** sayfasından şunları not al:
   - `Project URL` → `SUPABASE_URL`
   - `anon public` key → `SUPABASE_ANON_KEY`
   - `service_role` key → `SUPABASE_SERVICE_ROLE_KEY` (**gizli**, sadece Edge Function'da kullanılacak)
3. **SQL Editor** açıp `supabase/migrations/` klasöründeki dosyaları **sırasıyla** (0001 → 0002 → 0003) yapıştırıp çalıştır.
4. `0004_cron_jobs.sql` dosyasını çalıştırmadan önce:
   - **Database > Extensions**'tan `pg_cron` ve `pg_net`'i aktif et.
   - Dosyadaki `<PROJECT_REF>` ve `<SERVICE_ROLE_KEY>` yer tutucularını kendi değerlerinle değiştir.
   - Sonra çalıştır.

### Edge Functions Deploy (tablet üzerinden)

Bilgisayarın olmadığı için Supabase CLI'yi yerelde çalıştıramazsın. İki seçenek:

**Seçenek A — GitHub Codespaces (önerilen, ücretsiz):**
1. GitHub reponu aç → **Code > Codespaces > Create codespace**. (Tarayıcıdan, tablette de çalışır; ücretsiz kotası aylık 60 saat/2 çekirdek.)
2. Terminalde:
   ```bash
   npm install -g supabase
   supabase login
   supabase link --project-ref <PROJECT_REF>
   supabase functions deploy sync-fixtures
   supabase functions deploy compute-predictions
   supabase secrets set API_FOOTBALL_KEY=xxxx SUPABASE_SERVICE_ROLE_KEY=xxxx
   ```

**Seçenek B — Supabase Dashboard üzerinden manuel:**
Dashboard > Edge Functions > Create Function → kod içeriğini yapıştır (CLI gerektirmez, ama daha az esnek).

---

## 4. API-Football Kurulumu

1. [api-sports.io](https://www.api-sports.io) üzerinden ücretsiz hesap aç.
2. Free plan: **günde 100 istek** (tüm endpoint'ler dahil, ama sert limit).
3. API key'i **sadece** Supabase Edge Function ortam değişkenine gir (yukarıdaki `supabase secrets set` komutu). **Mobil uygulamaya asla gömülmez.**
4. ⚠️ Not: Hakem istatistikleri bazı liglerde eksik gelebilir — bu durumda uygulama "Bu veri mevcut değil" gösterir, veri uydurmaz.

---

## 5. Admin Hesabı Oluşturma

1. Uygulamadan normal şekilde kayıt ol (herhangi bir e-posta ile).
2. Supabase Dashboard > **Table Editor > profiles** tablosuna git.
3. Kendi satırını bul, `is_admin` alanını `true` yap.
4. (Alternatif) SQL Editor'de:
   ```sql
   update public.profiles set is_admin = true where email = 'admin@ornek.com';
   ```
5. Artık uygulamada Profil > **Admin Paneli** görünecek.

---

## 6. GitHub'a Yükleme (tablet üzerinden)

1. GitHub'da yeni **public** repo oluştur (public → Actions dakika limiti yok).
2. GitHub mobil uygulaması veya tarayıcıdan **Codespaces** açıp bu klasörü push et:
   ```bash
   git init
   git add .
   git commit -m "İlk sürüm"
   git branch -M main
   git remote add origin https://github.com/<kullanici-adi>/futbol-tahmin-app.git
   git push -u origin main
   ```
3. Repo > **Settings > Secrets and variables > Actions** kısmına ekle:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

---

## 7. Android APK Oluşturma

`main` branch'e her push'ta `.github/workflows/build-apk.yml` otomatik çalışır:

1. Repo > **Actions** sekmesine git.
2. "Build Android APK" workflow'unun tamamlanmasını bekle (~5-8 dk).
3. Tamamlanan run'a tıkla → en altta **Artifacts** bölümünden `futbol-tahmin-apk` dosyasını indir (tablet tarayıcısından direkt indirilebilir).
4. `.zip` içindeki `app-release.apk` dosyasını tablette aç.
5. Tablet ayarlarından "Bilinmeyen kaynaklara izin ver" açık değilse aç, APK'yı kur.

İlk build'de `android/` klasörü repoda olmadığı için workflow bunu otomatik oluşturur — elle bir şey yapmana gerek yok.

---

## 8. Ücretsiz Kullanım Limitleri (gerçekçi beklenti)

| Servis | Limit | Uygulamaya Etkisi |
|---|---|---|
| API-Football | 100 istek/gün | Günde ~15-25 maçın tam detaylı senkronu (korner+kart+hakem dahil) |
| Supabase | 500MB DB / 2GB bant genişliği / 500K Edge Function çağrısı ay | Küçük-orta kullanıcı tabanı için yeterli |
| GitHub Actions | Public repo: sınırsız dakika | APK build maliyeti yok |

Kullanıcı sayısı veya lig kapsamı büyürse önce **API-Football ücretli
planına** (aylık $19'dan başlıyor) geçmek gerekir — kod bunu `app_settings`
tablosundaki `api_daily_quota` değerini değiştirerek kolayca destekler.

---

## 9. Veri Bütünlüğü Kuralı (Kritik)

Sistem her zaman **VERİ → ANALİZ → TAHMİN** sırasıyla çalışır. Hiçbir
zaman ters yönde (önce tahmin, sonra veri uydurma) çalışmaz:
- Veri yoksa: `"Bu veri mevcut değil"`
- Yetersiz veri varsa: `"Yeterli veri olmadığı için tahmin oluşturulamadı"`
- Tahmin güven skorları her zaman gerçek `sample_size` ve veri
  tamlığından hesaplanır, rastgele üretilmez.

---

## 10. V1 (Bu Sürüm) vs V2 (Sonraki Adımlar)

**V1 (mevcut):** Auth, ana sayfa, maç listesi/filtre, maç detay
(genel/gol/korner/kart/hakem/tahmin sekmeleri), tahmin motoru, günlük 5
hak sistemi, admin paneli (kullanıcı/lig/kupon yönetimi), kupon
listeleme, chatbot (temel), GitHub Actions APK build.

**V2 (öneri):** H2H veri modeli ve entegrasyonu, admin kupon
oluşturmada maç/tahmin seçici arayüz, form grafikleri (fl_chart),
push bildirimleri, favori takımlar, geçmiş tahmin performans takibi,
ağırlık kalibrasyonu (backtesting).
