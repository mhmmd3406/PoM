/**
 * set_admin_rest.js
 * Sets is_admin=true custom claim via Identity Toolkit REST API
 * Uses the same OAuth token firebase-tools has (no service account / JWT needed)
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
const ADMIN_EMAIL = process.argv[2] || 'ozkanmuhammed2@gmail.com';

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

async function refreshToken(refreshToken) {
  const body = `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(refreshToken)}&grant_type=refresh_token`;
  const res = await httpsPost('oauth2.googleapis.com', '/token',
    { 'Content-Type': 'application/x-www-form-urlencoded' }, body);
  if (res.status !== 200) throw new Error(`Token refresh failed: ${JSON.stringify(res.body)}`);
  return res.body.access_token;
}

async function lookupUserByEmail(accessToken, email) {
  const res = await httpsPost(
    'identitytoolkit.googleapis.com',
    `/v1/projects/${PROJECT_ID}/accounts:lookup`,
    { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    { email: [email] }
  );
  if (res.status !== 200) throw new Error(`Lookup failed ${res.status}: ${JSON.stringify(res.body)}`);
  const users = res.body.users;
  if (!users || users.length === 0) throw new Error(`User not found: ${email}`);
  return users[0];
}

async function setCustomClaims(accessToken, localId, claims) {
  const res = await httpsPost(
    'identitytoolkit.googleapis.com',
    `/v1/projects/${PROJECT_ID}/accounts:update`,
    { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    { localId, customAttributes: JSON.stringify(claims) }
  );
  if (res.status !== 200) throw new Error(`SetClaims failed ${res.status}: ${JSON.stringify(res.body)}`);
  return res.body;
}

async function main() {
  console.log(`Setting is_admin=true on ${ADMIN_EMAIL}...`);

  const config = JSON.parse(fs.readFileSync(FIREBASE_TOOLS_JSON, 'utf8'));
  const rt = config.tokens && config.tokens.refresh_token;
  if (!rt) throw new Error('No refresh_token in firebase-tools.json');

  console.log('[1/3] Refreshing OAuth token...');
  const accessToken = await refreshToken(rt);
  console.log('      ✓ OK');

  console.log(`[2/3] Looking up user ${ADMIN_EMAIL}...`);
  const user = await lookupUserByEmail(accessToken, ADMIN_EMAIL);
  console.log(`      ✓ uid = ${user.localId}`);

  console.log('[3/3] Setting custom claim is_admin=true...');
  await setCustomClaims(accessToken, user.localId, { is_admin: true });
  console.log('      ✓ Done!');

  console.log('\n✅ is_admin=true set on', ADMIN_EMAIL);
  console.log('   → Sign out and back in on the admin portal to activate the claim.');
}

main().catch(err => {
  console.error('❌', err.message);
  process.exit(1);
});
