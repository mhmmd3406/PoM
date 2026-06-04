/**
 * Quick Firestore data check via REST API
 */
const https = require('https');
const fs = require('fs');
const path = require('path');

const FIREBASE_TOOLS_JSON = path.join(
  process.env.USERPROFILE || '', '.config/configstore/firebase-tools.json'
);
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const PROJECT_ID = 'pomapp-c3ccc';

function req(method, hostname, path_, headers, body) {
  const bodyStr = body ? (typeof body === 'string' ? body : JSON.stringify(body)) : '';
  return new Promise((resolve, reject) => {
    const opts = {
      hostname, path: path_, method,
      headers: { ...headers, ...(bodyStr ? { 'Content-Length': Buffer.byteLength(bodyStr) } : {}) }
    };
    const r = https.request(opts, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch (e) { resolve({ status: res.statusCode, body: d }); }
      });
    });
    r.on('error', reject);
    if (bodyStr) r.write(bodyStr);
    r.end();
  });
}

async function refreshToken(rt) {
  const body = `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(rt)}&grant_type=refresh_token`;
  const res = await req('POST', 'oauth2.googleapis.com', '/token',
    { 'Content-Type': 'application/x-www-form-urlencoded' }, body);
  if (res.status !== 200) throw new Error(`Token: ${JSON.stringify(res.body)}`);
  return res.body.access_token;
}

async function fsGet(token, collection) {
  const res = await req('GET',
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}?pageSize=5`,
    { Authorization: `Bearer ${token}` }
  );
  return res;
}

async function main() {
  const config = JSON.parse(fs.readFileSync(FIREBASE_TOOLS_JSON, 'utf8'));
  const token = await refreshToken(config.tokens.refresh_token);

  const collections = ['users', 'checkins', 'surveys', 'companies'];
  for (const col of collections) {
    const res = await fsGet(token, col);
    const count = (res.body.documents || []).length;
    if (res.status === 200) {
      console.log(`✓ ${col}: ${count} docs (showing first ${count})`);
      if (col === 'users' && count > 0) {
        res.body.documents.slice(0, 3).forEach(d => {
          const fields = d.fields || {};
          const email = fields.email?.stringValue || '?';
          const role = fields.role?.stringValue || '?';
          console.log(`    - ${email} [${role}]`);
        });
      }
    } else {
      console.log(`✗ ${col}: ${res.status} ${JSON.stringify(res.body).substring(0, 100)}`);
    }
  }
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
