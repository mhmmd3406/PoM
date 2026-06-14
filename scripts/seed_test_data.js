#!/usr/bin/env node
/**
 * PoM — Test verisi tohumlayıcı (GÜNCEL ŞEMA + İSİMSİZ)
 * =============================================================================
 * scrub_pii.js sonrası "mevcut fonksiyonları kullanabileceğin" canlı test verisi
 * üretir. Bugünkü şemaya birebir uyar ve veri-minimizasyonu politikasına uygun:
 * ÜRETİLEN KULLANICILARDA AD-SOYAD / PROFİL FOTOĞRAFI YOKTUR (takma adlı).
 *
 * Üretilenler:
 *   companies/{id}     → name, industry, employeeCount, plan, isSeedData
 *   users/{id}         → linkedinHash, userIdHash, role, companyId, department,
 *                        kvkk*, creditBalance, createdAt, isSeedData  (AD/FOTO YOK)
 *   checkins/{id}      → userIdHash + scores{overallMood…} + companyId/department
 *                        + createdAt/created_at  (computeInsights ile aynı şema)
 *   insights/{hash}    → doc id = userIdHash; { personal:{avg,…}, company:{avg,…} }
 *                        computeInsights'ın yazdığı şekille birebir (app bunu okur)
 *   benchmarks/{ind}   → { scores:{dim}, n }  (app sektör benchmark'ını buradan okur)
 *
 * userIdHash = HMAC-SHA256(uid, USER_HASH_SALT) — Cloud Functions hashUserId ile
 * aynı (env yoksa aynı varsayılan salt). Böylece deploy'lu computeInsights yeni
 * check-in'lerde tutarlı çalışır.
 *
 * ⚠️ ANKET aggregate/benchmark verisi BURADA üretilmez. Anket akışını test etmek
 * için bu script'ten SONRA çalıştır (mevcut kullanıcılar üzerinden join'ler):
 *     node scripts/seed_surveys.js                       # gate anketini oluştur
 *     node scripts/seed_gate_aggregate_data.js --apply   # yanıtlar (sha256(uid))
 *     node scripts/seed_gate_aggregate_data.js --write-aggregates
 *
 * Kullanım:
 *   GOOGLE_APPLICATION_CREDENTIALS=./sa_key.json node scripts/seed_test_data.js
 *   GOOGLE_APPLICATION_CREDENTIALS=./sa_key.json node scripts/seed_test_data.js --clear
 * =============================================================================
 */

"use strict";

const admin = require("firebase-admin");
const crypto = require("crypto");
const path = require("path");

// ─── Firebase init ────────────────────────────────────────────────────────────

if (!admin.apps.length) {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (credPath) {
    admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(credPath))) });
    console.log(`🔑 Service account: ${credPath}`);
  } else {
    admin.initializeApp();
    console.log("🔑 Application Default Credentials");
  }
}

const db = admin.firestore();
const CLEAR = process.argv.includes("--clear");

// Must match functions/src/index.ts userHashSalt() fallback so the pseudonym is
// the same one the Cloud Functions derive for these uids.
const USER_HASH_SALT = process.env.USER_HASH_SALT || "pom-user-id-hash-salt";
const hashUserId = (uid) =>
  crypto.createHmac("sha256", USER_HASH_SALT).update(uid).digest("hex");

// Tunable sizes. Defaults keep every company above company_min_n (15) so company
// aggregates are visible, while staying light enough to seed quickly.
const NUM_COMPANIES = parseInt(process.env.SEED_COMPANIES || "20", 10);
const USERS_PER_COMPANY = parseInt(process.env.SEED_USERS_PER_COMPANY || "20", 10);

const DIMS = ["overallMood", "workStress", "teamHarmony", "personalGrowth", "workLifeBalance"];

// ─── Helpers ──────────────────────────────────────────────────────────────────

const rand = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const clamp = (v, mn, mx) => Math.min(Math.max(v, mn), mx);
const clampR = (v, mn, mx) => Math.min(Math.max(Math.round(v), mn), mx);
const randF = (min, max) => Math.random() * (max - min) + min;
const ts = (date) => admin.firestore.Timestamp.fromDate(date);
const daysAgo = (n) => { const d = new Date(); d.setDate(d.getDate() - n); return d; };
const mean = (a) => (a.length ? a.reduce((s, v) => s + v, 0) / a.length : 0);
const r2 = (n) => Math.round(n * 100) / 100;

function olsSlope(values) {
  const n = values.length;
  if (n < 2) return 0;
  const xMean = (n - 1) / 2;
  const yMean = mean(values);
  let num = 0, den = 0;
  for (let i = 0; i < n; i++) { num += (i - xMean) * (values[i] - yMean); den += (i - xMean) ** 2; }
  return den === 0 ? 0 : num / den;
}

// Gaussian-ish score: base ± variance, clamped to [1,5]
function genScore(base, variance = 0.8) {
  const noise = (Math.random() + Math.random() - 1) * variance * 2;
  return clampR(base + noise, 1, 5);
}

async function commitBatches(ops, label) {
  const SIZE = 450;
  for (let i = 0; i < ops.length; i += SIZE) {
    const chunk = ops.slice(i, i + SIZE);
    const batch = db.batch();
    chunk.forEach(({ ref, data }) => batch.set(ref, data));
    await batch.commit();
    process.stdout.write(`\r  ${label}: ${Math.min(i + SIZE, ops.length)}/${ops.length}   `);
  }
  console.log();
}

// ─── Data definitions ─────────────────────────────────────────────────────────

// `name` becomes the company's `industry` (computeSurveyAggregate groups by it).
const SECTORS = [
  { name: "Teknoloji",   profile: { overallMood: 3.8, workStress: 2.5, teamHarmony: 3.5, personalGrowth: 4.2, workLifeBalance: 3.0 } },
  { name: "Finans",      profile: { overallMood: 3.2, workStress: 2.0, teamHarmony: 3.2, personalGrowth: 3.5, workLifeBalance: 2.5 } },
  { name: "Sağlık",      profile: { overallMood: 3.6, workStress: 2.8, teamHarmony: 4.0, personalGrowth: 3.8, workLifeBalance: 3.2 } },
  { name: "Perakende",   profile: { overallMood: 3.0, workStress: 3.2, teamHarmony: 3.3, personalGrowth: 2.8, workLifeBalance: 3.0 } },
  { name: "Üretim",      profile: { overallMood: 3.3, workStress: 3.0, teamHarmony: 3.5, personalGrowth: 3.0, workLifeBalance: 3.3 } },
  { name: "Eğitim",      profile: { overallMood: 3.9, workStress: 3.2, teamHarmony: 4.2, personalGrowth: 3.5, workLifeBalance: 3.8 } },
  { name: "Danışmanlık", profile: { overallMood: 3.0, workStress: 1.8, teamHarmony: 3.0, personalGrowth: 3.8, workLifeBalance: 2.2 } },
  { name: "E-ticaret",   profile: { overallMood: 3.5, workStress: 2.5, teamHarmony: 3.5, personalGrowth: 3.8, workLifeBalance: 2.8 } },
  { name: "Kamu",        profile: { overallMood: 3.2, workStress: 3.5, teamHarmony: 3.8, personalGrowth: 2.5, workLifeBalance: 4.0 } },
  { name: "STK",         profile: { overallMood: 4.0, workStress: 3.3, teamHarmony: 4.3, personalGrowth: 3.5, workLifeBalance: 3.8 } },
];

const COMPANY_NAMES = [
  "Arıkovanı Teknoloji", "Nöron Yazılım", "Fırtına Dijital", "Bulut Sistemleri A.Ş.", "Zirve Tech",
  "Güvenli Portföy", "Altın Fintech", "Akıllı Yatırım", "Borsa Analitik", "Para Akışı A.Ş.",
  "Şifa Hastanesi", "Sağlam Klinik", "Ömür Tıp Merkezi", "Hayat Sağlık", "Nefes Wellness",
  "Büyük Market A.Ş.", "Kentsel Mağazacılık", "Alışveriş Dünyası", "Hızlı Ticaret", "Şehir Satış",
  "Demir Endüstri", "Güçlü Makine", "Endüstri Plus", "Üretim Merkezi A.Ş.", "İş Gücü Fabrika",
  "Bilgi Akademisi", "Geleceğin Okulu", "Öğrenim Merkezi", "Bilim Yuvası", "Zeka Kampüsü",
  "Strateji Ortakları", "Kurumsal Çözüm", "Elite Danışmanlık", "Pro Consulting", "Vizyon Advisory",
  "Hızlı Kargo A.Ş.", "Online Pazar", "Dijital Ticaret", "Web Satış Platformu", "E-Bazar",
  "Belediye Hizmetleri", "Kamu Bankası", "İl Müdürlüğü", "Sosyal Hizmetler Vakfı", "Kamu Yönetimi",
  "Çevre Derneği", "Yardım Vakfı", "Toplum Gönüllüleri", "Umut Platformu", "Dayanışma Ağı",
];

const DEPARTMENTS = [
  "Mühendislik", "Pazarlama", "Satış", "İnsan Kaynakları",
  "Finans", "Ürün", "Tasarım", "Müşteri Hizmetleri", "Hukuk", "Operasyon",
];

// ─── Seed companies ───────────────────────────────────────────────────────────

async function seedCompanies() {
  console.log(`\n📦 Seeding ${NUM_COMPANIES} companies...`);
  const companies = [];
  const ops = [];
  const perSector = Math.max(1, Math.ceil(NUM_COMPANIES / SECTORS.length));

  for (let i = 0; i < NUM_COMPANIES; i++) {
    const sector = SECTORS[Math.min(SECTORS.length - 1, Math.floor(i / perSector))];
    const companyId = `seed_company_${String(i + 1).padStart(3, "0")}`;

    const companyProfile = {};
    for (const dim of DIMS) companyProfile[dim] = clamp(sector.profile[dim] + randF(-0.5, 0.5), 1, 5);

    companies.push({ companyId, companyProfile, industry: sector.name });

    ops.push({
      ref: db.collection("companies").doc(companyId),
      data: {
        name: COMPANY_NAMES[i % COMPANY_NAMES.length],
        industry: sector.name,             // computeSurveyAggregate groups by `industry`
        plan: i % 10 < 2 ? "enterprise" : "pro",
        employeeCount: USERS_PER_COMPANY,
        isSeedData: true,
        createdAt: ts(daysAgo(rand(180, 365))),
      },
    });
  }

  await commitBatches(ops, "companies");
  return companies;
}

// ─── Seed users (NAMELESS) ─────────────────────────────────────────────────────

async function seedUsers(companies) {
  console.log(`\n👥 Seeding ${companies.length * USERS_PER_COMPANY} users (nameless)...`);
  const users = [];
  const ops = [];
  let n = 0;

  for (let ci = 0; ci < companies.length; ci++) {
    const { companyId, companyProfile, industry } = companies[ci];
    for (let ui = 0; ui < USERS_PER_COMPANY; ui++) {
      const userId = `seed_user_${String(++n).padStart(5, "0")}`;
      const dept = DEPARTMENTS[ui % DEPARTMENTS.length];
      const joinedAt = daysAgo(rand(30, 365));

      users.push({ userId, userIdHash: hashUserId(userId), companyId, dept, industry, companyProfile });

      ops.push({
        ref: db.collection("users").doc(userId),
        data: {
          // Pseudonymous app user: NO displayName / firstName / lastName / avatarUrl / email.
          linkedinHash: `seed_hash_${userId}`,
          userIdHash: hashUserId(userId),
          role: "free",
          isAdmin: false,
          kvkkAccepted: true,
          kvkkVersion: "1.0",
          kvkkAcceptedAt: ts(joinedAt),
          creditBalance: 0,
          companyId,
          department: dept,
          createdAt: ts(joinedAt),
          deleted: false,
          isSeedData: true,
        },
      });
    }
  }

  await commitBatches(ops, "users   ");
  return users;
}

// ─── Seed check-ins (current schema) ───────────────────────────────────────────
// Returns: perUser (userId → [scoresMap…] chronological asc) and lastCheckins.

async function seedCheckins(users) {
  console.log("\n📋 Seeding check-ins (~4-6 per user)...");
  const ops = [];
  const perUser = {};
  const lastCheckins = {};

  for (const { userId, userIdHash, companyId, dept, companyProfile: p } of users) {
    const count = rand(4, 6);
    let daysBack = rand(0, 7);
    const series = [];

    for (let c = 0; c < count; c++) {
      const checkinDate = daysAgo(daysBack);
      const scores = {};
      for (const dim of DIMS) scores[dim] = genScore(p[dim]);
      const checkinTs = ts(checkinDate);
      series.push({ date: checkinDate, scores });

      ops.push({
        ref: db.collection("checkins").doc(`${userId}_${checkinDate.getTime()}`),
        data: {
          userIdHash,                                  // pseudonym only, no raw uid
          scores,                                      // camelCase canonical dims
          companyId,
          department: dept,
          createdAt: checkinTs,
          created_at: checkinTs,                       // computeInsights orders by created_at
          isAnonymized: true,
          isSeedData: true,
        },
      });

      if (c === 0) lastCheckins[userId] = checkinDate;
      daysBack += rand(7, 14);
    }

    // chronological ascending (oldest → newest) for trend
    series.sort((a, b) => a.date - b.date);
    perUser[userId] = series.map((s) => s.scores);
  }

  await commitBatches(ops, "checkins");
  return { perUser, lastCheckins };
}

async function updateLastCheckins(lastCheckins) {
  console.log("\n🔄 Updating lastCheckinAt on users...");
  const ops = Object.entries(lastCheckins).map(([userId, date]) => ({
    ref: db.collection("users").doc(userId),
    data: { lastCheckinAt: ts(date) },
  }));
  // merge to avoid clobbering the user doc
  const SIZE = 450;
  for (let i = 0; i < ops.length; i += SIZE) {
    const chunk = ops.slice(i, i + SIZE);
    const batch = db.batch();
    chunk.forEach(({ ref, data }) => batch.set(ref, data, { merge: true }));
    await batch.commit();
    process.stdout.write(`\r  lastCheckin: ${Math.min(i + SIZE, ops.length)}/${ops.length}   `);
  }
  console.log();
}

// ─── Seed insights (computeInsights doc shape; id = userIdHash) ─────────────────

async function seedInsights(users, perUser) {
  console.log("\n💡 Seeding insights (computeInsights shape)...");
  const ops = [];

  // company averages per dim (over every company check-in)
  const companyVals = {}; // companyId → dim → [vals]
  for (const u of users) {
    companyVals[u.companyId] ??= Object.fromEntries(DIMS.map((d) => [d, []]));
    for (const scores of perUser[u.userId] ?? []) {
      for (const dim of DIMS) companyVals[u.companyId][dim].push(scores[dim]);
    }
  }
  const companyCount = {};
  for (const u of users) companyCount[u.companyId] = (companyCount[u.companyId] || 0) + 1;
  const COMPANY_MIN_N = 15;

  const companyAvg = {};
  for (const [cid, dims] of Object.entries(companyVals)) {
    companyAvg[cid] = Object.fromEntries(DIMS.map((d) => [d, r2(mean(dims[d]))]));
  }

  for (const u of users) {
    const series = perUser[u.userId] ?? [];
    const personalAvg = {};
    for (const dim of DIMS) personalAvg[dim] = r2(mean(series.map((s) => s[dim])));

    const overallSeries = series.map((s) => mean(DIMS.map((d) => s[d])));
    const slope = olsSlope(overallSeries);
    const retentionRisk = r2(clamp(0.5 - slope * 10, 0, 1));

    const companyVisible = companyCount[u.companyId] >= COMPANY_MIN_N;

    ops.push({
      ref: db.collection("insights").doc(u.userIdHash),
      data: {
        userIdHash: u.userIdHash,
        companyId: u.companyId,
        department_name: u.dept,
        personal: {
          avg: personalAvg,
          checkin_count: series.length,
          trend_slope: r2(slope),
          retention_risk: retentionRisk,
        },
        company: companyVisible
          ? { avg: companyAvg[u.companyId], checkin_count: companyCount[u.companyId] }
          : null,
        department_stats: null,
        updated_at: ts(new Date()),
        isSeedData: true,
      },
    });
  }

  await commitBatches(ops, "insights");
}

// ─── Seed benchmarks (benchmarks/{industry} → {scores}) ─────────────────────────

async function seedBenchmarks(users, perUser) {
  console.log("\n📊 Seeding industry benchmarks...");
  const byIndustry = {}; // industry → dim → [vals]
  for (const u of users) {
    byIndustry[u.industry] ??= Object.fromEntries(DIMS.map((d) => [d, []]));
    for (const scores of perUser[u.userId] ?? []) {
      for (const dim of DIMS) byIndustry[u.industry][dim].push(scores[dim]);
    }
  }

  const ops = [];
  for (const [industry, dims] of Object.entries(byIndustry)) {
    const scores = Object.fromEntries(DIMS.map((d) => [d, r2(mean(dims[d]))]));
    const n = dims[DIMS[0]].length;
    ops.push({
      ref: db.collection("benchmarks").doc(industry),
      data: { scores, n, updated_at: ts(new Date()), isSeedData: true },
    });
  }
  await commitBatches(ops, "benchmarks");
}

// ─── Clear seed data ───────────────────────────────────────────────────────────

async function clearSeedData() {
  console.log("\n🗑  Clearing existing seed data...");
  const collections = ["companies", "users", "checkins", "insights", "benchmarks"];
  for (const col of collections) {
    const snap = await db.collection(col).where("isSeedData", "==", true).get();
    if (snap.empty) { console.log(`  ${col}: nothing to delete`); continue; }
    const SIZE = 450;
    for (let i = 0; i < snap.docs.length; i += SIZE) {
      const batch = db.batch();
      snap.docs.slice(i, i + SIZE).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
    console.log(`  ${col}: deleted ${snap.docs.length} docs`);
  }
}

// ─── Main ───────────────────────────────────────────────────────────────────────

async function main() {
  console.log("🌱 PoM Test Data Seeder (current schema, nameless)");
  console.log("═══════════════════════════════════════");

  if (CLEAR) await clearSeedData();

  const companies = await seedCompanies();
  const users = await seedUsers(companies);
  const { perUser, lastCheckins } = await seedCheckins(users);
  await updateLastCheckins(lastCheckins);
  await seedInsights(users, perUser);
  await seedBenchmarks(users, perUser);

  console.log("\n✅ Done!");
  console.log(`   Companies  : ${companies.length}`);
  console.log(`   Users      : ${users.length}  (nameless, pseudonymous)`);
  console.log(`   Check-ins  : ~${users.length * 5}`);
  console.log(`   Insights   : ${users.length}`);
  console.log("\n   For survey aggregates, next run:");
  console.log("     node scripts/seed_surveys.js");
  console.log("     node scripts/seed_gate_aggregate_data.js --apply");
  console.log("     node scripts/seed_gate_aggregate_data.js --write-aggregates");
  process.exit(0);
}

main().catch((err) => {
  console.error("\n❌ Seed failed:", err);
  process.exit(1);
});
