#!/usr/bin/env node
/**
 * PoM — Set is_admin custom claim on a Firebase Auth user.
 *
 * Usage:
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

  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { is_admin: true });
  console.log(`✅  is_admin=true set for ${email} (uid: ${user.uid})`);
  console.log("    Tarayıcıda çıkış yapıp tekrar giriş yapın.");
  process.exit(0);
}

main().catch((err) => {
  console.error("❌ Error:", err.message);
  process.exit(1);
});
