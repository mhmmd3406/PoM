const admin = require("firebase-admin");
if (!admin.apps.length) {
  const sa = require(require("path").resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS));
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
async function main() {
  const email = process.argv[2];
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { is_admin: true });
  console.log("OK - cikis yapip tekrar giris yapin");
  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
