#!/usr/bin/env node
/**
 * PoM Data Seed Script
 *
 * Generates 500+ realistic check-ins for 5 Turkish banks × 7 Business Families
 * with intentional trend patterns (HQ IT happier with Work-Model than Branch Ops).
 *
 * Usage:
 *   # Against Firebase Emulator (default):
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed_data.js
 *
 *   # Against real project (caution!):
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/sa.json node scripts/seed_data.js --prod
 */

'use strict';

const admin = require('firebase-admin');

// ── Configuration ────────────────────────────────────────────────────────────

const TARGET_MONTHS = [
  { year: 2026, month: 3 },
  { year: 2026, month: 4 },
  { year: 2026, month: 5 },
];

const METRICS = ['salary', 'benefits', 'work_model', 'culture', 'wlb'];
const PRIVACY_THRESHOLD = 7;

// ── Banks ────────────────────────────────────────────────────────────────────
// Base scores reflect market perception; modifiers are applied per family.

const BANKS = [
  {
    id: 'akbank',
    name: 'Akbank',
    // Solid private bank, good culture, mid-tier salary
    base: { salary: 4.1, benefits: 3.8, work_model: 3.6, culture: 4.0, wlb: 3.7 },
    userCount: 60,
  },
  {
    id: 'garanti_bbva',
    name: 'Garanti BBVA',
    // Best comp package in sector, modern culture, BBVA influence on work model
    base: { salary: 4.3, benefits: 4.1, work_model: 3.9, culture: 4.2, wlb: 3.8 },
    userCount: 70,
  },
  {
    id: 'is_bankasi',
    name: 'İş Bankası',
    // Legacy bank, strong benefits (pension, housing), slower adoption of remote
    base: { salary: 3.8, benefits: 4.3, work_model: 3.4, culture: 3.9, wlb: 3.5 },
    userCount: 65,
  },
  {
    id: 'yapi_kredi',
    name: 'Yapı Kredi',
    // Decent overall, best WLB in sector, slightly below market on salary
    base: { salary: 3.9, benefits: 3.7, work_model: 3.8, culture: 3.8, wlb: 4.1 },
    userCount: 55,
  },
  {
    id: 'ziraat_bankasi',
    name: 'Ziraat Bankası',
    // State bank: low salary, rock-solid culture & benefits (pension), old-school model
    base: { salary: 3.2, benefits: 3.9, work_model: 2.9, culture: 4.1, wlb: 3.3 },
    userCount: 50,
  },
];

// ── Business Families ─────────────────────────────────────────────────────────
// delta adjusts each bank's base score; clamp applied to [1, 5].

const FAMILIES = [
  {
    id: 'hq_it',
    name: 'HQ IT & Technology',
    weight: 0.18, // 18% of employees in this family
    delta: { salary: 0.25, benefits: 0.1, work_model: 1.3, culture: 0.0, wlb: 0.35 },
    // Key storyline: remote-first, great WLB, premium pay
  },
  {
    id: 'branch_operations',
    name: 'Branch Operations',
    weight: 0.22,
    delta: { salary: -0.1, benefits: -0.05, work_model: -1.15, culture: -0.1, wlb: -0.55 },
    // Key storyline: must be in-person, weekend pressure, lower WLB
  },
  {
    id: 'corporate_banking',
    name: 'Corporate Banking',
    weight: 0.14,
    delta: { salary: 0.45, benefits: 0.25, work_model: 0.1, culture: 0.05, wlb: -0.35 },
    // High salary, deal-pressure → worse WLB
  },
  {
    id: 'retail_banking',
    name: 'Retail Banking',
    weight: 0.18,
    delta: { salary: -0.2, benefits: -0.1, work_model: -0.3, culture: 0.15, wlb: -0.25 },
    // Branch-adjacent but more digitally enabled
  },
  {
    id: 'risk_compliance',
    name: 'Risk & Compliance',
    weight: 0.10,
    delta: { salary: 0.1, benefits: 0.1, work_model: 0.2, culture: 0.2, wlb: -0.65 },
    // Key storyline: always under regulatory pressure → lowest WLB
  },
  {
    id: 'human_resources',
    name: 'Human Resources',
    weight: 0.08,
    delta: { salary: -0.15, benefits: 0.15, work_model: 0.2, culture: 0.4, wlb: 0.35 },
    // Culture champions, good WLB, below-market salary
  },
  {
    id: 'finance_accounting',
    name: 'Finance & Accounting',
    weight: 0.10,
    delta: { salary: 0.3, benefits: 0.05, work_model: -0.05, culture: 0.1, wlb: -0.2 },
  },
];

// ── Helpers ───────────────────────────────────────────────────────────────────

function clamp(v, min = 1, max = 5) {
  return Math.max(min, Math.min(max, v));
}

/** Box-Muller normal sample, mean μ, std σ, clamped to [1,5] and rounded to int */
function normalInt(mu, sigma = 0.6) {
  let u = 0, v = 0;
  while (u === 0) u = Math.random();
  while (v === 0) v = Math.random();
  const n = Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
  return Math.round(clamp(mu + n * sigma));
}

function randomChoice(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomUid() {
  return Math.random().toString(36).slice(2, 12) + Math.random().toString(36).slice(2, 12);
}

/** Month-over-month drift: add slight positive trend to simulate engagement over time */
function monthDrift(monthIndex) {
  return monthIndex * 0.05; // +0.05 per month
}

// ── Aggregation helpers (mirror aggregations.js logic) ───────────────────────

function aggDocId(bankId, businessFamily, year, month) {
  const bankPart = bankId || 'SECTOR';
  return `${bankPart}_${businessFamily}_${year}_${String(month).padStart(2, '0')}`;
}

// ── Main seed logic ──────────────────────────────────────────────────────────

async function seed() {
  const isProd = process.argv.includes('--prod');

  if (isProd) {
    console.warn('⚠️  --prod flag detected. Writing to PRODUCTION Firestore!');
    admin.initializeApp();
  } else {
    process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
    admin.initializeApp({ projectId: 'pom-dev' });
    console.log(`🔧  Emulator mode → ${process.env.FIRESTORE_EMULATOR_HOST}`);
  }

  const db = admin.firestore();
  db.settings({ ignoreUndefinedProperties: true });

  // Accumulate aggregations in memory, then batch-write at the end.
  // Structure: aggMap[colId][docId] = { bank_id, business_family, year, month, sums, count }
  const aggMap = { aggregations: {}, sector_aggregations: {} };

  function accumulateAgg(colId, docId, bankId, businessFamily, year, month, ratings) {
    if (!aggMap[colId][docId]) {
      aggMap[colId][docId] = {
        bank_id: bankId,
        business_family: businessFamily,
        year,
        month,
        sums: Object.fromEntries([...METRICS, 'overall'].map((m) => [m, 0])),
        count: 0,
      };
    }
    const entry = aggMap[colId][docId];
    const overall = METRICS.reduce((s, m) => s + ratings[m], 0) / METRICS.length;
    for (const m of METRICS) entry.sums[m] += ratings[m];
    entry.sums.overall += overall;
    entry.count += 1;
  }

  let totalCheckins = 0;
  const checkinBatch = [];

  for (const [monthIndex, { year, month }] of TARGET_MONTHS.entries()) {
    console.log(`\n📅  Seeding ${year}-${String(month).padStart(2, '0')}...`);
    const drift = monthDrift(monthIndex);

    for (const bank of BANKS) {
      for (const family of FAMILIES) {
        // Determine how many checkins this bank×family cell gets this month
        const cellUsers = Math.round(bank.userCount * family.weight);
        // Ensure at least PRIVACY_THRESHOLD + 2 for main cells, fewer for small ones
        const count = Math.max(PRIVACY_THRESHOLD + 2, cellUsers);

        const mu = {};
        for (const m of METRICS) {
          mu[m] = clamp(bank.base[m] + family.delta[m] + drift, 1, 5);
        }

        for (let i = 0; i < count; i++) {
          const ratings = Object.fromEntries(METRICS.map((m) => [m, normalInt(mu[m])]));
          const uid = randomUid();
          const docId = `${uid}_${year}_${String(month).padStart(2, '0')}`;

          checkinBatch.push({
            docId,
            data: {
              uid,
              bank_id: bank.id,
              bank_name: bank.name,
              business_family: family.id,
              year,
              month,
              ratings,
              created_at: admin.firestore.Timestamp.fromDate(
                new Date(year, month - 1, Math.floor(Math.random() * 28) + 1),
              ),
            },
          });

          // Accumulate into all four aggregation targets
          const targets = [
            { col: 'aggregations', docId: aggDocId(bank.id, family.id, year, month), bankId: bank.id, family: family.id },
            { col: 'aggregations', docId: aggDocId(bank.id, 'all', year, month), bankId: bank.id, family: 'all' },
            { col: 'sector_aggregations', docId: aggDocId(null, family.id, year, month), bankId: null, family: family.id },
            { col: 'sector_aggregations', docId: aggDocId(null, 'all', year, month), bankId: null, family: 'all' },
          ];
          for (const t of targets) {
            accumulateAgg(t.col, t.docId, t.bankId, t.family, year, month, ratings);
          }

          totalCheckins++;
        }
      }
    }
  }

  console.log(`\n✍️  Writing ${totalCheckins} checkins in batches...`);

  // Firestore batch limit is 500 ops; chunk checkins
  const BATCH_SIZE = 400;
  for (let i = 0; i < checkinBatch.length; i += BATCH_SIZE) {
    const chunk = checkinBatch.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const { docId, data } of chunk) {
      batch.set(db.collection('checkins').doc(docId), data);
    }
    await batch.commit();
    process.stdout.write(`  ✓ ${Math.min(i + BATCH_SIZE, checkinBatch.length)}/${checkinBatch.length}\r`);
  }

  console.log('\n\n📊  Writing aggregations...');

  for (const [colId, docs] of Object.entries(aggMap)) {
    const entries = Object.entries(docs);
    for (let i = 0; i < entries.length; i += BATCH_SIZE) {
      const chunk = entries.slice(i, i + BATCH_SIZE);
      const batch = db.batch();
      for (const [docId, entry] of chunk) {
        const averages = Object.fromEntries(
          [...METRICS, 'overall'].map((m) => [m, entry.sums[m] / entry.count]),
        );
        batch.set(db.collection(colId).doc(docId), {
          bank_id: entry.bank_id,
          business_family: entry.business_family,
          department_type: 'all',
          year: entry.year,
          month: entry.month,
          entry_count: entry.count,
          averages,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    console.log(`  ✓ ${colId}: ${entries.length} documents`);
  }

  // ── Summary ──────────────────────────────────────────────────────────────
  console.log('\n' + '─'.repeat(60));
  console.log('✅  Seed complete!\n');
  console.log(`Total checkins written : ${totalCheckins}`);
  console.log(`Aggregation docs       : ${
    Object.values(aggMap).reduce((s, m) => s + Object.keys(m).length, 0)
  }`);

  console.log('\n📈  May 2026 bank scores (all families):');
  const { year, month } = TARGET_MONTHS[2];
  for (const bank of BANKS) {
    const docId = aggDocId(bank.id, 'all', year, month);
    const entry = aggMap.aggregations[docId];
    if (!entry) continue;
    const avg = Object.fromEntries(
      [...METRICS, 'overall'].map((m) => [m, (entry.sums[m] / entry.count).toFixed(2)]),
    );
    console.log(`  ${bank.name.padEnd(20)} overall=${avg.overall}  wlb=${avg.wlb}  work_model=${avg.work_model}`);
  }

  console.log('\n🏠  Work-Model by family (sector, May 2026):');
  for (const family of FAMILIES) {
    const docId = aggDocId(null, family.id, year, month);
    const entry = aggMap.sector_aggregations[docId];
    if (!entry) continue;
    const wm = (entry.sums.work_model / entry.count).toFixed(2);
    const wlb = (entry.sums.wlb / entry.count).toFixed(2);
    console.log(`  ${family.name.padEnd(28)} work_model=${wm}  wlb=${wlb}`);
  }
  console.log('─'.repeat(60) + '\n');
}

seed().catch((err) => {
  console.error('❌  Seed failed:', err);
  process.exit(1);
});
