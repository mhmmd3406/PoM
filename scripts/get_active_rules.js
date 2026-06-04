/**
 * get_active_rules.js — prints the ACTIVE Firestore ruleset source for the project,
 * using the firebase-tools OAuth token (Firebase Rules REST API).
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
  const at = await token();
  const auth = { Authorization: `Bearer ${at}` };
  const rel = await req('GET', 'firebaserules.googleapis.com', `/v1/projects/${PROJECT_ID}/releases`, auth, null);
  if (rel.status !== 200) throw new Error(`releases ${rel.status}: ${JSON.stringify(rel.body)}`);
  const fsRel = (rel.body.releases || []).find((r) => r.name.endsWith('cloud.firestore'));
  if (!fsRel) throw new Error('No cloud.firestore release found');
  console.log('Active release:', fsRel.name);
  console.log('Ruleset:', fsRel.rulesetName);
  const rs = await req('GET', 'firebaserules.googleapis.com', `/v1/${fsRel.rulesetName}`, auth, null);
  if (rs.status !== 200) throw new Error(`ruleset ${rs.status}: ${JSON.stringify(rs.body)}`);
  for (const f of rs.body.source.files) {
    console.log(`\n===== ${f.name} =====`);
    console.log(f.content);
  }
}
main().catch((e) => { console.error('ERR', e.message); process.exit(1); });
