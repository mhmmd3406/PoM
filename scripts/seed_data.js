#!/usr/bin/env node
/**
 * PoM (Peace of Mind) — Firestore Seed Script
 *
 * Generates realistic synthetic data for the mobile app:
 *   - companies      (5 Turkish banks)
 *   - users          (350+) with wallets & subscriptions
 *   - checkins       (6 months, 2-4 per user per month)
 *   - insights       (pre-computed per user)
 *   - transactions   (for paid users)
 *   - platform_config
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

// ─── Seed window ─────────────────────────────────────────────────────────────

const SEED_MONTHS = [
  { year: 2025, month: 12 },
  { year: 2026, month: 1 },
  { year: 2026, month: 2 },
  { year: 2026, month: 3 },
  { year: 2026, month: 4 },
  { year: 2026, month: 5 },
];

// ─── Dimension mapping ────────────────────────────────────────────────────────
// Mobile reads Turkish keys from scores{} map AND English flat fields as fallback.
// Insight documents use English keys (matching InsightModel._dimensionOrder).

const DIMENSIONS_TR = [
  'Genel Ruh Hali',
  'İş Stresi',
  'Takım Uyumu',
  'Kişisel Gelişim',
  'İş-Yaşam Dengesi',
];

const DIMENSIONS_EN = [
  'overallMood',
  'workStress',
  'teamHarmony',
  'personalGrowth',
  'workLifeBalance',
];

// ─── Privacy thresholds ───────────────────────────────────────────────────────

const COMPANY_MIN_N = 15;
const DEPT_MIN_N    = 10;

// ─── Companies ────────────────────────────────────────────────────────────────
// base scores reflect market perception on a 1-5 scale.

const COMPANIES = [
  {
    id: 'akbank',
    name: 'Akbank T.A.Ş.',
    sector: 'banking',
    userCount: 75,
    // Solid private bank, good culture, mid-tier compensation
    base: { overallMood: 4.0, workStress: 3.5, teamHarmony: 3.9, personalGrowth: 3.8, workLifeBalance: 3.7 },
  },
  {
    id: 'garanti_bbva',
    name: 'Garanti BBVA',
    sector: 'banking',
    userCount: 85,
    // Best comp in sector, modern culture, BBVA influence on work model
    base: { overallMood: 4.2, workStress: 3.3, teamHarmony: 4.1, personalGrowth: 4.0, workLifeBalance: 3.9 },
  },
  {
    id: 'is_bankasi',
    name: 'İş Bankası',
    sector: 'banking',
    userCount: 80,
    // Legacy bank, strong benefits, slower remote adoption
    base: { overallMood: 3.9, workStress: 3.7, teamHarmony: 3.8, personalGrowth: 3.6, workLifeBalance: 3.5 },
  },
  {
    id: 'yapi_kredi',
    name: 'Yapı Kredi',
    sector: 'banking',
    userCount: 65,
    // Good WLB, slightly below market on growth
    base: { overallMood: 3.8, workStress: 3.6, teamHarmony: 3.7, personalGrowth: 3.7, workLifeBalance: 4.1 },
  },
  {
    id: 'ziraat_bankasi',
    name: 'Ziraat Bankası',
    sector: 'banking',
    userCount: 60,
    // State bank: strong team culture, limited remote, slower growth
    base: { overallMood: 3.5, workStress: 3.8, teamHarmony: 4.0, personalGrowth: 3.3, workLifeBalance: 3.3 },
  },
];

// ─── Departments ──────────────────────────────────────────────────────────────
// delta is added to each company's base score; clamped to [1, 5].

const DEPARTMENTS = [
  {
    id: 'hq_it',
    name: 'HQ IT & Teknoloji',
    weight: 0.18,
    // Remote-first, premium pay, great WLB
    delta: { overallMood: 0.3, workStress: 0.4, teamHarmony: 0.1, personalGrowth: 0.35, workLifeBalance: 0.45 },
  },
  {
    id: 'sube_operasyonlari',
    name: 'Şube Operasyonları',
    weight: 0.22,
    // In-person, weekend pressure, lower WLB
    delta: { overallMood: -0.2, workStress: -0.45, teamHarmony: -0.1, personalGrowth: -0.2, workLifeBalance: -0.55 },
  },
  {
    id: 'kurumsal_bankacılık',
    name: 'Kurumsal Bankacılık',
    weight: 0.14,
    // High pay, deal pressure → worse WLB
    delta: { overallMood: 0.2, workStress: -0.2, teamHarmony: 0.1, personalGrowth: 0.25, workLifeBalance: -0.35 },
  },
  {
    id: 'perakende_bankacılık',
    name: 'Perakende Bankacılık',
    weight: 0.18,
    // Branch-adjacent but more digital
    delta: { overallMood: -0.1, workStress: -0.2, teamHarmony: 0.15, personalGrowth: 0.05, workLifeBalance: -0.25 },
  },
  {
    id: 'risk_uyum',
    name: 'Risk & Uyum',
    weight: 0.10,
    // Always under regulatory pressure → lowest WLB
    delta: { overallMood: 0.0, workStress: -0.5, teamHarmony: 0.2, personalGrowth: 0.1, workLifeBalance: -0.65 },
  },
  {
    id: 'insan_kaynaklari',
    name: 'İnsan Kaynakları',
    weight: 0.08,
    // Culture champions, good WLB, below-market pay
    delta: { overallMood: 0.25, workStress: 0.2, teamHarmony: 0.4, personalGrowth: 0.15, workLifeBalance: 0.35 },
  },
  {
    id: 'finans_muhasebe',
    name: 'Finans & Muhasebe',
    weight: 0.10,
    delta: { overallMood: 0.1, workStress: -0.1, teamHarmony: 0.0, personalGrowth: 0.1, workLifeBalance: -0.2 },
  },
];

// ─── Turkish names ────────────────────────────────────────────────────────────

const FIRST_NAMES = [
  'Ahmet', 'Mehmet', 'Ali', 'Mustafa', 'Hasan', 'Hüseyin', 'İbrahim', 'İsmail', 'Ömer', 'Yusuf',
  'Fatma', 'Ayşe', 'Emine', 'Hatice', 'Zeynep', 'Elif', 'Merve', 'Selin', 'Büşra', 'Esra',
  'Murat', 'Emre', 'Can', 'Onur', 'Burak', 'Cem', 'Serkan', 'Tolga', 'Ozan', 'Berk',
  'Seda', 'Gizem', 'Dilan', 'Cansu', 'Pınar', 'Aslı', 'Deniz', 'İpek', 'Ceren', 'Nihan',
  'Kemal', 'Orhan', 'Selim', 'Tarık', 'Barış', 'Volkan', 'Umut', 'Alp', 'Enes', 'Kaan',
  'Sibel', 'Bahar', 'Nur', 'Özge', 'Tuğba', 'Şeyma', 'Yasemin', 'Reyhan', 'Filiz', 'Gamze',
];

const LAST_NAMES = [
  'Yılmaz', 'Kaya', 'Demir', 'Şahin', 'Çelik', 'Yıldız', 'Yıldırım', 'Öztürk', 'Aydın', 'Özdemir',
  'Arslan', 'Doğan', 'Kılıç', 'Aslan', 'Çetin', 'Koç', 'Kurt', 'Özkan', 'Şimşek', 'Polat',
  'Erdoğan', 'Karahan', 'Güneş', 'Taş', 'Kara', 'Korkmaz', 'Güler', 'Çakır', 'Demirci', 'Aktaş',
  'Yıldırım', 'Keskin', 'Bulut', 'Akar', 'Tekin', 'Sarı', 'Tan', 'Bozkurt', 'Atmaca', 'Kaplan',
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function clamp(v, min = 1, max = 5) {
  return Math.max(min, Math.min(max, v));
}

function normalInt(mu, sigma = 0.7) {
  let u = 0, v = 0;
  while (u === 0) u = Math.random();
  while (v === 0) v = Math.random();
  const n = Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
  return Math.round(clamp(mu + n * sigma));
}

function randomChoice(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomId(len = 16) {
  return Array.from({ length: len }, () => Math.floor(Math.random() * 36).toString(36)).join('');
}

function randomHex(len = 64) {
  return Array.from({ length: len }, () => Math.floor(Math.random() * 16).toString(16)).join('');
}

function monthDrift(idx) {
  return idx * 0.04; // slight positive trend over the 6-month window
}

function randomDateInMonth(year, month) {
  const day  = Math.floor(Math.random() * 28) + 1;
  const hour = Math.floor(Math.random() * 10) + 8; // 08:00-18:00
  const min  = Math.floor(Math.random() * 60);
  return new Date(year, month - 1, day, hour, min, 0);
}

function avg(values) {
  if (!values.length) return 0;
  return values.reduce((s, v) => s + v, 0) / values.length;
}

function olsSlope(values) {
  const n = values.length;
  if (n < 2) return 0;
  const xMean = (n - 1) / 2;
  const yMean = avg(values);
  let num = 0, den = 0;
  for (let i = 0; i < n; i++) {
    num += (i - xMean) * (values[i] - yMean);
    den += (i - xMean) ** 2;
  }
  return den === 0 ? 0 : num / den;
}

function trendInt(slope) {
  if (slope >  0.05) return  1;
  if (slope < -0.05) return -1;
  return 0;
}

async function flushBatch(db, ops) {
  const BATCH_SIZE = 400;
  for (let i = 0; i < ops.length; i += BATCH_SIZE) {
    const batch = db.batch();
    for (const { ref, data, merge } of ops.slice(i, i + BATCH_SIZE)) {
      if (merge) batch.set(ref, data, { merge: true });
      else       batch.set(ref, data);
    }
    await batch.commit();
    process.stdout.write(`  ✓ ${Math.min(i + BATCH_SIZE, ops.length)}/${ops.length}\r`);
  }
  process.stdout.write('\n');
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function seed() {
  const isProd = process.argv.includes('--prod');

  if (isProd) {
    console.warn('⚠️  --prod flag detected. Writing to PRODUCTION Firestore!');
    admin.initializeApp();
  } else {
    process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
    admin.initializeApp({ projectId: 'pom-dev' });
    console.log(`🔧  Emulator mode → ${process.env.FIRESTORE_EMULATOR_HOST}\n`);
  }

  const db = admin.firestore();
  db.settings({ ignoreUndefinedProperties: true });

  const serverNow = admin.firestore.FieldValue.serverTimestamp();

  // ── 1. platform_config ─────────────────────────────────────────────────────

  console.log('⚙️   Writing platform_config...');
  await db.collection('platform_config').doc('thresholds').set({
    company_min_n:        COMPANY_MIN_N,
    department_min_n:     DEPT_MIN_N,
    company_filter_size:  200,
    checkin_cooldown_days: 7,
    kvkk_version:         '1.0',
    safety_floor_company:    7,
    safety_floor_department: 5,
  }, { merge: true });

  await db.collection('platform_config').doc('stripe_plans').set({
    pro:        { price_id: 'price_REPLACE_ME_PRO', amount: 19900, currency: 'try' },
    enterprise: { price_id: 'price_REPLACE_ME_ENT', amount: 99900, currency: 'try' },
  }, { merge: true });

  // ── 2. companies ───────────────────────────────────────────────────────────

  console.log('🏦  Writing companies...');
  await flushBatch(db, COMPANIES.map((c) => ({
    ref: db.collection('companies').doc(c.id),
    data: {
      id:     c.id,
      name:   c.name,
      sector: c.sector,
      created_at: serverNow,
    },
  })));

  // ── 3. Build user roster ───────────────────────────────────────────────────

  console.log('👥  Building user roster...');
  const users = [];
  const usedKeys = new Set();

  for (const company of COMPANIES) {
    let remaining = company.userCount;

    for (const [dIdx, dept] of DEPARTMENTS.entries()) {
      const isLast = dIdx === DEPARTMENTS.length - 1;
      const count  = isLast ? remaining : Math.max(1, Math.round(company.userCount * dept.weight));
      remaining -= count;

      for (let i = 0; i < count; i++) {
        let displayName;
        let attempt = 0;
        do {
          const fn = randomChoice(FIRST_NAMES);
          const ln = randomChoice(LAST_NAMES);
          displayName = `${fn} ${ln}`;
          attempt++;
        } while (usedKeys.has(`${displayName}__${company.id}`) && attempt < 20);
        usedKeys.add(`${displayName}__${company.id}`);

        const uid = randomId(16);

        // Role distribution: 70 % free · 20 % pro · 10 % enterprise
        const rnd = Math.random();
        const role = rnd < 0.70 ? 'free' : rnd < 0.90 ? 'pro' : 'enterprise';
        const creditBalance = role === 'free' ? 0 : Math.floor(Math.random() * 10 + 1) * 50;

        users.push({ uid, displayName, role, creditBalance, companyId: company.id, dept, companyBase: company.base });
      }
    }
  }

  console.log(`   ${users.length} users built\n`);

  // ── 4. users · wallets · subscriptions ────────────────────────────────────

  console.log('📝  Writing users...');
  await flushBatch(db, users.map((u) => {
    const createdAt = admin.firestore.Timestamp.fromDate(
      new Date(2025, 10, Math.floor(Math.random() * 28) + 1) // Nov 2025 onboarding
    );
    return {
      ref: db.collection('users').doc(u.uid),
      data: {
        uid:            u.uid,
        linkedinHash:   randomHex(64),
        displayName:    u.displayName,
        avatarUrl:      null,
        role:           u.role,
        isAdmin:        false,
        kvkkAccepted:   true,
        kvkkVersion:    '1.0',
        kvkkAcceptedAt: createdAt,
        creditBalance:  u.creditBalance,
        companyId:      u.companyId,
        department:     u.dept.id,
        createdAt,
        lastCheckinAt: null,
        deleted:        false,
      },
    };
  }));

  console.log('💼  Writing wallets...');
  await flushBatch(db, users.map((u) => {
    const createdAt = admin.firestore.Timestamp.fromDate(
      new Date(2025, 10, Math.floor(Math.random() * 28) + 1)
    );
    const totalPurchased = u.role !== 'free'
      ? u.creditBalance + Math.floor(Math.random() * 3) * 50
      : 0;
    return {
      ref: db.collection('wallets').doc(u.uid),
      data: {
        userId:          u.uid,
        credits:         u.creditBalance,
        total_purchased: totalPurchased,
        created_at:      createdAt,
        updated_at:      admin.firestore.Timestamp.now(),
      },
    };
  }));

  console.log('🔖  Writing subscriptions...');
  await flushBatch(db, users.map((u) => {
    const createdAt = admin.firestore.Timestamp.fromDate(
      new Date(2025, 10, Math.floor(Math.random() * 28) + 1)
    );
    const isPaid = u.role !== 'free';
    return {
      ref: db.collection('subscriptions').doc(u.uid),
      data: {
        userId:                  u.uid,
        plan:                    u.role,
        status:                  'active',
        stripe_customer_id:      isPaid ? `cus_${randomId(14)}` : null,
        stripe_subscription_id:  isPaid ? `sub_${randomId(14)}` : null,
        current_period_end:      isPaid
          ? admin.firestore.Timestamp.fromDate(new Date(2026, 5, 30))
          : null,
        created_at: createdAt,
        updated_at: admin.firestore.Timestamp.now(),
      },
    };
  }));

  // ── 5. Check-ins ───────────────────────────────────────────────────────────

  console.log('\n📅  Writing check-ins...');

  const checkinOps = [];
  const userHistory = {}; // uid → [{ scores: {EN_key: int}, date }]

  for (const [mIdx, { year, month }] of SEED_MONTHS.entries()) {
    const drift = monthDrift(mIdx);

    for (const u of users) {
      const checkinsThisMonth = Math.floor(Math.random() * 3) + 2; // 2-4

      for (let ci = 0; ci < checkinsThisMonth; ci++) {
        // Compute mean score per dimension
        const enScores = {};
        for (const key of DIMENSIONS_EN) {
          const mu = clamp(u.companyBase[key] + u.dept.delta[key] + drift, 1, 5);
          enScores[key] = normalInt(mu);
        }

        // Turkish scores map (what the mobile's CheckinModel reads)
        const trScores = {};
        for (const [i, trKey] of DIMENSIONS_TR.entries()) {
          trScores[trKey] = enScores[DIMENSIONS_EN[i]].toFixed(1) * 1; // float
        }

        const date = randomDateInMonth(year, month);
        const ts   = admin.firestore.Timestamp.fromDate(date);
        const docId = `${u.uid}_${year}_${String(month).padStart(2, '0')}_${ci}`;

        checkinOps.push({
          ref: db.collection('checkins').doc(docId),
          data: {
            uid:        u.uid,
            userId:     u.uid,
            companyId:  u.companyId,
            department: u.dept.id,
            // Turkish keyed map (primary read path in CheckinModel)
            scores: trScores,
            // Flat English fields (fallback read path)
            overallMood:    enScores.overallMood,
            workStress:     enScores.workStress,
            teamHarmony:    enScores.teamHarmony,
            personalGrowth: enScores.personalGrowth,
            workLifeBalance: enScores.workLifeBalance,
            isAnonymized: true,
            createdAt:    ts,
            created_at:   ts,
          },
        });

        if (!userHistory[u.uid]) userHistory[u.uid] = [];
        userHistory[u.uid].push({ enScores, date });
      }
    }

    console.log(`   ${year}-${String(month).padStart(2, '0')}: ${checkinOps.length} total so far`);
  }

  await flushBatch(db, checkinOps);

  // Update lastCheckinAt
  const lastCheckinUpdates = [];
  for (const u of users) {
    const hist = userHistory[u.uid];
    if (!hist || !hist.length) continue;
    hist.sort((a, b) => a.date - b.date);
    lastCheckinUpdates.push({
      ref: db.collection('users').doc(u.uid),
      data: { lastCheckinAt: admin.firestore.Timestamp.fromDate(hist.at(-1).date) },
      merge: true,
    });
  }
  console.log('\n🕐  Updating lastCheckinAt...');
  await flushBatch(db, lastCheckinUpdates);

  // ── 6. Insights (pre-computed) ─────────────────────────────────────────────

  console.log('\n📊  Computing insights...');

  // Accumulate all check-in scores per company for company averages
  const companyDimValues = {}; // companyId → EN_key → [values]
  for (const u of users) {
    for (const { enScores } of (userHistory[u.uid] || [])) {
      if (!companyDimValues[u.companyId]) {
        companyDimValues[u.companyId] = Object.fromEntries(DIMENSIONS_EN.map((k) => [k, []]));
      }
      for (const k of DIMENSIONS_EN) companyDimValues[u.companyId][k].push(enScores[k]);
    }
  }

  // Sector benchmark (average across all companies)
  const sectorDimValues = Object.fromEntries(DIMENSIONS_EN.map((k) => [k, []]));
  for (const dims of Object.values(companyDimValues)) {
    for (const k of DIMENSIONS_EN) sectorDimValues[k].push(...dims[k]);
  }
  const benchmarkScores = Object.fromEntries(
    DIMENSIONS_EN.map((k) => [k, parseFloat(avg(sectorDimValues[k]).toFixed(2))])
  );

  const insightOps = [];
  for (const u of users) {
    const hist = (userHistory[u.uid] || []).sort((a, b) => a.date - b.date);
    if (!hist.length) continue;

    const personalScores = Object.fromEntries(
      DIMENSIONS_EN.map((k) => [k, parseFloat(avg(hist.map((h) => h.enScores[k])).toFixed(2))])
    );

    // OLS trend on overall average per check-in
    const timeSeries = hist.map((h) => avg(DIMENSIONS_EN.map((k) => h.enScores[k])));
    const slope  = olsSlope(timeSeries);
    const trend  = trendInt(slope);

    // Company scores (only if N ≥ COMPANY_MIN_N)
    let companyScores = null;
    const cDims = companyDimValues[u.companyId];
    if (cDims && cDims[DIMENSIONS_EN[0]].length >= COMPANY_MIN_N) {
      companyScores = Object.fromEntries(
        DIMENSIONS_EN.map((k) => [k, parseFloat(avg(cDims[k]).toFixed(2))])
      );
    }

    insightOps.push({
      ref: db.collection('insights').doc(u.uid),
      data: {
        uid:             u.uid,
        companyId:       u.companyId,
        personalScores,
        companyScores,
        benchmarkScores,
        totalCheckins:   hist.length,
        trend,
        updatedAt:       admin.firestore.Timestamp.now(),
      },
    });
  }

  await flushBatch(db, insightOps);

  // ── 7. Transactions (paid users only) ─────────────────────────────────────

  console.log('\n💳  Writing transactions...');
  const txOps = [];
  const CREDIT_PACKS = [100, 200, 300, 500];

  for (const u of users) {
    if (u.role === 'free') continue;
    const txCount = Math.floor(Math.random() * 3) + 1;
    for (let i = 0; i < txCount; i++) {
      const credits = randomChoice(CREDIT_PACKS);
      const txDate  = new Date(2025, 10 + Math.min(i, 1), Math.floor(Math.random() * 28) + 1);
      txOps.push({
        ref: db.collection('transactions').doc(),
        data: {
          userId:                u.uid,
          type:                  'purchase',
          creditAmount:          credits,
          amount:                credits * 100, // kuruş
          currency:              'try',
          status:                'succeeded',
          description:           `${credits} kredi satın alma`,
          stripePaymentIntentId: `pi_${randomId(24)}`,
          created_at:            admin.firestore.Timestamp.fromDate(txDate),
        },
      });
    }
  }

  await flushBatch(db, txOps);

  // ── Summary ────────────────────────────────────────────────────────────────

  const byRole = { free: 0, pro: 0, enterprise: 0 };
  for (const u of users) byRole[u.role] = (byRole[u.role] || 0) + 1;

  console.log('\n' + '─'.repeat(60));
  console.log('✅  Seed complete!\n');
  console.log(`Companies    : ${COMPANIES.length}`);
  console.log(`Users        : ${users.length}  (free ${byRole.free} · pro ${byRole.pro} · enterprise ${byRole.enterprise})`);
  console.log(`Check-ins    : ${checkinOps.length}`);
  console.log(`Insights     : ${insightOps.length}`);
  console.log(`Transactions : ${txOps.length}`);

  console.log('\n📈  May 2026 benchmark (sector):\n');
  for (const [k, v] of Object.entries(benchmarkScores)) {
    console.log(`  ${k.padEnd(20)} ${v}`);
  }

  console.log('\n📈  May 2026 company averages (overallMood · workLifeBalance):\n');
  for (const c of COMPANIES) {
    const dims = companyDimValues[c.id];
    if (!dims) continue;
    const mood = avg(dims.overallMood).toFixed(2);
    const wlb  = avg(dims.workLifeBalance).toFixed(2);
    console.log(`  ${c.name.padEnd(24)}  mood=${mood}  wlb=${wlb}`);
  }

  console.log('\n' + '─'.repeat(60) + '\n');
}

seed().catch((err) => {
  console.error('❌  Seed failed:', err);
  process.exit(1);
});
