/**
 * validate_rules.js — compiles mobile/firestore.rules against the Firebase Rules
 * API WITHOUT releasing it (creates a ruleset = syntax/compile check only, the
 * live rules are never touched). Cleans up the test ruleset afterwards.
 *
 * Usage: node validate_rules.js
 */
const https = require('https');
const fs = require('fs');
const path = require('path');

const FIREBASE_TOOLS_JSON = path.join(
  process.env.USERPROFILE || process.env.HOME || '',
  '.config/configstore/firebase-tools.json'
);
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const PROJECT_ID = 'pomapp-c3ccc';
const RULES_FILE = path.join(__dirname, '..', 'mobile', 'firestore.rules');

function req(method, hostname, p, headers, body) {
  const b = body == null ? '' : (typeof body === 'string' ? body : JSON.stringify(body));
  return new Promise((resolve, reject) => {
    const r = https.request({ hostname, path: p, method, headers: { ...headers, 'Content-Length': Buffer.byteLength(b) } }, (res) => {
      let d = ''; res.on('data', (c) => (d += c));
      res.on('end', () => { try { resolve({ status: res.statusCode, body: JSON.parse(d) }); } catch (e) { resolve({ status: res.statusCode, body: d }); } });
    });
    r.on('error', reject); if (b) r.write(b); r.end();
  });
}

async function token() {
  const cfg = JSON.parse(fs.readFileSync(FIREBASE_TOOLS_JSON, 'utf8'));
  const rt = cfg.tokens.refresh_token;
  const body = `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(rt)}&grant_type=refresh_token`;
  const res = await req('POST', 'oauth2.googleapis.com', '/token', { 'Content-Type': 'application/x-www-form-urlencoded' }, body);
  return res.body.access_token;
}

async function main() {
  const content = fs.readFileSync(RULES_FILE, 'utf8');
  console.log(`Validating ${RULES_FILE} (${content.length} bytes)...\n`);
  const at = await token();
  const auth = { Authorization: `Bearer ${at}`, 'Content-Type': 'application/json' };
  const payload = { source: { files: [{ name: 'firestore.rules', content }] } };

  const res = await req('POST', 'firebaserules.googleapis.com', `/v1/projects/${PROJECT_ID}/rulesets`, auth, payload);

  if (res.status === 200) {
    console.log('✅ RULES VALID — compiled successfully (not released).');
    console.log('   Test ruleset:', res.body.name);
    // Clean up: delete the throwaway test ruleset so it doesn't linger.
    const del = await req('DELETE', 'firebaserules.googleapis.com', `/v1/${res.body.name}`, auth, null);
    console.log('   Cleanup delete status:', del.status);
    process.exit(0);
  }

  console.log('❌ RULES INVALID — status', res.status);
  console.log(JSON.stringify(res.body, null, 2));
  process.exit(1);
}
main().catch((e) => { console.error('ERR', e.message); process.exit(1); });
