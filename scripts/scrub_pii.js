#!/usr/bin/env node
'use strict';

/**
 * scrub_pii.js — Tek seferlik KVKK veri-minimizasyonu temizliği
 * =============================================================================
 * Uygulama (mobil / LinkedIn) kullanıcılarının ARTIK toplanmayan kişisel
 * alanlarını mevcut kayıtlardan siler:
 *
 *     displayName, firstName, lastName, avatarUrl   (Firestore users/{uid})
 *     displayName, photoURL                          (Firebase Auth kaydı)
 *
 * Admin / kurumsal portal hesapları HARİÇ tutulur (adları korunur):
 *   • admins/{uid} dokümanı olanlar, VEYA
 *   • Auth custom claim'i is_admin==true / company_admin==true olanlar, VEYA
 *   • Auth'ta e-posta/PAROLA provider'ı olanlar. (Uygulama kullanıcıları custom
 *     token (LinkedIn) ile girer, parola provider'ı YOKTUR; portal/kurumsal
 *     hesaplar e-posta/parola ile girer. Böylece henüz claim atanmamış bir
 *     kurumsal hesap dahi korunur — claim zamanlamasından bağımsız.)
 *
 * Bu, "feat(privacy): uygulama kullanıcısı için ad-soyad ve profil fotoğrafı
 * toplamayı durdur" (PR-1) ile eşleşir: PR-1 yeni toplamayı durdurur, bu script
 * eski veriyi temizler. ÖNCE PR-1 canlıya alınmalı, SONRA bu çalıştırılmalı.
 *
 * Güvenli: varsayılan KURU ÇALIŞMA (yalnız rapor). Yazmak için --apply gerekir.
 * İdempotent: tekrar çalıştırınca temizlenecek alan kalmadığını görür.
 *
 * Auth: firebase-admin (service account).
 * Kullanım:
 *   GOOGLE_APPLICATION_CREDENTIALS=./sa_key.json node scripts/scrub_pii.js
 *   GOOGLE_APPLICATION_CREDENTIALS=./sa_key.json node scripts/scrub_pii.js --apply
 * =============================================================================
 */

const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS first.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.applicationDefault() });

const auth = admin.auth();
const db = admin.firestore();

const APPLY = process.argv.includes('--apply');
const PII_FIELDS = ['displayName', 'firstName', 'lastName', 'avatarUrl'];

// ─── Build the exclude set: admins + company-admins keep their names ──────────

async function buildExcludeSet() {
  const exclude = new Set();

  // 1) admins/{uid} collection
  const adminsSnap = await db.collection('admins').get();
  adminsSnap.forEach((d) => exclude.add(d.id));

  // 2) Auth: is_admin / company_admin claim OR an email/password provider.
  //    App users sign in with a custom token (LinkedIn) and have no password
  //    provider; portal/corporate accounts use email/password — so this protects
  //    them even before their company_admin claim is assigned.
  let pageToken;
  do {
    const res = await auth.listUsers(1000, pageToken);
    for (const u of res.users) {
      const c = u.customClaims || {};
      const hasPasswordProvider = (u.providerData || []).some(
        (p) => p.providerId === 'password',
      );
      if (c.is_admin === true || c.company_admin === true || hasPasswordProvider) {
        exclude.add(u.uid);
      }
    }
    pageToken = res.pageToken;
  } while (pageToken);

  return exclude;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🧹 PoM PII Scrub');
  console.log('═══════════════════════════════════════');
  console.log(APPLY ? 'MODE: --apply (writes)' : 'MODE: dry-run (no writes; pass --apply to execute)');

  const exclude = await buildExcludeSet();
  console.log(`Excluded admin / company-admin / password accounts: ${exclude.size}`);

  const usersSnap = await db.collection('users').get();
  console.log(`Total user docs: ${usersSnap.size}`);

  // Collect docs that still carry any PII field and are not excluded.
  const targets = [];
  for (const doc of usersSnap.docs) {
    if (exclude.has(doc.id)) continue;
    const data = doc.data();
    const present = PII_FIELDS.filter((f) => data[f] !== undefined && data[f] !== null);
    if (present.length > 0) targets.push({ ref: doc.ref, id: doc.id, fields: present });
  }

  console.log(`User docs with PII to scrub: ${targets.length}`);
  if (targets.length > 0) {
    const sample = targets.slice(0, 5).map((t) => `${t.id} [${t.fields.join(', ')}]`);
    console.log('  e.g. ' + sample.join('  |  '));
  }

  if (!APPLY) {
    console.log('\n(Dry-run — nothing written. Re-run with --apply to scrub.)');
    process.exit(0);
  }

  // 1) Firestore: delete the PII fields (FieldValue.delete) in batches of 450.
  const SIZE = 450;
  let fsCount = 0;
  for (let i = 0; i < targets.length; i += SIZE) {
    const chunk = targets.slice(i, i + SIZE);
    const batch = db.batch();
    for (const t of chunk) {
      const patch = {};
      for (const f of t.fields) patch[f] = admin.firestore.FieldValue.delete();
      batch.update(t.ref, patch);
    }
    await batch.commit();
    fsCount += chunk.length;
    process.stdout.write(`\r  Firestore scrubbed: ${fsCount}/${targets.length}   `);
  }
  console.log();

  // 2) Firebase Auth: clear displayName / photoURL. Only the target uids; many
  //    have no Auth record (pure seed docs) — swallow not-found per user.
  let authCount = 0;
  for (const t of targets) {
    try {
      await auth.updateUser(t.id, { displayName: null, photoURL: null });
      authCount++;
    } catch (err) {
      if (err.code !== 'auth/user-not-found') {
        console.warn(`  ! Auth update failed for ${t.id}: ${err.code || err.message}`);
      }
    }
  }
  console.log(`  Auth records cleared: ${authCount}`);

  console.log('\n✅ Done.');
  console.log(`   Firestore docs scrubbed : ${fsCount}`);
  console.log(`   Auth records cleared    : ${authCount}`);
  console.log(`   Excluded (kept names)   : ${exclude.size}`);
  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌ Scrub failed:', err);
  process.exit(1);
});
