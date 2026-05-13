#!/usr/bin/env bash
# PoM — GCP bootstrap script
# Run once to create all IAM resources needed for CI/CD and production.
# Prerequisites: gcloud CLI authenticated as an Owner/Editor of the project.

set -euo pipefail

# ── Config — edit these before running ────────────────────────────────────
PROJECT_ID="${PROJECT_ID:-YOUR_PROJECT_ID}"
REGION="${REGION:-europe-west1}"
GITHUB_ORG="${GITHUB_ORG:-mhmmd3406}"
GITHUB_REPO="${GITHUB_REPO:-PoM}"
# ──────────────────────────────────────────────────────────────────────────

echo "==> Setting project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# ── Enable required APIs ───────────────────────────────────────────────────
echo "==> Enabling APIs..."
gcloud services enable \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iamcredentials.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  firestore.googleapis.com \
  firebase.googleapis.com \
  --quiet

# ── Artifact Registry repo ────────────────────────────────────────────────
echo "==> Creating Artifact Registry repo..."
gcloud artifacts repositories create pom \
  --repository-format=docker \
  --location="$REGION" \
  --description="PoM Docker images" \
  --quiet 2>/dev/null || echo "  (already exists)"

# ── Service account: Cloud Run runtime ────────────────────────────────────
SA_RUNTIME="pom-b2b-api@${PROJECT_ID}.iam.gserviceaccount.com"
echo "==> Creating runtime service account..."
gcloud iam service-accounts create pom-b2b-api \
  --display-name="PoM B2B API — Cloud Run runtime" \
  --quiet 2>/dev/null || echo "  (already exists)"

# Grant Firestore access
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_RUNTIME}" \
  --role="roles/datastore.user" --quiet

# Grant Secret Manager access
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_RUNTIME}" \
  --role="roles/secretmanager.secretAccessor" --quiet

# ── Service account: CI/CD deployer ───────────────────────────────────────
SA_DEPLOYER="pom-cicd@${PROJECT_ID}.iam.gserviceaccount.com"
echo "==> Creating CI/CD deployer service account..."
gcloud iam service-accounts create pom-cicd \
  --display-name="PoM CI/CD deployer" \
  --quiet 2>/dev/null || echo "  (already exists)"

for ROLE in \
  roles/run.developer \
  roles/artifactregistry.writer \
  roles/iam.serviceAccountUser \
  roles/firebase.admin; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_DEPLOYER}" \
    --role="$ROLE" --quiet
done

# ── Workload Identity Federation (keyless CI/CD) ──────────────────────────
POOL_ID="github-pool"
PROVIDER_ID="github-provider"

echo "==> Creating Workload Identity pool..."
gcloud iam workload-identity-pools create "$POOL_ID" \
  --location=global \
  --display-name="GitHub Actions pool" \
  --quiet 2>/dev/null || echo "  (already exists)"

POOL_RESOURCE=$(gcloud iam workload-identity-pools describe "$POOL_ID" \
  --location=global --format="value(name)")

echo "==> Creating OIDC provider..."
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
  --workload-identity-pool="$POOL_ID" \
  --location=global \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor" \
  --attribute-condition="assertion.repository == '${GITHUB_ORG}/${GITHUB_REPO}'" \
  --quiet 2>/dev/null || echo "  (already exists)"

PROVIDER_RESOURCE=$(gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --workload-identity-pool="$POOL_ID" \
  --location=global \
  --format="value(name)")

echo "==> Binding deployer SA to WIF pool..."
gcloud iam service-accounts add-iam-policy-binding "${SA_DEPLOYER}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_RESOURCE}/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}" \
  --quiet

# ── Secret Manager: app secrets ───────────────────────────────────────────
echo "==> Creating secret placeholders (values must be set separately)..."
for SECRET in LINKEDIN_CLIENT_SECRET LINKEDIN_ID_SALT STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET; do
  gcloud secrets create "$SECRET" --replication-policy=automatic --quiet 2>/dev/null \
    || echo "  $SECRET already exists"
done

# Allow the Cloud Functions service account to read secrets
FUNCTIONS_SA="${PROJECT_ID}@appspot.gserviceaccount.com"
for SECRET in LINKEDIN_CLIENT_SECRET LINKEDIN_ID_SALT STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:${FUNCTIONS_SA}" \
    --role="roles/secretmanager.secretAccessor" --quiet
done

# ── Print GitHub Actions configuration values ─────────────────────────────
echo ""
echo "========================================================"
echo " Add these to GitHub → Settings → Secrets / Variables"
echo "========================================================"
echo ""
echo " Repository variable (Settings → Variables):"
echo "   GCP_PROJECT_ID = ${PROJECT_ID}"
echo ""
echo " Repository secrets (Settings → Secrets):"
echo "   WIF_PROVIDER = ${PROVIDER_RESOURCE}"
echo "   WIF_SERVICE_ACCOUNT = ${SA_DEPLOYER}"
echo ""
echo " Then set actual secret values:"
echo "   firebase functions:secrets:set LINKEDIN_CLIENT_SECRET"
echo "   firebase functions:secrets:set LINKEDIN_ID_SALT"
echo "   firebase functions:secrets:set STRIPE_SECRET_KEY"
echo "   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET"
echo "========================================================"
