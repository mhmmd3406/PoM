# PoM — Peace of Mind · Claude Context

## Proje Yapısı
```
PoM/                          ← git repo (github: mhmmd3406/PoM)
├── mobile/                   ← Flutter uygulaması (asıl çalışılan yer)
├── admin/                    ← React admin portal (Vite + TailwindCSS)
├── functions/                ← Firebase Cloud Functions (TypeScript, v2/gen2)
├── scripts/                  ← Node.js yönetim scriptleri
├── firestore.rules
├── firestore.indexes.json
└── firebase.json
```

## Firebase Projesi
- **Project ID:** `pomapp-c3ccc`
- **Hosting:** https://pomapp-c3ccc.web.app  (admin portal)
- **CLI hesabı:** `ozkanmuhammed2@gmail.com`  (firebase-tools ile login)
- **Blaze plan:** ✅ Aktif (billingAccounts/01B2FE-E974A9-2A9CB3)

## Git İş Akışı (ZORUNLU — Claude her oturumda uygula)
**`main` = TEK doğru kaynak.** 2026-06 konsolidasyonunda tüm eski `claude/*` + `consolidate/*` branch'leri main'e alınıp SİLİNDİ; artık dağınık branch yok. Bu repoda çalışırken HER ZAMAN:
1. **`main`'e doğrudan push/commit YOK.** Her değişiklik = yeni branch + PR.
2. **Güncel `main`'den dalla:** `git fetch origin && git checkout -b <ad> origin/main`. Başka branch'ten / eski state'ten dallanma (geçmişteki karmaşanın kök nedeni buydu).
3. **1 branch = 1 odaklı iş**, kısa ömürlü; 50 commit / haftalarca büyütme.
4. **Küçük & sık PR**, günler içinde merge; net başlık + özet.
5. **CI yeşil olmadan merge yok**; mümkünse merge öncesi yerel doğrula (`flutter analyze` vb.).
6. **Merge sonrası branch'i sil** (uzak + lokal).
7. **`firestore.rules`:** main otoritatif; deploy öncesi repo ≡ canlı olduğundan emin ol; `survey_responses` daraltmasını (`isAdmin() || isCompanyMember`) ve admin-check'i geri ALMA.
8. **Cloud oturumları:** yeni oturumu güncel main'den başlat; bir sonraki büyük işi açmadan öncekini main'e merge et (aynı anda çok paralel oturum açma).

> `main` GitHub'da korumaya alınmalı (Settings → Branches: PR + CI zorunlu) → doğrudan push reddedilir.

## Flutter / Android
- **Flutter:** `C:\flutter\bin` (3.24.3, PATH'e ekli)
- **Test cihazı:** DNP NX9, Android 16 (API 36), ID: `A3SQUT5A28001708`
- **⚠️ BenchmarkingScreen** — Card import / Stripe API build fix'i hassas (artık main'de, `flutter analyze` temiz); değiştirirken dikkatli ol
- Debug giriş: Login ekranında "🛠 Test Girişi (Debug)" butonu (kDebugMode)

## Admin Portal Credentials
URL: https://pomapp-c3ccc.web.app

| Email | Şifre | Rol |
|-------|-------|-----|
| admin@pom.app | PomAdmin2026! | super admin |
| portal.garanti@pom.app | Garanti2026! | company admin |
| portal.turkcell@pom.app | Turkcell2026! | company admin |
| portal.startup@pom.app | Startup2026! | company admin |
| portal.akbank@pom.app | Akbank2026! | company admin |

## Cloud Functions (11 adet — hepsi canlı)
`us-central1`: linkedinAuth, createPaymentIntent, createSubscription, stripeWebhook,
cancelSubscription, deleteAccount, getThresholds, updateThresholds, daasWidgetApi, setAdminClaim
`europe-west1`: computeInsights

Env vars henüz ayarlanmadı → Stripe/LinkedIn fonksiyonları runtime'da hata verir.
Ayarlamak için: `firebase functions:config:set stripe.secret_key="sk_live_..."` vb.

## Faydalı Scriptler (scripts/)
```
node scripts/list_auth_users.js          # Firebase Auth kullanıcılarını listele
node scripts/set_admin_rest.js EMAIL     # is_admin claim'i ata (REST, SA gerekmez)
node scripts/reset_all_portal_passwords.js  # Tüm portal şifrelerini resetle
node scripts/check_firestore.js          # Firestore koleksiyonlarını say
node scripts/enable_billing.js           # Billing hesabını projeye bağla
```
> SA-key gerektiren scriptler için `scripts/sa_key.json` / `serviceAccountKey.json` gitignore'lı (repoya girmez).

## Firestore Koleksiyonları
`users`, `checkins`, `companies`, `surveys`, `survey_responses`,
`wallets`, `subscriptions`, `transactions`, `platform_config`

## Tasarım Sistemi
Renk token'ları: `mobile/lib/core/theme/app_colors.dart`
Arka plan: `#F6F1E8` (warm cream, beyaz değil). Uyarı rengi: amber (kırmızı değil).

## Yapılacaklar (Kalan)
- [ ] **main'i GitHub'da korumaya al** (Settings → Branches: PR + CI zorunlu)
- [ ] **Mobil Pro-gating/upsell** ekle (insights'ta yok; `UserModel.isPro` tanımlı ama kullanılmıyor)
- [ ] **pom-firestore'un benzersiz admin özelliklerini** TSX admin'e yeniden yaz: FeatureFlags, LegalTexts/KVKK, Announcements, Banks, Disputes + firestore/schema.md (silinen branch SHA `ce779a8`'den kurtarılabilir)
- [x] Temizlik: orphan `pom/` kaldırıldı — benzersiz işi `salvage/pom-gate-survey-wip` branch'ine + `../PoM-salvage/pom-gate-survey-wip.bundle`'a kurtarıldı (gate-survey WIP), scriptler→`scripts/`, `TECHNICAL_OVERVIEW.md`→`docs/`; `stash@{0}` arşivlenip (`../PoM-salvage/stash0-rules-admin-backup.patch`) drop edildi. ⚠️ `compassionate-antonelli` boş klasörü kilitli kaldı (bir process tutuyor; o oturum/terminal kapanınca `rmdir` ile silinir)
- [ ] Stripe API key'leri: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- [ ] LinkedIn OAuth: `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`
- [ ] Functions Node.js 20 → 22 yükseltme (20, 2026-10-30'da devre dışı)
- [ ] Mobile: gerçek cihazda uçtan uca test
