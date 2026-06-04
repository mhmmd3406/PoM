/**
 * enable_anonymous_auth.js
 * Enables the Anonymous sign-in provider on the Firebase project via the
 * Identity Toolkit Admin v2 API, reusing the firebase-tools OAuth token
 * (same approach as set_admin_rest.js — no service-account JWT needed).
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

function httpsReq(method, hostname, path_, headers, body) {
  const bodyStr = body == null ? '' : (typeof body === 'string' ? body : JSON.stringify(body));
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname, path: path_, method,
      headers: { ...headers, 'Content-Length': Buffer.byteLength(bodyStr) },
    }, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch (e) { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

async function refreshToken(rt) {
  const body = `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(rt)}&grant_type=refresh_token`;
  const res = await httpsReq('POST', 'oauth2.googleapis.com', '/token',
    { 'Content-Type': 'application/x-www-form-urlencoded' }, body);
  if (res.status !== 200) throw new Error(`Token refresh failed: ${JSON.stringify(res.body)}`);
  return res.body.access_token;
}

async function getConfig(accessToken) {
  return httpsReq('GET', 'identitytoolkit.googleapis.com',
    `/admin/v2/projects/${PROJECT_ID}/config`,
    { Authorization: `Bearer ${accessToken}` }, null);
}

async function enableAnonymous(accessToken) {
  return httpsReq('PATCH', 'identitytoolkit.googleapis.com',
    `/admin/v2/projects/${PROJECT_ID}/config?updateMask=signIn.anonymous.enabled`,
    { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    { signIn: { anonymous: { enabled: true } } });
}

async function main() {
  const config = JSON.parse(fs.readFileSync(FIREBASE_TOOLS_JSON, 'utf8'));
  const rt = config.tokens && config.tokens.refresh_token;
  if (!rt) throw new Error('No refresh_token in firebase-tools.json (run `firebase login`)');

  console.log('[1/3] Refreshing OAuth token...');
  const accessToken = await refreshToken(rt);
  console.log('      ✓ OK');

  console.log('[2/3] Current anonymous state...');
  const before = await getConfig(accessToken);
  if (before.status !== 200) throw new Error(`getConfig ${before.status}: ${JSON.stringify(before.body)}`);
  console.log('      anonymous.enabled =', before.body?.signIn?.anonymous?.enabled ?? false);

  console.log('[3/3] Enabling anonymous sign-in...');
  const res = await enableAnonymous(accessToken);
  if (res.status !== 200) throw new Error(`PATCH ${res.status}: ${JSON.stringify(res.body)}`);
  console.log('      ✓ anonymous.enabled =', res.body?.signIn?.anonymous?.enabled);
  console.log('\n✅ Anonymous sign-in enabled on', PROJECT_ID);
}

main().catch((err) => { console.error('❌', err.message); process.exit(1); });
