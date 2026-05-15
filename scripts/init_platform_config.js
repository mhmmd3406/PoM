#!/usr/bin/env node
/**
 * PoM — Seed platform_config documents in Firestore.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json node scripts/init_platform_config.js
 *
 * Or set FIREBASE_PROJECT_ID when using Application Default Credentials:
 *   node scripts/init_platform_config.js
 */

"use strict";

const admin = require("firebase-admin");

// ---------------------------------------------------------------------------
// Initialise Firebase Admin SDK
// ---------------------------------------------------------------------------

if (!admin.apps.length) {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (credPath) {
    const serviceAccount = require(require("path").resolve(credPath));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log(`Initialised with service account: ${credPath}`);
  } else {
    // Fall back to Application Default Credentials
    admin.initializeApp();
    console.log("Initialised with Application Default Credentials");
  }
}

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Seed data
// ---------------------------------------------------------------------------

const thresholds = {
  company_min_n: 15,
  department_min_n: 10,
  company_filter_size: 200,
  checkin_cooldown_days: 7,
  kvkk_version: "1.0",
  safety_floor_company: 7,
  safety_floor_department: 5,
};

const stripePlans = {
  pro: {
    price_id: "price_REPLACE_ME",
    amount: 19900,      // 199.00 TRY in smallest unit (kuruş)
    currency: "try",
  },
  enterprise: {
    price_id: "price_REPLACE_ME",
    amount: 99900,      // 999.00 TRY in smallest unit (kuruş)
    currency: "try",
  },
};

// ---------------------------------------------------------------------------
// Write to Firestore
// ---------------------------------------------------------------------------

async function seed() {
  try {
    const batch = db.batch();

    const thresholdsRef = db.collection("platform_config").doc("thresholds");
    batch.set(thresholdsRef, thresholds, { merge: true });

    const plansRef = db.collection("platform_config").doc("stripe_plans");
    batch.set(plansRef, stripePlans, { merge: true });

    await batch.commit();

    console.log("✓ platform_config/thresholds written:");
    console.log(JSON.stringify(thresholds, null, 2));
    console.log("");
    console.log("✓ platform_config/stripe_plans written:");
    console.log(JSON.stringify(stripePlans, null, 2));
    console.log("");
    console.log(
      "Remember to replace 'price_REPLACE_ME' values with real Stripe price IDs before going live."
    );

    process.exit(0);
  } catch (err) {
    console.error("✗ Failed to seed platform_config:", err);
    process.exit(1);
  }
}

seed();
