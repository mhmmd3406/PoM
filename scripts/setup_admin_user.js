#!/usr/bin/env node
/**
 * PoM — Admin kullanıcı kurulum scripti
 *
 * - admin@pom.app kullanıcısı yoksa oluşturur
 * - is_admin: true custom claim'ini set eder
 *
 * Kullanım:
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\...\serviceaccount.json"
 *   node scripts/setup_admin_user.js --email admin@pom.app --password YENI_SIFRE
 */

'use strict';

const admin = require('firebase-admin');

// ─── Args ─────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const getArg = (flag) => {
  const i = args.indexOf(flag);
  return i !== -1 ? args[i + 1] : null;
};

const email    = getArg('--email')    || 'admin@pom.app';
const password = getArg('--password');

if (!password) {
  console.error('\n❌ --password parametresi zorunlu.\n');
  console.error('   Kullanım: node setup_admin_user.js --email admin@pom.app --password SIFRENIZ\n');
  process.exit(1);
}

// ─── Init ─────────────────────────────────────────────────────────────────────

if (!admin.apps.length) {
  admin.initializeApp(); // GOOGLE_APPLICATION_CREDENTIALS env var'ını kullanır
}

const authAdmin = admin.auth();

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`\n🚀 PoM Admin Kullanıcı Kurulumu\n`);
  console.log(`   E-posta : ${email}`);

  let uid;

  // 1. Kullanıcı var mı kontrol et
  try {
    const existing = await authAdmin.getUserByEmail(email);
    uid = existing.uid;
    console.log(`\n✅ Kullanıcı zaten mevcut — uid: ${uid}`);

    // Şifreyi güncelle
    await authAdmin.updateUser(uid, { password });
    console.log(`   Şifre güncellendi.`);
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      // 2. Yoksa oluştur
      const created = await authAdmin.createUser({ email, password, emailVerified: true });
      uid = created.uid;
      console.log(`\n✅ Kullanıcı oluşturuldu — uid: ${uid}`);
    } else {
      throw err;
    }
  }

  // 3. is_admin custom claim'ini set et
  await authAdmin.setCustomUserClaims(uid, { is_admin: true });
  console.log(`   Custom claim set edildi: is_admin=true`);

  console.log(`\n🎉 Hazır! Şimdi panele giriş yapabilirsiniz:`);
  console.log(`   E-posta : ${email}`);
  console.log(`   Şifre   : ${password}\n`);
}

main().catch(err => {
  console.error('\n❌ Hata:', err.message ?? err);
  process.exit(1);
});
