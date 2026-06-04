/**
 * check_surveys.js — lists all survey docs (companyId/status/title) in Firestore.
 * Usage: GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json node check_surveys.js
 */
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

(async () => {
  const snap = await db.collection('surveys').get();
  console.log('Total surveys:', snap.size);
  snap.forEach((d) => {
    const x = d.data();
    console.log(
      `- ${d.id} | companyId=${x.companyId} | status=${x.status} | isGate=${x.isGate || false} | q=${(x.questions || []).length} | resp=${x.responseCount || 0} | "${x.title}"`
    );
  });
  const rsnap = await db.collection('survey_responses').get();
  console.log('Total survey_responses:', rsnap.size);
  process.exit(0);
})().catch((e) => { console.error('ERR', e.message); process.exit(1); });
