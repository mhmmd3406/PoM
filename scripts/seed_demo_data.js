#!/usr/bin/env node
/**
 * PoM — Seed demo data: companies, users, subscriptions, checkins, wallets.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json node scripts/seed_demo_data.js
 *
 *   # Or with Application Default Credentials (firebase login --reauth):
 *   FIREBASE_PROJECT_ID=pomapp-c3ccc node scripts/seed_demo_data.js
 *
 * Safe to re-run — uses setMerge so existing docs are not overwritten.
 * Pass --force to overwrite all documents.
 */

"use strict";

const admin = require("firebase-admin");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

// ─── Init ────────────────────────────────────────────────────────────────────

if (!admin.apps.length) {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (credPath) {
    const serviceAccount = require(require("path").resolve(credPath));
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    console.log(`✓ Initialised with service account: ${credPath}`);
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID ?? "pomapp-c3ccc",
    });
    console.log("✓ Initialised with Application Default Credentials");
  }
}

const db = getFirestore();
const FORCE = process.argv.includes("--force");
const writeOpts = FORCE ? undefined : { merge: true };

// ─── Helpers ─────────────────────────────────────────────────────────────────

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return Timestamp.fromDate(d);
}

function daysFromNow(n) {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return Timestamp.fromDate(d);
}

function rand(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function fakeStripeCustomerId(idx) {
  return `cus_PmDemo${String(idx).padStart(8, "0")}`;
}

function fakeStripeSubId(idx) {
  return `sub_PmDemo${String(idx).padStart(8, "0")}`;
}

// ─── Static fixtures ─────────────────────────────────────────────────────────

const COMPANIES = [
  {
    id: "comp_teknoloji",
    name: "Teknoloji A.Ş.",
    plan: "enterprise",
    industry: "Teknoloji",
    employee_count: 320,
    contact_email: "it@teknoloji.com.tr",
    active: true,
  },
  {
    id: "comp_finans",
    name: "Finans Grubu",
    plan: "pro",
    industry: "Finans",
    employee_count: 180,
    contact_email: "info@finansgrubu.com.tr",
    active: true,
  },
  {
    id: "comp_saglik",
    name: "Sağlık Merkezi Ltd.",
    plan: "pro",
    industry: "Sağlık",
    employee_count: 95,
    contact_email: "admin@saglikmerkezi.com.tr",
    active: true,
  },
  {
    id: "comp_perakende",
    name: "Perakende Co.",
    plan: "free",
    industry: "Perakende",
    employee_count: 55,
    contact_email: "info@perakendeco.com.tr",
    active: true,
  },
  {
    id: "comp_danismanlik",
    name: "Danışmanlık Group",
    plan: "daas",
    industry: "Danışmanlık",
    employee_count: 42,
    contact_email: "contact@danismanlikgroup.com.tr",
    active: true,
  },
];

// Plan → default role for users of that company
const COMPANY_PLAN = Object.fromEntries(COMPANIES.map((c) => [c.id, c.plan]));

const DEPARTMENTS_BY_INDUSTRY = {
  Teknoloji: ["Mühendislik", "Ürün", "Tasarım", "Veri", "Altyapı", "İK"],
  Finans: ["Risk", "Muhasebe", "Operasyon", "Yatırım", "Uyum", "İK"],
  Sağlık: ["Klinik", "İdari", "Araştırma", "İK"],
  Perakende: ["Satış", "Lojistik", "Müşteri Hizmetleri", "İK"],
  Danışmanlık: ["Strateji", "Teknoloji", "Operasyon", "İK"],
};

const NAMES = [
  ["Ahmet", "Yılmaz"], ["Fatma", "Kaya"], ["Mehmet", "Demir"], ["Ayşe", "Çelik"],
  ["Mustafa", "Şahin"], ["Zeynep", "Yıldız"], ["Ali", "Öztürk"], ["Elif", "Arslan"],
  ["Hüseyin", "Doğan"], ["Büşra", "Kılıç"], ["İbrahim", "Aslan"], ["Selin", "Çetin"],
  ["Emre", "Koç"], ["Merve", "Aydın"], ["Oğuz", "Erdoğan"], ["Ceren", "Kurt"],
  ["Kemal", "Özdemir"], ["Derya", "Şimşek"], ["Serkan", "Bulut"], ["Gül", "Polat"],
  ["Tarık", "Güneş"], ["Pınar", "Avcı"], ["Volkan", "Tekin"], ["Işık", "Yalçın"],
  ["Deniz", "Çakır"], ["Emine", "Tunç"], ["Burak", "Duman"], ["Lale", "Karaca"],
  ["Alper", "Güler"], ["Hande", "Özcan"],
];

// ─── Users ───────────────────────────────────────────────────────────────────

/**
 * 30 realistic users spread across 5 companies.
 * Roles mostly match company plan; a few upgrades/downgrades for realism.
 */
function buildUsers() {
  const users = [];
  let nameIdx = 0;

  const distribution = [
    { companyId: "comp_teknoloji", count: 9 },
    { companyId: "comp_finans", count: 7 },
    { companyId: "comp_saglik", count: 5 },
    { companyId: "comp_perakende", count: 5 },
    { companyId: "comp_danismanlik", count: 4 },
  ];

  let userIdx = 0;
  for (const { companyId, count } of distribution) {
    const company = COMPANIES.find((c) => c.id === companyId);
    const departments = DEPARTMENTS_BY_INDUSTRY[company.industry];
    const basePlan = COMPANY_PLAN[companyId];

    // Possible roles: mostly base, few variants
    const roles = [
      basePlan, basePlan, basePlan, basePlan, // 4× base
      "free", "pro", // 1 free / 1 pro regardless
    ];

    for (let i = 0; i < count; i++) {
      const [firstName, lastName] = NAMES[nameIdx % NAMES.length];
      nameIdx++;
      const uid = `demo_user_${String(userIdx + 1).padStart(3, "0")}`;
      const role = roles[i % roles.length];

      users.push({
        id: uid,
        uid,
        displayName: `${firstName} ${lastName}`,
        email: `${firstName.toLowerCase()}.${lastName.toLowerCase()}@${companyId.replace("comp_", "")}.demo`,
        role,
        companyId,
        department: departments[i % departments.length],
        created_at: daysAgo(rand(30, 180)),
        updated_at: daysAgo(rand(0, 30)),
        deleted: false,
        kvkk_accepted: true,
        credits: rand(5, 80),
      });
      userIdx++;
    }
  }

  return users;
}

// ─── Subscriptions ────────────────────────────────────────────────────────────

function buildSubscriptions(users) {
  return users.map((u, idx) => {
    const isPaid = u.role !== "free";
    const status = isPaid
      ? pick(["active", "active", "active", "trialing", "past_due"])
      : pick(["inactive", "inactive", "active"]);

    const sub = {
      id: `sub_demo_${String(idx + 1).padStart(3, "0")}`,
      userId: u.id,
      plan: u.role,
      status,
      created_at: u.created_at,
      updated_at: u.updated_at,
    };

    if (isPaid && status !== "inactive") {
      sub.stripe_customer_id = fakeStripeCustomerId(idx + 1);
      sub.stripe_subscription_id = fakeStripeSubId(idx + 1);
      sub.current_period_end = daysFromNow(rand(1, 30));
    }

    return sub;
  });
}

// ─── Wallets ─────────────────────────────────────────────────────────────────

function buildWallets(users) {
  return users.map((u) => ({
    id: u.id,
    userId: u.id,
    balance: u.credits,
    updated_at: u.updated_at,
  }));
}

// ─── Wallet Transactions ──────────────────────────────────────────────────────

function buildWalletTransactions(users) {
  const txns = [];
  for (const u of users) {
    // 2–4 transactions per user
    const count = rand(2, 4);
    for (let i = 0; i < count; i++) {
      const isCredit = i === 0; // first txn is always a purchase
      txns.push({
        id: `wtx_${u.id}_${i}`,
        userId: u.id,
        type: isCredit ? "purchase" : "usage",
        amount: isCredit ? pick([10, 50, 100]) : -rand(3, 8),
        description: isCredit
          ? `Kredi paketi · ${pick([10, 50, 100])} Kredi`
          : `Anket oluşturma · ${pick(["Refah Anketi", "Q2 Analizi", "Hibrit Çalışma", "Departman Raporu"])}`,
        created_at: daysAgo(rand(1, 60)),
      });
    }
  }
  return txns;
}

// ─── Check-ins ────────────────────────────────────────────────────────────────

const SCORE_PROFILES = {
  // [overallMood, workStress, teamHarmony, personalGrowth, workLifeBalance]
  happy:    [5, 4, 5, 4, 4],
  stressed: [3, 2, 3, 3, 2],
  neutral:  [3, 3, 3, 3, 3],
  growing:  [4, 3, 4, 5, 3],
  burned:   [2, 1, 2, 2, 2],
};

function jitter(base, spread = 1) {
  return Math.min(5, Math.max(1, base + rand(-spread, spread)));
}

function buildCheckins(users) {
  const checkins = [];
  const profiles = Object.values(SCORE_PROFILES);
  let cidx = 0;

  for (const u of users) {
    const profile = profiles[cidx % profiles.length];
    cidx++;

    // 8–16 weekly check-ins over last ~16 weeks
    const count = rand(8, 16);
    for (let w = 0; w < count; w++) {
      const overallMood     = jitter(profile[0]);
      const workStress      = jitter(profile[1]);
      const teamHarmony     = jitter(profile[2]);
      const personalGrowth  = jitter(profile[3]);
      const workLifeBalance = jitter(profile[4]);
      const ts = daysAgo(w * 7 + rand(0, 3));

      checkins.push({
        id: `chk_${u.id}_w${String(w).padStart(2, "0")}`,
        uid: u.id,
        userId: u.id,
        companyId: u.companyId,
        department: u.department,
        isAnonymized: true,
        overallMood,
        workStress,
        teamHarmony,
        personalGrowth,
        workLifeBalance,
        scores: {
          "Genel Ruh Hali":    overallMood,
          "İş Stresi":         workStress,
          "Takım Uyumu":       teamHarmony,
          "Kişisel Gelişim":   personalGrowth,
          "İş-Yaşam Dengesi":  workLifeBalance,
        },
        createdAt: ts,
        created_at: ts,
      });
    }
  }
  return checkins;
}

// ─── Write helpers ────────────────────────────────────────────────────────────

async function writeBatch(collectionName, docs, idField = "id") {
  const BATCH_SIZE = 490;
  let written = 0;
  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const chunk = docs.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const doc of chunk) {
      const ref = db.collection(collectionName).doc(doc[idField]);
      const { [idField]: _id, ...data } = doc;
      FORCE ? batch.set(ref, data) : batch.set(ref, data, { merge: true });
    }
    await batch.commit();
    written += chunk.length;
    process.stdout.write(`\r  ${collectionName}: ${written}/${docs.length}`);
  }
  console.log(`\r  ✓ ${collectionName}: ${docs.length} docs written`);
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log("\n🌱  PoM Demo Seed\n");
  if (FORCE) console.log("⚡  --force: documents will be overwritten\n");

  const users = buildUsers();
  const subscriptions = buildSubscriptions(users);
  const wallets = buildWallets(users);
  const walletTxns = buildWalletTransactions(users);
  const checkins = buildCheckins(users);

  console.log(`  Companies:   ${COMPANIES.length}`);
  console.log(`  Users:       ${users.length}`);
  console.log(`  Subscriptions: ${subscriptions.length}`);
  console.log(`  Wallets:     ${wallets.length}`);
  console.log(`  Wallet Txns: ${walletTxns.length}`);
  console.log(`  Check-ins:   ${checkins.length}\n`);

  await writeBatch("companies", COMPANIES);
  await writeBatch("users", users);
  await writeBatch("subscriptions", subscriptions);
  await writeBatch("wallets", wallets);
  await writeBatch("wallet_transactions", walletTxns);
  await writeBatch("checkins", checkins);

  console.log("\n✅  Seed complete!\n");
  process.exit(0);
}

main().catch((err) => {
  console.error("\n❌ Error:", err.message);
  process.exit(1);
});
