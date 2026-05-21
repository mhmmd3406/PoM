#!/usr/bin/env node
/**
 * PoM — Seed 50 companies × 50 users = 2500 users + check-in history.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json node scripts/seed_test_data.js
 *
 * Pass --clear to delete existing seed data first:
 *   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json node scripts/seed_test_data.js --clear
 */

"use strict";

const admin = require("firebase-admin");
const path  = require("path");

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

const db   = admin.firestore();
const CLEAR = process.argv.includes("--clear");

// ─── Helpers ──────────────────────────────────────────────────────────────────

const rand    = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const clamp   = (v, mn, mx) => Math.min(Math.max(Math.round(v), mn), mx);
const randF   = (min, max) => Math.random() * (max - min) + min;
const ts      = (date) => admin.firestore.Timestamp.fromDate(date);
const daysAgo = (n) => { const d = new Date(); d.setDate(d.getDate() - n); return d; };

// Commit ops in chunks of 499 (Firestore batch limit)
async function commitBatches(ops, label) {
  const SIZE = 499;
  const total = ops.length;
  for (let i = 0; i < total; i += SIZE) {
    const chunk = ops.slice(i, i + SIZE);
    const batch = db.batch();
    chunk.forEach(({ ref, data, merge }) =>
      merge ? batch.set(ref, data, { merge: true }) : batch.set(ref, data)
    );
    await batch.commit();
    process.stdout.write(`\r  ${label}: ${Math.min(i + SIZE, total)}/${total}   `);
  }
  console.log();
}

// Gaussian-ish score: base ± variance, clamped to [1,5]
function genScore(base, variance = 0.8) {
  const noise = (Math.random() + Math.random() - 1) * variance * 2;
  return clamp(base + noise, 1, 5);
}

// ─── Data definitions ─────────────────────────────────────────────────────────

const SECTORS = [
  { name: "Teknoloji",    profile: { mood: 3.8, stress: 2.5, harmony: 3.5, growth: 4.2, balance: 3.0 } },
  { name: "Finans",       profile: { mood: 3.2, stress: 2.0, harmony: 3.2, growth: 3.5, balance: 2.5 } },
  { name: "Sağlık",       profile: { mood: 3.6, stress: 2.8, harmony: 4.0, growth: 3.8, balance: 3.2 } },
  { name: "Perakende",    profile: { mood: 3.0, stress: 3.2, harmony: 3.3, growth: 2.8, balance: 3.0 } },
  { name: "Üretim",       profile: { mood: 3.3, stress: 3.0, harmony: 3.5, growth: 3.0, balance: 3.3 } },
  { name: "Eğitim",       profile: { mood: 3.9, stress: 3.2, harmony: 4.2, growth: 3.5, balance: 3.8 } },
  { name: "Danışmanlık",  profile: { mood: 3.0, stress: 1.8, harmony: 3.0, growth: 3.8, balance: 2.2 } },
  { name: "E-ticaret",    profile: { mood: 3.5, stress: 2.5, harmony: 3.5, growth: 3.8, balance: 2.8 } },
  { name: "Kamu",         profile: { mood: 3.2, stress: 3.5, harmony: 3.8, growth: 2.5, balance: 4.0 } },
  { name: "STK",          profile: { mood: 4.0, stress: 3.3, harmony: 4.3, growth: 3.5, balance: 3.8 } },
];

// 5 companies per sector = 50 total
const COMPANY_NAMES = [
  // Teknoloji
  "Arıkovanı Teknoloji", "Nöron Yazılım", "Fırtına Dijital", "Bulut Sistemleri A.Ş.", "Zirve Tech",
  // Finans
  "Güvenli Portföy", "Altın Fintech", "Akıllı Yatırım", "Borsa Analitik", "Para Akışı A.Ş.",
  // Sağlık
  "Şifa Hastanesi", "Sağlam Klinik", "Ömür Tıp Merkezi", "Hayat Sağlık", "Nefes Wellness",
  // Perakende
  "Büyük Market A.Ş.", "Kentsel Mağazacılık", "Alışveriş Dünyası", "Hızlı Ticaret", "Şehir Satış",
  // Üretim
  "Demir Endüstri", "Güçlü Makine", "Endüstri Plus", "Üretim Merkezi A.Ş.", "İş Gücü Fabrika",
  // Eğitim
  "Bilgi Akademisi", "Geleceğin Okulu", "Öğrenim Merkezi", "Bilim Yuvası", "Zeka Kampüsü",
  // Danışmanlık
  "Strateji Ortakları", "Kurumsal Çözüm", "Elite Danışmanlık", "Pro Consulting", "Vizyon Advisory",
  // E-ticaret
  "Hızlı Kargo A.Ş.", "Online Pazar", "Dijital Ticaret", "Web Satış Platformu", "E-Bazar",
  // Kamu
  "Belediye Hizmetleri", "Kamu Bankası", "İl Müdürlüğü", "Sosyal Hizmetler Vakfı", "Kamu Yönetimi",
  // STK
  "Çevre Derneği", "Yardım Vakfı", "Toplum Gönüllüleri", "Umut Platformu", "Dayanışma Ağı",
];

const DEPARTMENTS = [
  "Mühendislik", "Pazarlama", "Satış", "İnsan Kaynakları",
  "Finans", "Ürün", "Tasarım", "Müşteri Hizmetleri", "Hukuk", "Operasyon",
];

const FIRST_NAMES = [
  "Ahmet", "Mehmet", "Mustafa", "Ali", "Hüseyin", "Hasan", "İbrahim", "İsmail",
  "Ömer", "Yusuf", "Ayşe", "Fatma", "Emine", "Hatice", "Zeynep", "Elif",
  "Meryem", "Şule", "Selin", "Ceren", "Can", "Burak", "Emre", "Serkan",
  "Tolga", "Deniz", "Ege", "Berk", "Kaan", "Mert",
];

const LAST_NAMES = [
  "Yılmaz", "Kaya", "Demir", "Çelik", "Şahin", "Doğan", "Arslan", "Aydın",
  "Öztürk", "Kılıç", "Koç", "Aslan", "Çetin", "Duman", "Polat", "Keskin",
  "Yıldız", "Güneş", "Akar", "Erdoğan", "Bakır", "Şimşek", "Yıldırım", "Bulut",
];

// ─── Seed companies ───────────────────────────────────────────────────────────

async function seedCompanies() {
  console.log("\n📦 Seeding companies...");
  const companies = [];
  const ops = [];

  for (let i = 0; i < 50; i++) {
    const sector = SECTORS[Math.floor(i / 5)];
    const companyId = `seed_company_${String(i + 1).padStart(3, "0")}`;

    // Give each company a slight deviation from sector profile
    const companyProfile = {
      mood:    clamp(sector.profile.mood    + randF(-0.5, 0.5), 1, 5),
      stress:  clamp(sector.profile.stress  + randF(-0.5, 0.5), 1, 5),
      harmony: clamp(sector.profile.harmony + randF(-0.5, 0.5), 1, 5),
      growth:  clamp(sector.profile.growth  + randF(-0.5, 0.5), 1, 5),
      balance: clamp(sector.profile.balance + randF(-0.5, 0.5), 1, 5),
    };

    companies.push({ companyId, companyProfile, sector: sector.name });

    ops.push({
      ref: db.collection("companies").doc(companyId),
      data: {
        name:          COMPANY_NAMES[i],
        sector:        sector.name,
        plan:          i % 10 < 2 ? "enterprise" : "pro",
        employeeCount: rand(50, 5000),
        isSeedData:    true,
        createdAt:     ts(daysAgo(rand(180, 365))),
        // Store profile for reference (not used by app, just for debugging)
        _seedProfile:  companyProfile,
      },
    });
  }

  await commitBatches(ops, "companies");
  return companies;
}

// ─── Seed users ───────────────────────────────────────────────────────────────

async function seedUsers(companies) {
  console.log("\n👥 Seeding 2500 users...");
  const users = [];
  const ops   = [];

  for (let ci = 0; ci < companies.length; ci++) {
    const { companyId } = companies[ci];

    for (let ui = 0; ui < 50; ui++) {
      const userId   = `seed_user_${String(ci * 50 + ui + 1).padStart(5, "0")}`;
      const fname    = FIRST_NAMES[rand(0, FIRST_NAMES.length - 1)];
      const lname    = LAST_NAMES[rand(0, LAST_NAMES.length - 1)];
      const dept     = DEPARTMENTS[ui % DEPARTMENTS.length];
      const joinedAt = daysAgo(rand(30, 365));

      users.push({ userId, companyId, dept, companyProfile: companies[ci].companyProfile });

      ops.push({
        ref: db.collection("users").doc(userId),
        data: {
          linkedinHash:  `seed_hash_${userId}`,
          displayName:   `${fname} ${lname}`,
          email:         `${fname.toLowerCase()}.${lname.toLowerCase()}@${companyId}.test`,
          role:          "free",
          isAdmin:       false,
          kvkkAccepted:  true,
          kvkkVersion:   "1.0",
          kvkkAcceptedAt: ts(joinedAt),
          creditBalance: 0,
          companyId,
          department:    dept,
          createdAt:     ts(joinedAt),
          isSeedData:    true,
        },
      });
    }
  }

  await commitBatches(ops, "users   ");
  return users;
}

// ─── Seed check-ins ───────────────────────────────────────────────────────────

async function seedCheckins(users) {
  console.log("\n📋 Seeding check-ins (~4-6 per user)...");
  const ops          = [];
  const lastCheckins = {}; // userId → Date of most recent checkin

  for (const { userId, companyId, dept, companyProfile: p } of users) {
    const checkinCount = rand(4, 6);
    // Spread check-ins over past 8 weeks (one per ~10-14 days)
    let daysBack = rand(0, 7); // most recent

    for (let c = 0; c < checkinCount; c++) {
      const checkinDate = daysAgo(daysBack);
      const docId       = `${userId}_${checkinDate.getTime()}`;

      const mood    = genScore(p.mood);
      const stress  = genScore(p.stress);
      const harmony = genScore(p.harmony);
      const growth  = genScore(p.growth);
      const balance = genScore(p.balance);
      const checkinTs = ts(checkinDate);

      ops.push({
        ref: db.collection("checkins").doc(docId),
        data: {
          uid:            userId,
          userId,
          companyId,
          department:     dept,
          overallMood:    mood,
          workStress:     stress,
          teamHarmony:    harmony,
          personalGrowth: growth,
          workLifeBalance: balance,
          scores: {
            "Genel Ruh Hali":   mood,
            "İş Stresi":        stress,
            "Takım Uyumu":      harmony,
            "Kişisel Gelişim":  growth,
            "İş-Yaşam Dengesi": balance,
          },
          createdAt:   checkinTs,
          created_at:  checkinTs,
          isAnonymized: true,
          isSeedData:   true,
        },
      });

      if (c === 0) lastCheckins[userId] = checkinDate;
      daysBack += rand(7, 14);
    }
  }

  await commitBatches(ops, "checkins");
  return lastCheckins;
}

// ─── Update lastCheckinAt on users ───────────────────────────────────────────

async function updateLastCheckins(lastCheckins) {
  console.log("\n🔄 Updating lastCheckinAt on users...");
  const ops = Object.entries(lastCheckins).map(([userId, date]) => ({
    ref:   db.collection("users").doc(userId),
    data:  { lastCheckinAt: ts(date) },
    merge: true,
  }));
  await commitBatches(ops, "lastCheckin");
}

// ─── Seed insights ────────────────────────────────────────────────────────────

async function seedInsights(users) {
  console.log("\n💡 Seeding insights...");
  const ops = [];

  // Precompute company averages
  const companyTotals = {};
  for (const { companyId, companyProfile: p } of users) {
    if (!companyTotals[companyId]) {
      companyTotals[companyId] = { mood: 0, stress: 0, harmony: 0, growth: 0, balance: 0, n: 0 };
    }
    companyTotals[companyId].mood    += p.mood;
    companyTotals[companyId].stress  += p.stress;
    companyTotals[companyId].harmony += p.harmony;
    companyTotals[companyId].growth  += p.growth;
    companyTotals[companyId].balance += p.balance;
    companyTotals[companyId].n++;
  }

  const companyAvgs = {};
  for (const [cid, t] of Object.entries(companyTotals)) {
    companyAvgs[cid] = {
      overallMood:     parseFloat((t.mood    / t.n).toFixed(2)),
      workStress:      parseFloat((t.stress  / t.n).toFixed(2)),
      teamHarmony:     parseFloat((t.harmony / t.n).toFixed(2)),
      personalGrowth:  parseFloat((t.growth  / t.n).toFixed(2)),
      workLifeBalance: parseFloat((t.balance / t.n).toFixed(2)),
    };
  }

  // Overall benchmark (average across all companies)
  const allMoods = users.map(u => u.companyProfile.mood);
  const benchmark = {
    overallMood:     parseFloat((allMoods.reduce((a,b)=>a+b,0)/allMoods.length).toFixed(2)),
    workStress:      parseFloat((users.reduce((a,u)=>a+u.companyProfile.stress,0)/users.length).toFixed(2)),
    teamHarmony:     parseFloat((users.reduce((a,u)=>a+u.companyProfile.harmony,0)/users.length).toFixed(2)),
    personalGrowth:  parseFloat((users.reduce((a,u)=>a+u.companyProfile.growth,0)/users.length).toFixed(2)),
    workLifeBalance: parseFloat((users.reduce((a,u)=>a+u.companyProfile.balance,0)/users.length).toFixed(2)),
  };

  for (const { userId, companyId, companyProfile: p } of users) {
    const personal = {
      overallMood:     parseFloat(genScore(p.mood,    0.5).toFixed(2)),
      workStress:      parseFloat(genScore(p.stress,  0.5).toFixed(2)),
      teamHarmony:     parseFloat(genScore(p.harmony, 0.5).toFixed(2)),
      personalGrowth:  parseFloat(genScore(p.growth,  0.5).toFixed(2)),
      workLifeBalance: parseFloat(genScore(p.balance, 0.5).toFixed(2)),
    };

    const personalAvg = Object.values(personal).reduce((a,b)=>a+b,0) / 5;
    const companyAvg  = Object.values(companyAvgs[companyId]).reduce((a,b)=>a+b,0) / 5;
    const trend       = personalAvg > companyAvg + 0.3 ? 1 : personalAvg < companyAvg - 0.3 ? -1 : 0;

    ops.push({
      ref: db.collection("insights").doc(userId),
      data: {
        uid:             userId,
        companyId,
        personalScores:  personal,
        companyScores:   companyAvgs[companyId],
        benchmarkScores: benchmark,
        totalCheckins:   rand(4, 6),
        trend,
        updatedAt:       ts(new Date()),
        isSeedData:      true,
      },
    });
  }

  await commitBatches(ops, "insights");
}

// ─── Clear seed data ─────────────────────────────────────────────────────────

async function clearSeedData() {
  console.log("\n🗑  Clearing existing seed data...");
  const collections = ["companies", "users", "checkins", "insights"];
  for (const col of collections) {
    const snap = await db.collection(col).where("isSeedData", "==", true).get();
    if (snap.empty) { console.log(`  ${col}: nothing to delete`); continue; }
    const ops = snap.docs.map(d => ({ ref: d.ref, data: {}, _delete: true }));
    // Delete in batches
    const SIZE = 499;
    for (let i = 0; i < ops.length; i += SIZE) {
      const batch = db.batch();
      ops.slice(i, i + SIZE).forEach(({ ref }) => batch.delete(ref));
      await batch.commit();
    }
    console.log(`  ${col}: deleted ${snap.docs.length} docs`);
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log("🌱 PoM Test Data Seeder");
  console.log("═══════════════════════════════════════");

  if (CLEAR) await clearSeedData();

  const companies   = await seedCompanies();
  const users       = await seedUsers(companies);
  const lastCheckins = await seedCheckins(users);
  await updateLastCheckins(lastCheckins);
  await seedInsights(users);

  console.log("\n✅ Done!");
  console.log(`   Companies : 50`);
  console.log(`   Users     : 2500`);
  console.log(`   Check-ins : ~${2500 * 5} (avg 5 per user)`);
  console.log(`   Insights  : 2500`);
  process.exit(0);
}

main().catch(err => {
  console.error("\n❌ Seed failed:", err);
  process.exit(1);
});
