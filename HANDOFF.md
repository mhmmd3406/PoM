# PoM — Oturum Devir Dokümanı (Handoff)

> Son güncelleme: 2026-06-13. Anket sonuçlarını mobil uygulamaya getirme işinin (Faz 0–2c) devamı için. Bir sonraki oturumda buradan devam et.

## 0. Mevcut Durum (snapshot)

**Branch:** `feat/survey-aggregate-data` → **PR #34** (OPEN, MERGEABLE). main'den 8 commit önde.

**Canlıya deploy edilmiş (prod `pomapp-c3ccc`):**
- Cloud Function `computeSurveyAggregate` (region `europe-west1`, node22, schedule `every 24 hours`).
  - Cloud Scheduler job: `firebase-schedule-computeSurveyAggregate-europe-west1`.
- `firestore.rules` (yeni `survey_aggregates` + `survey_benchmarks` blokları).

**Prod veri durumu:**
- Gate anketi: `surveys/UvBNk4IL4oe1VW2xFznT` ("Genel Çalışan Deneyimi Anketi 1", 48 soru / 12 kategori + eNPS, `status=active`, `responseCount=400`).
- `survey_responses`: **3 gerçek + 397 `seed:true`** (join-tutarlı, `userIdHash = sha256(uid)`).
- `survey_aggregates/{surveyId}__{companyId}`: 12 doc (5 banka görünür, comp_* min-N altı kilitli).
- `survey_benchmarks/{surveyId}`: 1 doc, 5 banka + Bankacılık sektörü.
- `companies`: `industry` + `employeeCount` dolduruldu.

**Tamamlanan fazlar:**
- Faz 0–1: skorlama motoru + ana sayfa "Deneyim Karnem" + İçgörüler kişisel anket bölümü (PR #32, #33 — merge edildi).
- Faz 2.0: veri temeli (prod seed + join doğrulama).
- Faz 2a: `computeSurveyAggregate` CF + rules + İçgörüler "Karşılaştırma" sekmesi (Sen/Şirket/Sektör, kendi-şirket kısıtlı).
- Faz 2c: `survey_benchmarks` (çapraz-şirket) + Şirket Karşılaştırması ekranında çoklu-şirket anket kıyası.
- (Faz 2a+2c → **PR #34**.)

**Mimari kararı (önemli):** Gate anketi platform anketidir (`companyId='__admin__'`), yani `survey_responses` gerçek şirketi taşımaz. CF her user için `sha256(uid)` hesaplayıp `response.userIdHash`'e **join** yapar (Option A). Submit yazım yolu değişmez, anonimlik korunur. min-N: şirket ≥15, departman ≥10 (`platform_config/thresholds`).

---

## P0 — PR #34'ü kapat (en öncelikli, hızlı)

1. **CI yeşil olunca merge:** `gh pr merge 34 --squash --delete-branch`
2. **Merge sonrası:** worktree'yi güncel main'e rebase et; lokal branch'i sil.
3. **`functions/package-lock.json` untracked** — `npm install` üretti. Tekrarlanabilir CF build'i için repoya eklenmeli (ayrı küçük commit).

---

## P1 — Lansman öncesi ZORUNLU (anket özelliği canlıya çıkmadan)

4. **Demo/seed veriyi temizle:**
   ```
   node scripts/seed_gate_aggregate_data.js --purge
   ```
   397 `seed:true` yanıtı siler, `responseCount`'u gerçek değere (3) indirir. Sonra CF bir sonraki çalışmada `survey_aggregates`/`survey_benchmarks`'i boş/locked üretir (doğru davranış). **ŞİMDİ YAPMA** — demo verisi şu an faydalı.

5. **CF zamanlamasını doğrula/ayarla:** `every 24 hours` → ilk/sonraki tetik zamanı belirsiz. Anket döneminde daha sık istenebilir (`functions/src/index.ts` → `onSchedule({schedule: ...})` → redeploy). Manuel tetik: Cloud Scheduler `:run` REST (firebase-tools OAuth token **bazen 401** veriyor → gerekirse `firebase login --reauth`).

6. **GERÇEK girişli kullanıcıyla uçtan uca test (KRİTİK):** Tüm cihaz testleri **debug-bypass** ile yapıldı; bypass'ta **Firebase auth YOK** (bkz. P2-7). `survey_benchmarks`/`survey_aggregates` gibi auth-gerektiren okumalar bypass'ta **fixture** ile doğrulandı. Üretim akışında (LinkedIn girişi) bu doc'ların gerçekten okunduğu doğrulanmalı. Bunun için önce LinkedIn OAuth env'leri (P3-15) gerekebilir.

---

## P2 — Bu oturumda açılan/fark edilen teknik borçlar

7. **Debug-bypass'ta Firebase anonim giriş yok** — `mobile/lib/main.dart` / `auth_provider.dart`'ta `signInAnonymously` çağrısı yok; `_testUser` sentetik (`_kDebugUsers[1]`, Mehmet/garanti_bbva/Pro). Sonuç: bypass'ta auth-gerektiren + cache'siz yeni doc'lar okunamıyor → her cihaz testinde fixture gerekiyor.
   - **Öneri:** bypass'a `FirebaseAuth.instance.signInAnonymously()` ekle (Firebase Console'da Anonymous provider açık olmalı). Cihaz testleri gerçek okuma yapar, fixture'a gerek kalmaz. **Risk:** rules'ın anon kullanıcıya ne açtığını gözden geçir.

8. **Haftalık-nabız trend/delta HÂLÂ sahte** — `mobile/lib/features/insights/presentation/insights_screen.dart`: `_kFakeDeltas`, `_kTrendSeries` (Sen/Şirket sekmelerindeki "BOYUT BAZINDA DEĞİŞİM" + "Son 4 Check-in" grafiği). Bunlar anket değil **check-in** verisi; gerçeğe bağlamak check-in geçmişi toplama (yeni CF/sorgu) ister. Ayrı iş.

9. **/benchmarking 5-boyut verisi mock** — `benchmarking_provider.dart` `_mockCompanies` (debug) + prod `searchCompanies`. 5-boyut check-in benchmark'ı da gerçek veriye bağlanabilir (Faz 2b).

10. **Karşılaştırmada eNPS gösterilmiyor** — `_SurveyComparisonCard` sadece 12 kategori barı gösteriyor; modelde `BenchGroup.enps` var ama UI'da yok. İstenirse eklenir.

11. **"En güçlü/gelişime açık alan" kıyasa duyarsız** — kullanıcı "ilerde kıyaslama yapılan verilere göre değişken yapabiliriz" dedi. Şu an sadece kişisel.

12. **Karanlık modda highlight kart kontrastı** — sage-zeminli "EN GÜÇLÜ ALANIN" başlık metni karanlık modda düşük kontrast (mevcut desen, Faz 1).

---

## P3 — CLAUDE.md backlog (genel, bu işle doğrudan ilgisiz)

13. **main'i GitHub'da korumaya al** (Settings → Branches: PR + CI zorunlu).
14. **Stripe env:** `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`.
15. **LinkedIn OAuth env:** `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET` (P1-6 için lazım).
16. **Mevcut 11 fonksiyon node20** (yeni CF node22). 20, 2026-10-30'da devre dışı → hepsini 22'ye taşı + redeploy.
17. **Silinen admin özelliklerini TSX panele geri yaz:** FeatureFlags, LegalTexts/KVKK, Announcements, Banks, Disputes (kurtarma SHA `ce779a8`).
18. **Temizlik:** orphan worktree'ler (bazıları untracked dosya içeriyor, force gerekebilir), `stash@{0}`, nested `pom/`.
19. **Admin panel veri göstermiyor** — ayrı tanı gerekiyor (memory'de "Açık Sorun" notu).

---

## Yararlı komutlar / ipuçları

- **Veri scripti:** `node scripts/seed_gate_aggregate_data.js [--plan|--apply|--purge|--verify|--write-aggregates]`
  - `--plan`: yazmadan rapor · `--apply`: companies + seed yanıtlar · `--purge`: seed yanıtları sil · `--verify`: join + min-N agregat (CF referans implementasyonu) · `--write-aggregates`: survey_aggregates + survey_benchmarks doc'larını CF şekliyle yaz.
  - Auth: firebase-tools OAuth refresh token → Firestore REST (Owner, kuralları bypass eder; SA gerekmez). Token bazen 401 → `firebase login --reauth`.
- **Debug APK + cihaz:** `cd mobile && flutter build apk --debug --dart-define=BYPASS_AUTH=true` → `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. Bypass `_kDebugUsers[1]` ile açılır.
- **Cihaz tap koordinatı:** `adb shell uiautomator dump /sdcard/ui.xml` → `adb shell cat /sdcard/ui.xml` (Flutter semantics `content-desc` + `bounds` verir). Tahmin etme, gerçek bounds kullan.
- **Cihazda dolu veri görmek için fixture'lar** (şimdi geri alındı, repoda YOK): `_testUser.surveyAnswers` (48 soru ID'si `surveys/UvBNk4IL...`'den okunur), `surveyAggregateProvider`/`surveyBenchmarkProvider` bypass kısa-devresi. Gerekirse yeniden yazılır (git history'de `c65b4ac` öncesi working-tree'de vardı).
- **CF logu:** `firebase functions:log --only computeSurveyAggregate`
- **CF/rules deploy:** `firebase deploy --only functions:computeSurveyAggregate` / `firebase deploy --only firestore:rules`

---

## Önemli dosyalar

| Alan | Dosya |
|---|---|
| Skorlama motoru | `mobile/lib/features/surveys/data/survey_scoring.dart` |
| Kişisel sonuç ekranı | `mobile/lib/features/surveys/presentation/survey_result_screen.dart` |
| Anket provider'ları | `mobile/lib/features/surveys/providers/surveys_provider.dart` |
| Agregat/benchmark modelleri | `mobile/lib/features/surveys/data/survey_aggregate.dart`, `survey_benchmark.dart` |
| Ana sayfa kartı | `mobile/lib/features/home/presentation/home_screen.dart` (`_ExperienceReportCard`) |
| İçgörüler | `mobile/lib/features/insights/presentation/insights_screen.dart` (`_SurveyInsightsSection`, `_SurveyComparisonSection`) |
| Şirket Karşılaştırması | `mobile/lib/features/benchmarking/presentation/benchmarking_screen.dart` (`_SurveyComparisonCard`) |
| Cloud Function | `functions/src/index.ts` (`computeSurveyAggregate`) |
| Kurallar | `firestore.rules` |
| Veri scripti | `scripts/seed_gate_aggregate_data.js` |
