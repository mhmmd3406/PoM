/**
 * Lists all Firebase Auth users via REST API
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

function httpsPost(hostname, path_, headers, body) {
  const bodyStr = typeof body === 'string' ? body : JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname, path: path_, method: 'POST',
      headers: { ...headers, 'Content-Length': Buffer.byteLength(bodyStr) },
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch (e) { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  });
}

async function refreshToken(rt) {
  const body = `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(rt)}&grant_type=refresh_token`;
  const res = await httpsPost('oauth2.googleapis.com', '/token',
    { 'Content-Type': 'application/x-www-form-urlencoded' }, body);
  if (res.status !== 200) throw new Error(`Token refresh failed: ${JSON.stringify(res.body)}`);
  return res.body.access_token;
}

async function main() {
  const config = JSON.parse(fs.readFileSync(FIREBASE_TOOLS_JSON, 'utf8'));
  const rt = config.tokens.refresh_token;
  const accessToken = await refreshToken(rt);

  // Download all users
  const res = await httpsPost(
    'identitytoolkit.googleapis.com',
    `/v1/projects/${PROJECT_ID}/accounts:query`,
    { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    { returnUserInfo: true }
  );

  if (res.status !== 200) {
    // Try batchGet approach
    const res2 = await httpsPost(
      'identitytoolkit.googleapis.com',
      `/v1/projects/${PROJECT_ID}/accounts:batchGet`,
      { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      {}
    );
    console.log('batchGet status:', res2.status);
    console.log(JSON.stringify(res2.body, null, 2));
    return;
  }

  const users = res.body.userInfo || res.body.users || [];
  console.log(`Found ${users.length} users:`);
  users.forEach(u => {
    console.log(`  uid=${u.localId} email=${u.email || '(no email)'} displayName=${u.displayName || '-'}`);
    if (u.customAttributes) console.log(`    claims: ${u.customAttributes}`);
  });
}

main().catch(err => { console.error('❌', err.message); process.exit(1); });
