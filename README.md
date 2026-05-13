# PoM — Peace of Mind

Banking employee happiness platform. Employees rate 5 metrics (Salary, Benefits, Work Model, Culture, WLB) weekly via emoji. Banks subscribe to aggregated insights through a B2B portal.

**Privacy guarantees:**
- Zero-knowledge identity: LinkedIn `sub` is HMAC-SHA256 hashed with a server-side salt. No PII stored.
- N < 7 rule: aggregation data is never exposed unless at least 7 unique responses exist (enforced at both Firestore rules level and Cloud Function level).
- Differential privacy: B2B clients read from snapshots published only when Δ ≥ 3 new entries exist, making individual score inference mathematically impossible.

---

## Architecture

```
Flutter (iOS/Android)
  └─ LinkedIn OAuth → Firebase Auth (custom token)
  └─ Firestore (client SDK, rules-enforced)
  └─ Cloud Functions (callable: submitCheckin, queryInsights, Stripe)

Firebase
  ├─ Auth          — custom token provider
  ├─ Firestore     — checkins, aggregations, b2b_snapshots
  ├─ Cloud Functions (Node 20)
  │    ├─ linkedinCallback  — OAuth exchange, zero-knowledge hash
  │    ├─ submitCheckin     — validates ratings, updates Welford aggregation
  │    ├─ queryInsights     — credit-gated, N<7 enforced
  │    ├─ createPaymentIntent / confirmPurchase / stripeWebhook
  │    ├─ reconcileAggregations  — nightly 03:00 UTC
  │    └─ generateB2BSnapshots   — daily 04:00 UTC (Δ≥3 guard)
  └─ Hosting       — proxy → Cloud Run B2B API

ASP.NET Core 8.0 (Cloud Run, europe-west1)
  ├─ GET /api/trend       — month-over-month happiness trend
  ├─ GET /api/benchmark   — bank vs sector delta
  ├─ POST /api/report/generate — async Excel/JSON report (Hangfire)
  └─ B2BAuthMiddleware    — Firebase ID token + b2b_bank_id claim
```

---

## Prerequisites

| Tool | Version |
|---|---|
| Node.js | 20 LTS |
| Firebase CLI | `npm i -g firebase-tools` |
| Flutter | 3.22+ |
| .NET SDK | 8.0 |
| Docker | 24+ |
| gcloud CLI | latest |
| Java | 11+ (Firestore emulator) |

---

## 1 — GCP + Firebase Setup (first time)

```bash
# 1. Create a Firebase project at console.firebase.google.com
#    Enable: Firestore, Authentication, Cloud Functions, Hosting

# 2. Run the bootstrap script (creates WIF, service accounts, Artifact Registry,
#    Secret Manager placeholders, and prints the GitHub Actions values)
export PROJECT_ID=your-firebase-project-id
bash scripts/setup-gcp.sh

# 3. Set actual secret values
firebase use $PROJECT_ID
firebase functions:secrets:set LINKEDIN_CLIENT_SECRET
firebase functions:secrets:set LINKEDIN_ID_SALT          # random 32+ byte string
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

---

## 2 — Flutter Setup

```bash
cd flutter

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for all platforms (generates lib/firebase_options.dart)
flutterfire configure --project=$PROJECT_ID

# Install dependencies
flutter pub get
```

---

## 3 — Local Development

```bash
# Start all emulators (Firestore :8080, Functions :5001, Auth :9099, UI :4000)
firebase emulators:start

# In another terminal — Flutter app pointing at emulators
cd flutter
flutter run
# The app reads FIREBASE_AUTH_EMULATOR_HOST / FIRESTORE_EMULATOR_HOST env vars
# when built in debug mode (see lib/main.dart)
```

---

## 4 — Running Tests

```bash
# Cloud Functions — unit tests (no emulator)
cd functions && npm test

# Cloud Functions — integration tests (requires Firestore emulator)
firebase emulators:exec --only firestore --project pom-test \
  "cd functions && npm run test:integration"

# .NET — unit tests
cd dotnet && dotnet test

# Flutter — unit tests
cd flutter && flutter test --coverage
```

---

## 5 — Deploying

### Firebase (rules + functions)

```bash
firebase deploy --only firestore    # Firestore rules + indexes
firebase deploy --only functions    # Cloud Functions
firebase deploy --only hosting      # Static landing page + Cloud Run proxy
```

### ASP.NET Core B2B API → Cloud Run

```bash
cd dotnet

# Build and push Docker image
docker build -t europe-west1-docker.pkg.dev/$PROJECT_ID/pom/b2b-api:latest .
docker push europe-west1-docker.pkg.dev/$PROJECT_ID/pom/b2b-api:latest

# Deploy to Cloud Run
gcloud run services replace cloudrun.yaml \
  --region=europe-west1 \
  --project=$PROJECT_ID
```

---

## 6 — CI/CD (GitHub Actions)

Three workflows trigger automatically on push to `main`:

| Workflow | Trigger paths | Steps |
|---|---|---|
| `flutter.yml` | `flutter/**` | lint → test → Android APK |
| `dotnet.yml` | `dotnet/**` | build → test → Docker → Cloud Run |
| `firebase.yml` | `firestore/**`, `functions/**` | unit tests → Firestore rules integration tests → deploy |

**Required GitHub repository settings:**

*Settings → Secrets → Actions:*
```
WIF_PROVIDER       = projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider
WIF_SERVICE_ACCOUNT = pom-cicd@PROJECT_ID.iam.gserviceaccount.com
```

*Settings → Variables → Actions:*
```
GCP_PROJECT_ID = your-firebase-project-id
```

> `scripts/setup-gcp.sh` prints the exact values for `WIF_PROVIDER` and `WIF_SERVICE_ACCOUNT` at the end of its run.

---

## Project Structure

```
PoM/
├─ firestore/
│   ├─ firestore.rules      # N<7 privacy gate, B2B bank scoping
│   ├─ indexes.json         # composite indexes
│   └─ schema.md            # collection design docs
│
├─ functions/               # Cloud Functions (Node 20)
│   ├─ src/
│   │   ├─ linkedinAuth.js  # OAuth exchange, HMAC-SHA256 zero-knowledge hash
│   │   ├─ credits.js       # credit balance, sessions, micropayments
│   │   ├─ aggregations.js  # Welford online mean, reconciliation
│   │   ├─ b2bSnapshots.js  # differential-privacy-safe snapshot publisher
│   │   ├─ stripe.js        # payment intents, webhook
│   │   └─ titleMapper.js   # LinkedIn title → Business Family (EN + TR)
│   ├─ tests/
│   │   ├─ *.test.js              # unit tests (109 tests)
│   │   └─ integration/
│   │       └─ firestoreRules.test.js  # security rules against emulator
│   └─ index.js             # function exports
│
├─ flutter/                 # Flutter mobile app (iOS + Android)
│   ├─ lib/
│   │   ├─ main.dart
│   │   ├─ router.dart
│   │   ├─ theme/app_theme.dart
│   │   ├─ models/
│   │   ├─ services/        # auth_service, firestore_service
│   │   ├─ screens/         # onboarding, checkin, insights, home
│   │   └─ widgets/
│   └─ test/
│
├─ dotnet/                  # ASP.NET Core 8.0 B2B API
│   ├─ src/PoM.B2B.Api/
│   │   ├─ Controllers/     # TrendController, BenchmarkController, ReportController
│   │   ├─ Services/        # IFirestoreService, FirestoreService, ReportGeneratorService
│   │   ├─ Jobs/            # ReportJob, WeeklyReportJob (Hangfire)
│   │   ├─ Middleware/      # B2BAuthMiddleware
│   │   └─ Models/
│   ├─ tests/PoM.B2B.Api.Tests/   # xUnit + Moq
│   ├─ Dockerfile           # multi-stage Alpine, non-root user
│   └─ cloudrun.yaml        # scale-to-zero, Secret Manager volume
│
├─ scripts/
│   └─ setup-gcp.sh         # one-shot GCP bootstrap (WIF, IAM, secrets)
│
└─ .github/workflows/
    ├─ flutter.yml
    ├─ dotnet.yml
    └─ firebase.yml
```

---

## Key Design Decisions

**Why HMAC-SHA256 instead of bcrypt for LinkedIn ID?**
LinkedIn `sub` is a fixed-length opaque identifier, not a user-chosen password. Bcrypt is designed for guessable inputs. HMAC with a 256-bit server-side salt stored in Secret Manager provides equivalent security with O(1) lookup time, which is required for Firebase Auth custom token issuance.

**Why snapshots instead of live aggregations for B2B?**
Live aggregations update on every check-in. An observer with two consecutive reads can compute `new_avg × N − old_avg × (N−1)` to recover the exact score of the Nth submitter. Snapshots published only when Δ ≥ 3 create a system of equations with more unknowns than equations — individual scores are mathematically irrecoverable.

**Why Welford online algorithm + nightly reconciliation?**
Welford avoids storing all raw values while maintaining a running mean. Under concurrent writes, the incremental path can drift slightly. The nightly full recount from raw `checkins` corrects any drift before B2B snapshots are generated at 04:00 UTC.
