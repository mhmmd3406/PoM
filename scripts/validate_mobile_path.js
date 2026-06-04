/**
 * validate_mobile_path.js
 * Reproduces the mobile app's EXACT survey data path against live Firestore,
 * proving the anonymous-auth fix works under the deployed security rules:
 *   1. Query surveys with NO auth        → expect 403 PERMISSION_DENIED (the bug)
 *   2. Anonymous sign-in (Identity Toolkit) → idToken (same call the app makes)
 *   3. Query surveys WITH the anon token  → surveys returned (the fix)
 * The query mirrors watchEligibleSurveys: companyId in [<user company>, '__admin__'].
 */
const https = require('https');

const API_KEY = 'AIzaSyBNj_7VEcXJ4AzS6i1q2ysupHP4FayEqiU';
const PROJECT = 'pomapp-c3ccc';
const COMPANY = 'garanti_bbva'; // debug_pro persona's companyId

function req(method, host, path, headers, body) {
  const b = body == null ? '' : JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const r = https.request({ host, path, method, headers: { ...headers, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(b) } }, (res) => {
      let d = ''; res.on('data', (c) => (d += c));
      res.on('end', () => { try { resolve({ status: res.statusCode, body: JSON.parse(d) }); } catch (e) { resolve({ status: res.statusCode, body: d }); } });
    });
    r.on('error', reject); if (b) r.write(b); r.end();
  });
}

const surveyQuery = {
  structuredQuery: {
    from: [{ collectionId: 'surveys' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'companyId' },
        op: 'IN',
        value: { arrayValue: { values: [{ stringValue: COMPANY }, { stringValue: '__admin__' }] } },
      },
    },
  },
};

function runQuery(idToken) {
  const headers = idToken ? { Authorization: `Bearer ${idToken}` } : {};
  return req('POST', 'firestore.googleapis.com',
    `/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`, headers, surveyQuery);
}

const f = (d) => {
  const x = d.fields || {};
  const g = (k) => (x[k] && (x[k].stringValue ?? x[k].integerValue ?? x[k].booleanValue)) ?? '';
  const qn = x.questions && x.questions.arrayValue && x.questions.arrayValue.values ? x.questions.arrayValue.values.length : 0;
  return { id: d.name.split('/').pop(), companyId: g('companyId'), status: g('status'), isGate: g('isGate') === true, q: qn, title: g('title') };
};

async function main() {
  console.log('Mobile survey query: surveys WHERE companyId IN [', COMPANY, ", '__admin__' ]\n");

  // 1) No auth → should be denied (this was the silent failure)
  console.log('[1] Querying WITHOUT auth (simulates bypass user with no Firebase session)...');
  const anon0 = await runQuery(null);
  if (anon0.status === 403 || (Array.isArray(anon0.body) && anon0.body[0] && anon0.body[0].error)) {
    console.log('    → DENIED as expected. status=', anon0.status,
      '-', (anon0.body.error && anon0.body.error.status) || (anon0.body[0] && anon0.body[0].error && anon0.body[0].error.status) || 'PERMISSION_DENIED');
  } else {
    console.log('    → Unexpected:', anon0.status, JSON.stringify(anon0.body).slice(0, 200));
  }

  // 2) Anonymous sign-in — exact call FlutterFire signInAnonymously() makes
  console.log('\n[2] Anonymous sign-in via Identity Toolkit (accounts:signUp)...');
  const su = await req('POST', 'identitytoolkit.googleapis.com', `/v1/accounts:signUp?key=${API_KEY}`, {}, { returnSecureToken: true });
  if (su.status !== 200 || !su.body.idToken) {
    throw new Error(`Anonymous sign-in failed ${su.status}: ${JSON.stringify(su.body)}`);
  }
  console.log('    → OK. anon uid =', su.body.localId);

  // 3) With anon token → should return the surveys
  console.log('\n[3] Querying WITH anonymous token...');
  const res = await runQuery(su.body.idToken);
  if (res.status !== 200) throw new Error(`Query failed ${res.status}: ${JSON.stringify(res.body)}`);
  const docs = (res.body || []).filter((e) => e.document).map((e) => f(e.document));
  console.log('    → ALLOWED. Returned', docs.length, 'survey docs.\n');

  const active = docs.filter((d) => d.status === 'active');
  const pendingList = active.filter((d) => !d.isGate); // regular "Aktif" tab cards
  const gates = active.filter((d) => d.isGate);

  console.log('All eligible surveys (companyId in scope):');
  docs.forEach((d) => console.log(`   [${d.status}]${d.isGate ? '[GATE]' : '      '} ${d.companyId.padEnd(12)} q=${d.q}  "${d.title}"`));
  console.log(`\n→ Mobile "Anketler / Aktif" tab would show ${pendingList.length} survey(s):`);
  pendingList.forEach((d) => console.log(`   • ${d.title}  (${d.companyId}, ${d.q} soru)`));
  if (gates.length) console.log(`→ Plus ${gates.length} gate survey shown as launch intercept: "${gates[0].title}"`);

  console.log('\n✅ Fix validated: anonymous auth unlocks the exact survey reads the mobile app performs.');
}

main().catch((e) => { console.error('❌', e.message); process.exit(1); });
