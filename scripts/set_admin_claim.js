#!/usr/bin/env node
/**
 * PoM — Grant admin access via Firestore admins collection.
 *
 * Usage (PowerShell):
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "serviceAccountKey.json"
 *   node scripts/set_admin_claim.js ozkanmuhammed2@gmail.com
 */

"use strict";

const admin = require("firebase-admin");

if (!admin.apps.length) {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (credPath) {
    const serviceAccount = require(require("path").resolve(credPath));
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID ?? "pomapp-c3ccc",
    });
  }
}

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error("Usage: node set_admin_claim.js <email>");
    process.exit(1);
  }

  const db = admin.firestore();

  // Look up the UID by email
  const user = await admin.auth().getUserByEmail(email);
  const uid = user.uid;

  // Write to admins/{uid} — Firestore rules check existence of this doc
  await db.collection("admins").doc(uid).set({
    email,
    granted_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Also set custom claim for future-proofing
  await admin.auth().setCustomUserClaims(uid, { is_admin: true });

  console.log(`\n✅  Admin erişimi verildi:`);
  console.log(`   email : ${email}`);
  console.log(`   uid   : ${uid}`);
  console.log(`\n→ Tarayıcıda çıkış yapıp tekrar giriş yapın.\n`);
  process.exit(0);
}

main().catch((err) => {
  console.error("\n❌ Hata:", err.message);
  process.exit(1);
});
