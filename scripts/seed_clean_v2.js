#!/usr/bin/env node
'use strict';

/**
 * PoM (Peace of Mind) — Clean Reseed (schema v2)
 * =============================================================================
 * Wipes the app-data collections and reseeds them with the POST-Sprint-2 schema:
 *
 *   - users     : single canonical camelCase schema
 *                 (linkedinHash, kvkkAccepted, kvkkVersion, createdAt, updatedAt,
 *                  avatarUrl, …) + the pseudonymous `userIdHash`.
 *   - checkins  : random auto-ID, `userIdHash` only (NO raw uid/userId),
 *                 camelCase `scores` map (overallMood, workStress, …).
 *   - insights  : keyed by `userIdHash`, nested shape
 *                 { personal:{avg,checkin_count,trend_slope,retention_risk},
 *                   company:{avg,checkin_count}|null,
 *                   department_stats:{avg,checkin_count}|null, … }.
 *   - companies : existing schema (created_at, name, industry, employeeCount).
 *   - platform_config/thresholds : { company_min_n: 15, department_min_n: 10 }.
 *
 * The cohorts are sized so EVERY company clears the 15-user floor and EVERY
 * department clears the 10-user floor (PR #4a), so company + department
 * dashboards render meaningful (non-suppressed) data.
 *
 * -----------------------------------------------------------------------------
 * SAFETY (this script is DESTRUCTIVE — it deletes before it writes):
 *   • Refuses to run when NODE_ENV=production unless `--force-prod` is passed.
 *   • Defaults to the local Firestore emulator; an accidental run never touches
 *     the cloud. Targeting a real project requires `--prod` +
 *     GOOGLE_APPLICATION_CREDENTIALS (Muhammed runs this manually).
 *
 * Usage:
 *   # Local emulator (safe default):
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed_clean_v2.js
 *
 *   # Real project (manual, deliberate):
 *   GOOGLE_APPLICATION_CREDENTIALS=sa.json \
 *   USER_HASH_SALT=<same-as-functions> \
 *   node scripts/seed_clean_v2.js --prod --force-prod
 * =============================================================================
 */

const crypto = require('crypto');
const admin = require('firebase-admin');

// ─── Safety lock ──────────────────────────────────────────────────────────────

const ARGV = process.argv.slice(2);
const FORCE_PROD = ARGV.includes('--force-prod');
const PROD = ARGV.includes('--prod') || FORCE_PROD;

if (process.env.NODE_ENV === 'production' && !FORCE_PROD) {
  throw new Error(
    'Refusing to run with NODE_ENV=production. This script WIPES and reseeds the ' +
    'database. Pass --force-prod only if you truly intend to reset the live data.'
  );
}
if (PROD && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error(
    '--prod requires GOOGLE_APPLICATION_CREDENTIALS pointing at a service account.'
  );
}
if (!PROD && !process.env.FIRESTORE_EMULATOR_HOST) {
  // Default to the local emulator so an accidental run can never hit the cloud.
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
  console.log('[info] No --prod flag → defaulting to emulator at 127.0.0.1:8080');
}

// ─── Pseudonymous hash (mirrors functions/src/index.ts hashUserId) ────────────
// HMAC-SHA256(uid, USER_HASH_SALT). MUST match the Cloud Functions salt so that
// the seeded userIdHash values line up with what the live backend would derive.

const USER_HASH_SALT = process.env.USER_HASH_SALT || 'pom-user-id-hash-salt';
if (!process.env.USER_HASH_SALT) {
  console.warn(
    '[warn] USER_HASH_SALT not set — using the default dev salt. In production ' +
    'this MUST equal the Cloud Functions USER_HASH_SALT or hashes will not match.'
  );
}
const hashUserId = (uid) =>
  crypto.createHmac('sha256', USER_HASH_SALT).update(uid).digest('hex');

// ─── Init ─────────────────────────────────────────────────────────────────────

admin.initializeApp(
  PROD
    ? { credential: admin.credential.applicationDefault() }
    : { projectId: process.env.GCLOUD_PROJECT || 'pomapp-c3ccc' }
);
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

// ─── Config ───────────────────────────────────────────────────────────────────

const CANONICAL_DIMS = [
  'overallMood',
  'workStress',
  'teamHarmony',
  'personalGrowth',
  'workLifeBalance',
];

const COMPANY_MIN_N = 15; // PR #4a hard floor
const DEPT_MIN_N = 10; // PR #4a hard floor

const COMPANIES = [
  { id: 'garanti_bbva', name: 'Garanti BBVA', industry: 'Bankacılık' },
  { id: 'akbank', name: 'Akbank', industry: 'Bankacılık' },
  { id: 'turkcell', name: 'Turkcell', industry: 'Telekomünikasyon' },
  { id: 'startup_co', name: 'Startup Co', industry: 'Teknoloji' },
];

const DEPARTMENTS = ['Operasyon', 'Teknoloji', 'İnsan Kaynakları'];
const USERS_PER_DEPT = 12; // ≥ DEPT_MIN_N; company = 3 × 12 = 36 ≥ COMPANY_MIN_N

// Collections this script owns (wiped before reseed).
const OWNED_COLLECTIONS = ['users', 'checkins', 'insights', 'companies', 'wallets', 'subscriptions'];

// Aggregate lookups shared across the two write passes.
const companyAgg = {};
const companyDeptAgg = {};

// ─── Helpers ──────────────────────────────────────────────────────────────────

const randInt = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const round2 = (n) => Math.round(n * 100) / 100;

/** Positive-skewed 1–5 score so dashboards look realistic, not uniform. */
const sampleScore = () => randInt(2, 5);

/** OLS slope over integer x = 0..n-1 (mirrors the Cloud Function). */
function olsSlope(values) {
  const n = values.length;
  if (n < 2) return 0;
  const xMean = (n - 1) / 2;
  const yMean = values.reduce((s, v) => s + v, 0) / n;
  let num = 0;
  let den = 0;
  for (let i = 0; i < n; i++) {
    num += (i - xMean) * (values[i] - yMean);
    den += (i - xMean) ** 2;
  }
  return den === 0 ? 0 : num / den;
}

const avg = (vals) => (vals.length ? vals.reduce((s, v) => s + v, 0) / vals.length : null);

/** Delete every document in a collection in batches of 400. */
async function wipeCollection(name) {
  const col = db.collection(name);
  let total = 0;
  while (true) {
    const snap = await col.limit(400).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    total += snap.size;
  }
  return total;
}

// ─── Seed window (last 6 months, weekly check-ins) ────────────────────────────

function seedDates(count) {
  const out = [];
  const now = Date.now();
  for (let i = count - 1; i >= 0; i--) {
    // one check-in per week, going back from "now"
    out.push(new Date(now - i * 7 * 24 * 60 * 60 * 1000));
  }
  return out;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`[info] Target: ${PROD ? 'REAL PROJECT (--prod)' : 'emulator'}`);

  // 1) Wipe owned collections.
  for (const name of OWNED_COLLECTIONS) {
    const n = await wipeCollection(name);
    console.log(`[wipe] ${name}: deleted ${n} docs`);
  }

  // 2) Thresholds (defensive — backend floors at 15/10 regardless).
  await db.collection('platform_config').doc('thresholds').set({
    company_min_n: COMPANY_MIN_N,
    department_min_n: DEPT_MIN_N,
    _updated_at: FieldValue.serverTimestamp(),
  });

  const nowTs = Timestamp.now();
  let userCounter = 0;
  let checkinCount = 0;

  for (const company of COMPANIES) {
    // Accumulators for company-level aggregate.
    const companyScores = Object.fromEntries(CANONICAL_DIMS.map((d) => [d, []]));
    let companyCheckins = 0;

    for (const department of DEPARTMENTS) {
      const deptScores = Object.fromEntries(CANONICAL_DIMS.map((d) => [d, []]));
      let deptCheckins = 0;

      for (let u = 0; u < USERS_PER_DEPT; u++) {
        userCounter += 1;
        const uid = `seeduser_${company.id}_${department}_${u}`
          .replace(/[^a-zA-Z0-9_]/g, '');
        const userIdHash = hashUserId(uid);
        const displayName = `Kullanıcı ${userCounter}`;

        // ── user doc (camelCase schema) ──
        await db.collection('users').doc(uid).set({
          uid,
          linkedinHash: `seedhash_${userCounter}`,
          userIdHash,
          displayName,
          firstName: 'Kullanıcı',
          lastName: String(userCounter),
          avatarUrl: null,
          email: `${uid}@seed.pom.app`,
          role: 'free',
          companyId: company.id,
          department,
          kvkkAccepted: true,
          kvkkVersion: '1.0',
          createdAt: nowTs,
          updatedAt: nowTs,
          deleted: false,
        });

        // ── wallet + subscription (existing schema) ──
        await db.collection('wallets').doc(uid).set({
          userId: uid, credits: 0, total_purchased: 0,
          created_at: nowTs, updated_at: nowTs,
        });
        await db.collection('subscriptions').doc(uid).set({
          userId: uid, plan: 'free', status: 'active',
          stripe_customer_id: null, stripe_subscription_id: null,
          current_period_end: null, created_at: nowTs, updated_at: nowTs,
        });

        // ── check-ins (anonymous: auto-ID + userIdHash, camelCase scores) ──
        const dates = seedDates(randInt(4, 8));
        const personalSeries = []; // composite per check-in for trend
        const personalScores = Object.fromEntries(CANONICAL_DIMS.map((d) => [d, []]));

        for (const date of dates) {
          const ts = Timestamp.fromDate(date);
          const scores = {};
          for (const dim of CANONICAL_DIMS) {
            const s = sampleScore();
            scores[dim] = s;
            personalScores[dim].push(s);
            companyScores[dim].push(s);
            deptScores[dim].push(s);
          }
          personalSeries.push(avg(Object.values(scores)) ?? 0);

          await db.collection('checkins').add({
            userIdHash,
            scores,
            createdAt: ts,
            created_at: ts,
            companyId: company.id,
            department,
            isAnonymized: true,
          });
          checkinCount += 1;
          companyCheckins += 1;
          deptCheckins += 1;
        }

        // ── personal insight (keyed by userIdHash, nested shape) ──
        const personalAvg = {};
        for (const dim of CANONICAL_DIMS) {
          const a = avg(personalScores[dim]);
          if (a !== null) personalAvg[dim] = round2(a);
        }
        const trendSlope = olsSlope(personalSeries);
        const retentionRisk = Math.max(0, Math.min(1, 0.5 - trendSlope * 10));

        // Stash for a second pass that fills company/department aggregates.
        await db.collection('insights').doc(userIdHash).set({
          userIdHash,
          companyId: company.id,
          department_name: department,
          personal: {
            avg: personalAvg,
            checkin_count: personalSeries.length,
            trend_slope: round2(trendSlope),
            retention_risk: round2(retentionRisk),
          },
          // company / department_stats filled in the second pass below.
          updated_at: FieldValue.serverTimestamp(),
        });
      }

      // Department aggregate (shared by all users in this dept). Every dept has
      // USERS_PER_DEPT (≥ DEPT_MIN_N) users, so it always clears the floor.
      const deptAvg = {};
      for (const dim of CANONICAL_DIMS) {
        const a = avg(deptScores[dim]);
        if (a !== null) deptAvg[dim] = round2(a);
      }
      companyDeptAgg[`${company.id}__${department}`] = {
        avg: deptAvg,
        checkin_count: deptCheckins,
      };
    }

    // Company aggregate (N is guaranteed ≥ COMPANY_MIN_N by construction).
    const companyAvg = {};
    for (const dim of CANONICAL_DIMS) {
      const a = avg(companyScores[dim]);
      if (a !== null) companyAvg[dim] = round2(a);
    }
    companyAgg[company.id] = { avg: companyAvg, checkin_count: companyCheckins };

    await db.collection('companies').doc(company.id).set({
      name: company.name,
      industry: company.industry,
      employeeCount: DEPARTMENTS.length * USERS_PER_DEPT,
      created_at: nowTs,
    });
  }

  // 3) Second pass: backfill company + department aggregates into each insight.
  const insightsSnap = await db.collection('insights').get();
  let patched = 0;
  for (const doc of insightsSnap.docs) {
    const data = doc.data();
    const cId = data.companyId;
    const dept = data.department_name;
    const cAgg = companyAgg[cId];
    const dAgg = companyDeptAgg[`${cId}__${dept}`];
    await doc.ref.set(
      {
        company: cAgg ? { avg: cAgg.avg, checkin_count: cAgg.checkin_count } : null,
        department_stats: dAgg
          ? { avg: dAgg.avg, checkin_count: dAgg.checkin_count }
          : null,
      },
      { merge: true }
    );
    patched += 1;
  }

  console.log('[done] reseed complete');
  console.log(`       companies : ${COMPANIES.length}`);
  console.log(`       users     : ${userCounter}`);
  console.log(`       checkins  : ${checkinCount}`);
  console.log(`       insights  : ${patched}`);
  console.log(`       thresholds: company≥${COMPANY_MIN_N}, dept≥${DEPT_MIN_N}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('[error] reseed failed:', err);
    process.exit(1);
  });
