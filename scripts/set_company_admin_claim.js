/**
 * Şirket yöneticisi custom claim ayarlama scripti
 *
 * Kullanım:
 *   node set_company_admin_claim.js <email> <company_id>
 *
 * Örnek:
 *   node set_company_admin_claim.js portal.garanti@pom.app garanti_bbva
 */

const admin = require('firebase-admin');
const path  = require('path');

if (!admin.apps.length) {
  const sa = require(path.resolve(__dirname, 'serviceAccountKey.json'));
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}

async function main() {
  const email     = process.argv[2];
  const companyId = process.argv[3];

  if (!email || !companyId) {
    console.error('Kullanım: node set_company_admin_claim.js <email> <company_id>');
    process.exit(1);
  }

  const user = await admin.auth().getUserByEmail(email);

  await admin.auth().setCustomUserClaims(user.uid, {
    company_admin: true,
    company_id:    companyId,
  });

  console.log(`✅ Başarılı!`);
  console.log(`   Kullanıcı : ${email}`);
  console.log(`   UID       : ${user.uid}`);
  console.log(`   company_id: ${companyId}`);
  console.log(`\n⚠️  Kullanıcının tarayıcıda çıkış yapıp tekrar giriş yapması gerekiyor.`);
  process.exit(0);
}

main().catch(e => {
  console.error('Hata:', e.message);
  process.exit(1);
});
