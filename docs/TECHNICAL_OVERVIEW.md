# PoM — Peace of Mind  
## Teknik ve Fonksiyonel Tanıtım Dokümanı

**Versiyon:** 1.0.0  
**Tarih:** Mayıs 2026  
**Platform:** Android (iOS hazır altyapı)

---

## İçindekiler

1. [Ürün Özeti](#1-ürün-özeti)
2. [Sistem Topolojisi](#2-sistem-topolojisi)
3. [Teknoloji Yığını](#3-teknoloji-yığını)
4. [Uygulama Mimarisi](#4-uygulama-mimarisi)
5. [Veri Modeli ve Firestore Şeması](#5-veri-modeli-ve-firestore-şeması)
6. [Kimlik Doğrulama ve Yetkilendirme](#6-kimlik-doğrulama-ve-yetkilendirme)
7. [Özellik Modülleri](#7-özellik-modülleri)
8. [Ödeme Altyapısı](#8-ödeme-altyapısı)
9. [Güvenlik ve Gizlilik](#9-güvenlik-ve-gizlilik)
10. [KVKK Uyumluluğu](#10-kvkk-uyumluluğu)
11. [CI/CD ve Build Pipeline](#11-cicd-ve-build-pipeline)
12. [Loglama ve İzlenebilirlik](#12-loglama-ve-i̇zlenebilirlik)
13. [Ortam Yönetimi](#13-ortam-yönetimi)
14. [Veritabanı Seed Altyapısı](#14-veritabanı-seed-altyapısı)
15. [Teknik Kısıtlar ve Eşik Değerleri](#15-teknik-kısıtlar-ve-eşik-değerleri)
16. [Bilinen Eksikler ve Yol Haritası](#16-bilinen-eksikler-ve-yol-haritası)

---

## 1. Ürün Özeti

**PoM (Peace of Mind)**, finans sektöründe çalışan banka personelinin kurumsal mutluluğunu ve refah düzeyini ölçen, kişisel içgörüler sunan ve anonim topluluk analitiği üretmek için tasarlanmış bir mobil SaaS uygulamasıdır.

### Temel Değer Önerisi

| Kullanıcı | Değer |
|-----------|-------|
| Banka çalışanı | Haftalık ruh hali takibi, kişisel trend analizi, anonim şirket karşılaştırması |
| İK / Yönetim | Departman bazlı refah skorları, sektör benchmark'ı, çalışan memnuniyeti panosu |
| Platform sahibi | Abonelik + kredi geliri, anonimleştirilmiş veri monetizasyonu (DaaS) |

### Ölçülen Boyutlar (5 Dimensyon)

| Kod Adı | Türkçe Etiket | Ölçek |
|---------|---------------|-------|
| `overallMood` | Genel Ruh Hali | 1–5 |
| `workStress` | İş Stresi | 1–5 |
| `teamHarmony` | Takım Uyumu | 1–5 |
| `personalGrowth` | Kişisel Gelişim | 1–5 |
| `workLifeBalance` | İş-Yaşam Dengesi | 1–5 |

---

## 2. Sistem Topolojisi

```
┌─────────────────────────────────────────────────────────────────────┐
│                        KULLANICI CİHAZI                             │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │           Flutter Mobil Uygulama (Android / iOS)           │     │
│  │  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌──────────┐  │     │
│  │  │   Auth   │  │  Check-in │  │ Insights │  │ Wallet / │  │     │
│  │  │ LinkedIn │  │   Flow    │  │ & Radar  │  │  Stripe  │  │     │
│  │  └────┬─────┘  └─────┬─────┘  └─────┬────┘  └─────┬────┘  │     │
│  └───────┼──────────────┼──────────────┼──────────────┼───────┘     │
└──────────┼──────────────┼──────────────┼──────────────┼─────────────┘
           │              │              │              │
           │         HTTPS / TLS 1.3    │              │
           ▼              ▼              ▼              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                        GOOGLE FIREBASE                               │
│                     (Project: pomapp-c3ccc)                          │
│                                                                      │
│  ┌─────────────────┐   ┌──────────────────┐   ┌──────────────────┐  │
│  │  Firebase Auth  │   │  Cloud Firestore  │   │ Cloud Functions  │  │
│  │  (Custom Token) │   │  (NoSQL, Multi-   │   │  (Node.js)       │  │
│  │                 │   │   region)         │   │                  │  │
│  │  • JWT İmzalama │   │  • users          │   │ • linkedinAuth   │  │
│  │  • Oturum Yönt. │   │  • checkins       │   │ • createPayment  │  │
│  └─────────────────┘   │  • insights       │   │   Intent         │  │
│                        │  • subscriptions  │   │ • createSubscr.  │  │
│                        │  • wallets        │   │ • cancelSubscr.  │  │
│                        │  • transactions   │   │ • computeInsight │  │
│                        │  • companies      │   │   s (scheduled)  │  │
│                        │  • benchmarks     │   └──────────────────┘  │
│                        │  • platform_config│                         │
│                        └──────────────────┘                         │
└──────────────────────────────────────────────────────────────────────┘
           │                                          │
           ▼                                          ▼
┌──────────────────┐                    ┌─────────────────────────────┐
│  LinkedIn OAuth  │                    │      Stripe Payment API      │
│  (v2 API)        │                    │  • PaymentIntent             │
│  • Kimlik Doğr.  │                    │  • Subscription (recurring)  │
│  • HMAC Hash     │                    │  • Webhook (server → func.)  │
└──────────────────┘                    └─────────────────────────────┘
```

### Veri Akışı

```
LinkedIn OAuth  ──►  Cloud Function (linkedinAuth)
                          │
                          ├── LinkedIn ID  →  HMAC-SHA256  →  linkedinHash
                          ├── Firebase Custom Token imzala
                          └── Firestore users/ upsert
                                    │
                          Flutter Firebase Auth oturumu
                                    │
                          ┌─────────┴──────────┐
                          │                    │
                    Firestore okuma     Cloud Functions
                    (Security Rules     (ödeme, abonelik)
                     ile korumalı)              │
                                         Stripe API
```

---

## 3. Teknoloji Yığını

### 3.1 Mobil Uygulama

| Katman | Teknoloji | Versiyon |
|--------|-----------|----------|
| Framework | Flutter | Stable (≥3.22) |
| Dil | Dart | ≥3.3.0, <4.0.0 |
| Durum Yönetimi | Flutter Riverpod | 2.5.1 |
| Navigasyon | GoRouter | 14.2.7 |
| Grafik | fl_chart | 0.69.0 |
| Lokalizasyon | intl | 0.19.0 |
| HTTP | http | 1.2.2 |
| Şifreleme | crypto | 3.0.3 |
| Depolama | shared_preferences | 2.3.2 |
| URL | url_launcher | 6.3.0 |

### 3.2 Firebase SDK'ları (Dart)

| Paket | Versiyon | Kullanım |
|-------|----------|----------|
| firebase_core | 3.6.0 | Firebase başlatma |
| firebase_auth | 5.3.1 | Kimlik doğrulama |
| cloud_firestore | 5.4.4 | Veritabanı |
| cloud_functions | 5.1.3 | Sunucu fonksiyonları |

### 3.3 Ödeme

| Teknoloji | Versiyon | Rol |
|-----------|----------|-----|
| flutter_stripe | 11.1.0 | Mobil Stripe SDK |
| Stripe API | v1 | Payment Intent, Subscription |

### 3.4 Backend ve Altyapı

| Teknoloji | Rol |
|-----------|-----|
| Google Firebase | BaaS — Auth, DB, Functions |
| Cloud Firestore | NoSQL gerçek zamanlı veritabanı |
| Cloud Functions (Node.js) | LinkedIn auth bridge, ödeme akışı |
| LinkedIn OAuth v2 | Sosyal kimlik doğrulama |
| Stripe | Ödeme işleme |

### 3.5 Geliştirici Araçları

| Araç | Versiyon / Detay |
|------|-----------------|
| Codemagic | CI/CD — Android debug APK build |
| Android Gradle Plugin | 8.7.0 |
| Kotlin | 2.1.0 |
| Java | 17 (build ortamı) |
| Google Services Plugin | 4.4.2 |
| build_runner | Riverpod kod üretimi |
| flutter_lints | Statik analiz |
| Node.js | Seed script |

### 3.6 Dil Dağılımı

```
Dart    ████████████████████░░  ~95%   (Flutter uygulama kodu)
Kotlin  █░░░░░░░░░░░░░░░░░░░░░   ~2%   (Android MainActivity)
YAML    █░░░░░░░░░░░░░░░░░░░░░   ~1%   (pubspec, codemagic)
JS      █░░░░░░░░░░░░░░░░░░░░░   ~1%   (Firestore seed script)
Gradle  █░░░░░░░░░░░░░░░░░░░░░   ~1%   (Android build configs)
```

---

## 4. Uygulama Mimarisi

### 4.1 Klasör Yapısı

```
mobile/lib/
├── main.dart                    # Uygulama giriş noktası
├── firebase_options.dart        # Platform bazlı Firebase yapılandırması
│
├── core/
│   ├── constants/
│   │   └── app_constants.dart   # Merkezi sabitler (URL, koleksiyonlar, eşikler)
│   ├── providers/
│   │   └── firebase_providers.dart  # Firebase singleton provider'ları
│   ├── router/
│   │   └── app_router.dart      # GoRouter tanımları + auth redirect
│   └── theme/
│       └── app_theme.dart       # Material 3 tema (light + dark)
│
├── models/                      # Saf Dart veri sınıfları
│   ├── user_model.dart
│   ├── checkin_model.dart
│   ├── insight_model.dart
│   ├── wallet_model.dart
│   └── subscription_model.dart
│
└── features/                    # Özellik bazlı modüler yapı
    ├── auth/
    ├── home/
    ├── checkin/
    ├── insights/
    ├── wallet/
    ├── subscription/
    └── benchmarking/
```

Her `feature/` modülü aynı iç yapıya sahiptir:

```
feature/
├── data/          # Repository (Firestore / Cloud Function çağrıları)
├── providers/     # Riverpod state notifier'ları ve provider'lar
└── presentation/  # Flutter widget'ları (ekranlar + alt bileşenler)
```

### 4.2 Katmanlı Mimari (Clean Architecture)

```
┌────────────────────────────────────────────┐
│          Presentation (Widget'lar)          │  ← Yalnızca UI, provider izler
├────────────────────────────────────────────┤
│         Providers (Riverpod)                │  ← State + iş mantığı
├────────────────────────────────────────────┤
│         Repository (Data Layer)             │  ← Firestore / Functions / HTTP
├────────────────────────────────────────────┤
│         Models (Plain Dart)                 │  ← Serileştirme / fromMap / toMap
└────────────────────────────────────────────┘
```

### 4.3 Durum Yönetimi (Riverpod)

| Provider Türü | Kullanım Yeri |
|--------------|---------------|
| `Provider` | Firebase instance'ları, repository singleton'ları |
| `NotifierProvider` | Auth state, Check-in flow state (karmaşık iş mantığı) |
| `StreamProvider.autoDispose` | Firestore gerçek zamanlı okumalar (insights, wallet, subscription) |
| `FutureProvider.autoDispose` | Tek seferlik async işlemler (cooldown sorgusu, company search) |
| `StateProvider` | Basit mutable state (selected period, search query, selected companies) |

`autoDispose` kullanımı: Widget ağaçtan kaldırıldığında provider otomatik temizlenir → bellek sızıntısı riski minimize edilir.

### 4.4 Navigasyon (GoRouter)

GoRouter **flat route** mimarisiyle çalışır — navigasyon yığını oluşmaz. Tüm geçişler `context.go('/route')` ile yapılır. Bu nedenle tüm ekranlarda geri butonu **elle** eklenmektedir.

**Route Tablosu:**

| Yol | Ekran | Açıklama |
|-----|-------|----------|
| `/` | HomeScreen | Ana sayfa + bottom nav |
| `/login` | LoginScreen | LinkedIn giriş |
| `/kvkk` | KvkkScreen | KVKK onay ekranı |
| `/checkin` | CheckinFlowScreen | Haftalık anket akışı |
| `/insights` | InsightsScreen | Kişisel analitik |
| `/wallet` | WalletScreen | Kredi bakiyesi + satın alma |
| `/subscription` | SubscriptionScreen | Abonelik yönetimi |
| `/benchmarking` | BenchmarkingScreen | Şirket karşılaştırması |

**Auth Redirect Mantığı:**

```
Kullanıcı giriş yapmamış  →  /login
Giriş yapılmış, KVKK yok  →  /kvkk
/login veya /kvkk'da ama auth OK  →  /
```

GoRouter, `AuthStateNotifier`'ın `Listenable` arayüzü sayesinde auth değişimlerini otomatik algılar.

### 4.5 Tema

**Renk Paleti:**

| Mod | Seed Rengi | İkincil |
|-----|-----------|---------|
| Light | #4A90D9 (Mavi) | #5CB85C (Yeşil) |
| Dark | #4A90D9 (Mavi) | #5CB85C (Yeşil) |

Dark mode arka plan renkleri: `#0F1117` (primary), `#1A1D27` (surface).

**Material 3** etkin — dinamik renk şeması, rounded corner tasarımı (12–16px), custom AppBar ve button stili.

---

## 5. Veri Modeli ve Firestore Şeması

### 5.1 Koleksiyon Haritası

```
Firestore (pomapp-c3ccc)
│
├── users/{uid}
├── checkins/{checkin_id}
├── insights/{uid}
├── subscriptions/{uid}
├── wallets/{uid}
├── transactions/{transaction_id}
├── companies/{company_id}
│   └── aggregates/{period}    (subcollection)
├── benchmarks/{industry_id}
└── platform_config/
    ├── thresholds
    └── stripe_plans
```

### 5.2 Alan Detayları

#### `users/{uid}`

| Alan | Tip | Açıklama |
|------|-----|----------|
| `uid` | String | Firebase Auth UID (doc ID) |
| `linkedinHash` | String | HMAC-SHA256 LinkedIn ID hash |
| `displayName` | String | Görünen ad |
| `avatarUrl` | String? | Profil fotoğrafı URL |
| `role` | String | `free` / `pro` / `enterprise` / `daas` |
| `isAdmin` | bool | Yönetici yetkisi |
| `kvkkAccepted` | bool | KVKK onayı verildi mi |
| `kvkkVersion` | String | Onaylanan KVKK versiyonu |
| `kvkkAcceptedAt` | Timestamp | Onay tarihi |
| `creditBalance` | int | Mevcut kredi bakiyesi |
| `companyId` | String? | Çalıştığı şirket ID |
| `department` | String? | Departman kodu |
| `email` | String? | E-posta |
| `createdAt` | Timestamp | Kayıt tarihi |
| `lastCheckinAt` | Timestamp? | Son check-in tarihi |

#### `checkins/{checkin_id}`

| Alan | Tip | Açıklama |
|------|-----|----------|
| `uid` | String | Kullanıcı ID |
| `overallMood` | int | 1–5 |
| `workStress` | int | 1–5 |
| `teamHarmony` | int | 1–5 |
| `personalGrowth` | int | 1–5 |
| `workLifeBalance` | int | 1–5 |
| `companyId` | String? | Şirket ID |
| `department` | String? | Departman |
| `isAnonymized` | bool | Anonimleme bayrağı (default: true) |
| `createdAt` | Timestamp | Kayıt zamanı |

#### `insights/{uid}`

| Alan | Tip | Açıklama |
|------|-----|----------|
| `personalScores` | Map<String, double> | 5 boyut kişisel ortalama |
| `companyScores` | Map<String, double>? | Şirket ortalaması (N≥15 ise) |
| `benchmarkScores` | Map<String, double>? | Sektör ortalaması |
| `totalCheckins` | int | Toplam check-in sayısı |
| `trend` | int | +1 (iyileşiyor) / -1 (kötüleşiyor) / 0 |
| `updatedAt` | Timestamp | Son hesaplama zamanı |
| `companyId` | String | Şirket referansı |

#### `subscriptions/{uid}`

| Alan | Tip | Açıklama |
|------|-----|----------|
| `plan` | String | `free` / `pro` / `enterprise` / `daas` |
| `status` | String | `active` / `inactive` / `canceled` / `pastDue` / `trialing` |
| `currentPeriodStart` | Timestamp | Dönem başlangıcı |
| `currentPeriodEnd` | Timestamp | Dönem sonu |
| `stripeSubscriptionId` | String | Stripe abonelik ID |
| `stripeCustomerId` | String | Stripe müşteri ID |
| `cancelAtPeriodEnd` | bool | Dönem sonunda iptal |
| `trialEnd` | Timestamp? | Deneme süresi bitiş |

#### `wallets/{uid}`

| Alan | Tip | Açıklama |
|------|-----|----------|
| `credits` | int | Mevcut kredi |
| `total_purchased` | int | Toplam satın alınan kredi |
| `created_at` | Timestamp | İlk oluşturma |
| `updated_at` | Timestamp | Son güncelleme |

#### `platform_config/thresholds`

| Alan | Değer |
|------|-------|
| `company_min_n` | 15 |
| `department_min_n` | 10 |
| `checkin_cooldown_days` | 7 |
| `kvkk_version` | "1.0" |
| `safety_floor_company` | 5 |
| `safety_floor_department` | 3 |

---

## 6. Kimlik Doğrulama ve Yetkilendirme

### 6.1 LinkedIn OAuth Akışı

```
1. Kullanıcı "LinkedIn ile Giriş" butonuna basar
   │
2. url_launcher → tarayıcı açılır
   URL: https://www.linkedin.com/oauth/v2/authorization
        ?client_id=<CLIENT_ID>
        &redirect_uri=https://app.pom.app/auth/callback
        &scope=r_liteprofile%20r_emailaddress
        &response_type=code
        &state=<random>
   │
3. Kullanıcı LinkedIn'de oturum açar ve izin verir
   │
4. LinkedIn → redirect_uri?code=<AUTH_CODE>
   │
5. Flutter app authCode yakalar
   │
6. Cloud Function `linkedinAuth` çağrılır (authCode ile)
   │
7. Function: LinkedIn API'den profil alır
   Function: HMAC-SHA256(linkedinId, secret) = linkedinHash
   Function: Firestore'da linkedinHash ile kullanıcı arar/oluşturur
   Function: Firebase Custom Token imzalar
   │
8. Flutter: customToken ile Firebase Auth signInWithCustomToken()
   │
9. Firebase Auth → idToken (JWT) verilir
   Tüm Firestore isteklerinde Authorization header olarak kullanılır
```

### 6.2 Debug Bypass Auth

Geliştirme kolaylığı için `kDebugMode && AppConstants.debugBypassAuth == true` koşulunda:
- LinkedIn akışı tamamen atlanır
- Bellekte tanımlı `_testUser` doğrudan yüklenir
- Firebase Auth oturumu **açılmaz** → Firestore Security Rules bypass
- Bu nedenle tüm provider'lar debug modunda mock veri döner

```dart
const _testUser = UserModel(
  uid: 'test_user_001',
  displayName: 'Test Kullanıcı',
  role: 'pro',
  companyId: 'garanti_bbva',
  creditBalance: 150,
  kvkkAccepted: true,
);
```

**Production'da `debugBypassAuth` kesinlikle `false` olmalıdır.**

### 6.3 Firebase Security Rules Prensibi

Firestore, Firebase Auth tarafından sağlanan JWT'nin `request.auth.uid` değerini kullanır:

- Kullanıcılar yalnızca kendi dökümanlarını okuyabilir/yazabilir
- Şirket aggregat'ları ve benchmark'lar herkes tarafından okunabilir (N eşiğini sağlıyorsa)
- Admin işlemleri için `isAdmin: true` alanı kontrol edilir
- Check-in yazma: yalnızca kimlik doğrulanmış kullanıcı, kendi `uid` ile

---

## 7. Özellik Modülleri

### 7.1 Home (Ana Sayfa)

**Bileşenler:**

| Widget | İçerik |
|--------|--------|
| AppBar | PoM logosu, kredi chip'i (bakiye), profil avatar'ı |
| Selamlama kartı | Saate göre Günaydın/İyi Günler/İyi Akşamlar + kullanıcı adı + plan rozeti |
| Check-in CTA | Hazır (gradient kart) veya cooldown geri sayımı |
| Hızlı İstatistikler | Refah skoru, toplam check-in, trend oku (↑/↓/→) |
| Hızlı Eylemler | 4 buton: İçgörüler, Cüzdan, Abonelik, Karşılaştır |
| Bottom Navigation | 4 sekme: Ana Sayfa, Check-in, İçgörüler, Cüzdan |

**Pull-to-refresh:** insights, cooldown ve wallet balance provider'larını invalidate eder.

### 7.2 Check-in Akışı

**5 adımlı emoji tabanlı anket:**

```
Adım 1: Genel Ruh Hali      → 😢 😕 😐 🙂 😊  (1–5)
Adım 2: İş Stresi           → 😰 😟 😐 😌 😎
Adım 3: Takım Uyumu         → 💔 😕 🤝 😊 🤗
Adım 4: Kişisel Gelişim     → 📉 😐 📈 🌱 🚀
Adım 5: İş-Yaşam Dengesi    → ⚖️💥 😓 ⚖️ 🌟 🏆
```

**Akış:**
- Emoji seçildiğinde 380ms gecikme sonrası **otomatik ilerleme** (son adım hariç)
- Geri butonu: tüm adımlarda (adım 1 hariç) gösterilir
- "Tamamla" butonu: yalnızca son adımda
- Başarıda: "İçgörüleri Gör" veya "Ana Sayfa" seçenekli dialog
- 7 günlük cooldown: süre dolmadan CTA gösterilmez, kalan süre formatlanarak gösterilir
- Debug mod: Firestore yazılmaz, 600ms mock gecikme ile başarı simülasyonu

### 7.3 İçgörüler (Analytics)

**İçerik:**
- Radar chart — 5 boyut (kişisel vs şirket)
- Trend göstergesi (+/- %)
- Boyut bazlı detay kartları
- Son check-in tarihi (`DateFormat('dd MMMM yyyy', 'tr_TR')`)
- Benchmark karşılaştırması (sektör ortalaması)

**Veri:** `insightsStreamProvider` → Firestore `insights/{uid}` gerçek zamanlı stream

**Debug mock verisi:**
```
personalScores: { overallMood: 4.0, workStress: 3.5, teamHarmony: 4.2,
                  personalGrowth: 3.8, workLifeBalance: 3.2 }
companyScores:  { overallMood: 3.8, workStress: 3.2, teamHarmony: 3.9,
                  personalGrowth: 3.5, workLifeBalance: 3.0 }
totalCheckins: 8, trend: +1
```

### 7.4 Şirket Karşılaştırması (Benchmarking)

**Özellikler:**
- En fazla **6 şirket** aynı anda karşılaştırılabilir
- **Dönem seçici:** Son 30 Gün / Son 90 Gün / Tüm Zamanlar
- **fl_chart LineChart:** Her şirket = ayrı renkli çizgi, her nokta = boyut skoru
- **Şirket chip'leri:** Renkli avatar + X (kaldır) + "Şirket Ekle" ActionChip
- **Dönem banner:** "N şirket · Son 90 Gün verileri"
- **Şirket arama:** Alt sayfa (modal bottom sheet) → Firestore prefix sorgusu
- **Skor kartları:** 2 sütunlu grid, şirket başına N, ortalama skor
- Yetersiz veri (N < 15): "Yetersiz veri" etiketi

**Renk paleti (6 şirket):**
```
#2196F3 Mavi  |  #4CAF50 Yeşil  |  #FF9800 Turuncu
#9C27B0 Mor   |  #F44336 Kırmızı|  #00BCD4 Cyan
```

**Debug mock şirketleri:**
- Garanti BBVA (n=73), Akbank (n=71), Ziraat (n=70), İş Bankası (n=68), Yapı Kredi (n=65)

### 7.5 Cüzdan (Wallet)

**Kredi Paketleri:**

| Paket | Fiyat | Kredi | Birim Maliyet |
|-------|-------|-------|---------------|
| Başlangıç | ₺49 | 10 kredi | ₺4.90/kredi |
| Popüler ⭐ | ₺199 | 50 kredi | ₺3.98/kredi |
| Kurumsal | ₺349 | 100 kredi | ₺3.49/kredi |

**Ödeme akışı:** Stripe Payment Sheet → Cloud Function → Stripe API → Webhook → Firestore wallets güncelleme

**İşlem geçmişi:** Son 30 işlem, tip bazlı emoji ikonları (satın alma/harcama/iade/bonus)

### 7.6 Abonelik

**Planlar:**

| Plan | Aylık | Özellikler |
|------|-------|------------|
| Free | ₺0 | 3 check-in/ay, temel içgörüler, kişisel radar |
| Pro | ₺199 | Sınırsız check-in, gelişmiş analitik, şirket karşılaştırma, sektör benchmark, öncelikli destek |
| Enterprise | ₺999 | Pro + takım paneli, departman karşılaştırma, özel raporlar, SSO, hesap yöneticisi |
| DaaS | Özel | Enterprise + API erişimi, white-label widget, özel entegrasyon, SLA |

**DaaS (Data as a Service):** `sales@pom.app` mailto bağlantısı ile satış ekibi yönlendirmesi.

### 7.7 KVKK Onay Ekranı

- 12 bölümlü tam KVKK Aydınlatma Metni (Türkçe)
- Scroll zorunluluğu (sonuna kadar kaydırmadan kabul edilemiyor)
- Versiyon + tarih damgası ile Firestore'a kaydedilir
- İletişim: `kvkk@pom.app`

---

## 8. Ödeme Altyapısı

### 8.1 Tek Seferlik Ödeme (Kredi)

```
Kullanıcı "Satın Al" →
  WalletRepository.createCreditPaymentIntent(amount, credits) →
    Cloud Function createPaymentIntent →
      Stripe PaymentIntent oluştur →
        clientSecret döner →
          flutter_stripe PaymentSheet göster →
            Kullanıcı ödeme yapar →
              Stripe Webhook → Cloud Function →
                Firestore wallets/{uid}.credits += credits
```

### 8.2 Tekrarlayan Abonelik

```
Kullanıcı plan seçer →
  SubscriptionRepository.createSubscription(planId) →
    Cloud Function createSubscription →
      Stripe Subscription oluştur →
        clientSecret döner →
          flutter_stripe PaymentSheet →
            Kullanıcı ödeme yapar →
              Stripe Webhook → Cloud Function →
                Firestore subscriptions/{uid} upsert
```

### 8.3 İptal

```
SubscriptionRepository.cancelSubscription(subscriptionId) →
  Cloud Function cancelSubscription →
    Stripe: cancelAtPeriodEnd = true →
      Stripe Webhook → Firestore subscriptions/{uid}.cancelAtPeriodEnd = true
```

### 8.4 Stripe Güvenliği

- Kart bilgileri **asla PoM'a ulaşmaz** — Stripe Payment Sheet doğrudan Stripe sunucularıyla iletişim kurar
- PCI DSS uyumluluğu Stripe tarafından sağlanır
- Publishable key mobil uygulamada, secret key yalnızca Cloud Functions'ta bulunur

---

## 9. Güvenlik ve Gizlilik

### 9.1 Kimlik ve Veri Güvenliği

| Güvenlik Katmanı | Detay |
|-----------------|-------|
| Aktarım Şifrelemesi | TLS 1.3 (Firebase, Stripe, LinkedIn) |
| LinkedIn ID Gizleme | HMAC-SHA256 hash — ham LinkedIn ID hiçbir zaman saklanmaz |
| Firebase Auth JWT | Her Firestore isteğinde doğrulanır, Firestore Security Rules tarafından kontrol edilir |
| Stripe Tokenization | Kart verisi PoM sistemlerine hiç girmez |
| Anonimleme Eşiği | Şirket skoru yalnızca N ≥ 15 çalışan ile yayınlanır |
| Departman Eşiği | Departman skoru yalnızca N ≥ 10 çalışan ile yayınlanır |

### 9.2 Firestore Security Rules Prensipleri

```javascript
// Kullanıcılar yalnızca kendi verisini okuyup yazabilir
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}

// Check-in yazmak için auth gerekli ve uid eşleşmeli
match /checkins/{checkinId} {
  allow create: if request.auth != null
                && request.resource.data.uid == request.auth.uid;
  allow read: if request.auth.uid == resource.data.uid;
}

// Şirket agregatları herkese açık (anonim veri, N eşiği server tarafında)
match /companies/{companyId} {
  allow read: if true;
}
```

### 9.3 Hassas Veri Sınıflandırması

| Veri | Kategori | Saklama |
|------|----------|---------|
| LinkedIn ID | Ham → İşlenmez | Asla saklanmaz |
| LinkedIn Hash | Kişisel | Firestore users/ |
| İsim, Avatar | Kişisel | Firestore users/ |
| Check-in skorları | Kişisel | Firestore checkins/ |
| Kart numarası | Ödeme | Yalnızca Stripe |
| Stripe müşteri ID | Ödeme ref. | Firestore subscriptions/ |

### 9.4 Veri Saklama Süreleri (KVKK)

| Veri Türü | Süre |
|-----------|------|
| Hesap/check-in | Hesap silindikten 90 gün |
| Ödeme kayıtları | 10 yıl (yasal zorunluluk) |
| Anonim aggregatlar | Süresiz |

### 9.5 Debug/Production Ayrımı

```dart
// Yalnızca debug build'lerde aktif
if (kDebugMode && AppConstants.debugBypassAuth) {
  // Mock veri döner — Firestore'a dokunulmaz
  return Stream.value(_mockData);
}
```

`debugBypassAuth` flag'i `release` build'de derleme zamanında `false` olarak ayarlanmalıdır. Mevcut haliyle `true` değeri SDK'nın `kDebugMode = false` garantisiyle production'da etkisizdir.

---

## 10. KVKK Uyumluluğu

### 10.1 Veri Sorumlusu

- **Şirket:** PoM Teknoloji A.Ş.
- **İletişim:** kvkk@pom.app

### 10.2 Mevzuat Uyum Kapsamı

| Gereklilik | Uygulama |
|-----------|---------|
| Açık rıza | KVKK ekranı scroll zorunluluğu + onay butonu |
| Rıza kaydı | Firestore'da sürüm + zaman damgası |
| Veri minimizasyonu | LinkedIn hash — ham ID saklanmaz |
| Anonim hale getirme | N eşiği altı agregat yayınlanmaz |
| Silme hakkı | Hesap silme akışı (Cloud Function ile) |
| Güvenlik | TLS 1.3, Firebase Security Rules |

### 10.3 Çerez ve İzleme

Uygulama herhangi bir üçüncü taraf analitik SDK (Analytics, Crashlytics, vb.) içermemektedir. Firebase Authentication dışında otomatik veri toplama yoktur.

---

## 11. CI/CD ve Build Pipeline

### 11.1 Codemagic Konfigürasyonu

**Workflow:** `android-debug-build`

```yaml
Ortam:
  flutter: stable
  java: 17
  xcode: latest    (iOS hazırlığı)

Build Komutu:
  flutter build apk --debug \
    --no-tree-shake-icons \
    --suppress-analytics

Artefakt:
  mobile/build/app/outputs/flutter-apk/app-debug.apk
```

**Cache Stratejisi:** `~/.pub-cache`, `~/.gradle/caches`, `~/.gradle/wrapper`, `mobile/.dart_tool` önbelleğe alınır → tekrar build süreleri kısalır.

**Yayımlama:** Build tamamlandığında (başarı veya başarısızlık) `ozkanmuhammed8060@gmail.com` adresine e-posta gönderilir.

**Zaman Aşımı:** 30 dakika — Flutter pub get + Gradle + APK derleme için yeterli.

### 11.2 Android Build Konfigürasyonu

**`android/app/build.gradle`:**
- `minSdk: 21` (Android 5.0 Lollipop ve üzeri)
- `targetSdk:` Flutter default (güncel)
- `compileSdk: 35`
- `versionCode/Name:` Flutter versiyonundan alınır

**`android/gradle.properties`:**
```properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m
org.gradle.parallel=true
org.gradle.caching=true
android.useAndroidX=true
android.enableJetifier=false   # AndroidX-only proje
```

**Kotlin:** 2.1.0 (Flutter minimum gereksinimi karşılıyor)

### 11.3 Geliştirme Dalları

| Dal | Amaç |
|-----|------|
| `main` | Üretim kodu |
| `claude/integrate-stripe-sdk-AEgVE` | Stripe + auth + fix branch |
| `claude/synthetic-data-mobile-PoOpW` | Mevcut aktif geliştirme |
| `claude/pom-firestore-schema-design-E90ck` | Firestore şema tasarımı |

---

## 12. Loglama ve İzlenebilirlik

### 12.1 Mevcut Durum

Uygulama şu anda üçüncü taraf bir loglama veya crash reporting çözümü **içermemektedir**. Loglama `print()` ve Flutter'ın yerleşik `debugPrint()` ile sınırlıdır ve yalnızca geliştirme ortamında görülür.

**Hata yakalama:** Provider hataları `state.error` alanına yazılır ve UI'da snackbar/card olarak gösterilir.

### 12.2 Önerilen Eklemeler (Yol Haritası)

| Araç | Amaç |
|------|------|
| Firebase Crashlytics | Crash reporting (production) |
| Firebase Performance | Ağ gecikmesi, screen render süreleri |
| Firebase Analytics | Kullanıcı davranışı (anonim event tracking) |
| Cloud Logging | Cloud Functions log yönetimi |

### 12.3 Hata Yönetimi Stratejisi

| Senaryo | Yaklaşım |
|---------|---------|
| Firestore okuma hatası | `StreamProvider` error state → UI hata kartı |
| Auth hatası | `AuthState.error` → snackbar |
| Stripe ödeme hatası | try/catch → setState error → snackbar |
| Network timeout | Firebase SDK otomatik retry (3x) |
| Cooldown aşımı | Firestore sorgusu → UI cooldown state |

---

## 13. Ortam Yönetimi

### 13.1 Firebase Konfigürasyonu

**Platform bazlı Firebase yapılandırması** `firebase_options.dart` içinde hard-coded bulunmaktadır. Firebase Console üzerinden üretilir; kaynak kontrolünde saklanması Firebase'in standart pratikidir (API key'ler Firebase Security Rules ile korunur).

| Platform | App ID |
|----------|--------|
| Android | `1:1049001087254:android:6c7969c2a9746c378b4037` |
| iOS | `1:1049001087254:ios:...` |
| Web | `1:1049001087254:web:a4d3089ee32891198b4037` |

**Firebase Project:** `pomapp-c3ccc` (Google Cloud Project Number: 1049001087254)

### 13.2 Değiştirilmesi Gereken Değerler

| Sabit | Mevcut Değer | Yapılacak |
|-------|-------------|---------|
| `stripePublishableKey` | `pk_live_REPLACE_ME` | Stripe publishable key ile değiştir |
| `linkedInClientId` | `REPLACE_ME` | LinkedIn Developer App client ID |
| `linkedInRedirectUri` | `https://app.pom.app/auth/callback` | Doğrula / deep link kur |
| HMAC Secret (CF) | `pom-linkedin-hash-secret-REPLACE_ME` | Cloud Function env var |
| `debugBypassAuth` | `true` | Release'de `false` |

### 13.3 Desteklenen Lokaller

| Lokal | Kullanım |
|-------|---------|
| `tr_TR` | DateFormat (insights tarihleri), UI metin |

`main()` başlangıcında `initializeDateFormatting('tr_TR', null)` çağrılır — eksikliği `LocaleDataException`'a neden olur.

---

## 14. Veritabanı Seed Altyapısı

### 14.1 `scripts/seed_data.js`

Geliştirme ve test ortamları için gerçekçi Türkçe bankacılık verisi üretir.

**Üretilen Varlıklar:**

| Koleksiyon | Miktar |
|-----------|--------|
| companies | 5 (Garanti, Akbank, İş, Yapı Kredi, Ziraat) |
| users | ~350 |
| checkins | ~2,500 (6 aylık geçmiş) |
| insights | ~350 (kullanıcı başına hesaplanmış) |
| wallets | ~350 |
| transactions | ~1,000 |
| subscriptions | ~350 |
| benchmarks | 1 (Bankacılık sektörü) |
| platform_config | 1 |

**Kullanıcı Dağılımı (rol bazlı):**

| Rol | Oran |
|-----|------|
| free | %70 |
| pro | %20 |
| enterprise | %10 |

**Departman Score Delta'ları:**

| Departman | Ruh Hali | İş Stresi | Takım | Gelişim | Denge |
|-----------|---------|-----------|-------|---------|-------|
| hq_it | +0.1 | +0.3 | 0 | +0.2 | +0.4 |
| hq_risk | -0.1 | -0.3 | 0 | 0 | -0.2 |
| branches | -0.2 | -0.1 | +0.1 | -0.1 | -0.1 |
| operations | -0.3 | -0.2 | 0 | -0.1 | -0.3 |

**Çalıştırma:**

```bash
# Emulator (önerilen)
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed_data.js

# Production (dikkatli kullan)
GOOGLE_APPLICATION_CREDENTIALS=path/to/sa.json node scripts/seed_data.js --prod
```

---

## 15. Teknik Kısıtlar ve Eşik Değerleri

| Parametre | Değer | Açıklama |
|-----------|-------|---------|
| `company_min_n` | 15 | Şirket skoru yayınlanma eşiği |
| `department_min_n` | 10 | Departman skoru yayınlanma eşiği |
| `checkin_cooldown_days` | 7 | Anketler arası minimum süre |
| `kvkk_version` | "1.0" | Geçerli KVKK versiyonu |
| Maks. karşılaştırma şirketi | 6 | Benchmarking ekranı limiti |
| Wallet işlem geçmişi | Son 30 | Ekranda gösterilen işlem sayısı |
| Kredi paketi boyutları | 10 / 50 / 100 | Mevcut kredi seçenekleri |
| Codemagic build timeout | 30 dk | CI pipeline zaman aşımı |
| Android minSdk | 21 | Android 5.0 Lollipop |

---

## 16. Bilinen Eksikler ve Yol Haritası

### 16.1 Mevcut Eksikler

| Alan | Eksik |
|------|-------|
| Cloud Functions | Kaynak kodu depoda yok (linkedinAuth, createPaymentIntent, vb.) |
| Firestore Rules | `firestore.rules` dosyası depoda yok |
| iOS native config | `ios/Runner/GoogleService-Info.plist` depoda yok |
| Deep Link | LinkedIn callback deep link kurulmamış |
| Crash Reporting | Firebase Crashlytics entegre edilmemiş |
| Push Notification | Firebase Cloud Messaging entegre edilmemiş |
| Admin Panel | Yönetici dashboard'u (web) geliştirilmemiş |

### 16.2 Üretim Geçişi Kontrol Listesi

- [ ] `debugBypassAuth = false` olarak güncellendi
- [ ] `stripePublishableKey` gerçek Stripe key ile değiştirildi
- [ ] `linkedInClientId` gerçek LinkedIn app ID ile değiştirildi
- [ ] LinkedIn redirect_uri (`https://app.pom.app/auth/callback`) aktif deep link
- [ ] Firebase Security Rules deploy edildi
- [ ] Cloud Functions deploy edildi
- [ ] Stripe webhook endpoint yapılandırıldı
- [ ] `google-services.json` imzalı release build için güncellendi
- [ ] Codemagic release workflow yapılandırıldı (signing)
- [ ] Firebase Crashlytics entegre edildi
- [ ] Play Store / App Store geliştirici hesapları hazır

---

*Bu doküman `claude/synthetic-data-mobile-PoOpW` dalındaki kaynak kodan otomatik olarak çıkarılmıştır.*
