/**
 * Resets admin@pom.app password via Identity Toolkit REST API
 * Admin uid: MCZ5LPZYgNbASe4DNAGVGqYM6iM2
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

// admin@pom.app  uid (from list_auth_users output)
const ADMIN_UID   = 'MCZ5LPZYgNbASe4DNAGVGqYM6iM2';
const NEW_PASSWORD = 'PomAdmin2026!';

function post(hostname, path_, headers, body) {
  const bodyStr = typeof body === 'string' ? body : JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname, path: path_, method: 'POST',
      headers: { ...headers, 'Content-Length': Buffer.byteLength(bodyStr) },
    }, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch (e) { resolve({ status: res.statusCode, body: d }); }
      });
    });
    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  });
}

async function main() {
  const config = JSON.parse(fs.readFileSync(FIREBASE_TOOLS_JSON, 'utf8'));
  const rt = config.tokens.refresh_token;

  console.log('[1/2] Refreshing OAuth token...');
  const tokenBody = `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(rt)}&grant_type=refresh_token`;
  const tokenRes = await post('oauth2.googleapis.com', '/token',
    { 'Content-Type': 'application/x-www-form-urlencoded' }, tokenBody);
  if (tokenRes.status !== 200) throw new Error(`Token refresh: ${JSON.stringify(tokenRes.body)}`);
  const accessToken = tokenRes.body.access_token;
  console.log('    ✓ OK');

  console.log(`[2/2] Resetting password for admin@pom.app (uid=${ADMIN_UID})...`);
  const res = await post(
    'identitytoolkit.googleapis.com',
    `/v1/projects/${PROJECT_ID}/accounts:update`,
    { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    { localId: ADMIN_UID, password: NEW_PASSWORD }
  );

  if (res.status !== 200) {
    throw new Error(`Password reset failed ${res.status}: ${JSON.stringify(res.body)}`);
  }

  console.log('    ✓ Done!');
  console.log('\n✅ Admin portal credentials:');
  console.log('   Email:    admin@pom.app');
  console.log(`   Password: ${NEW_PASSWORD}`);
  console.log('   URL:      https://pomapp-c3ccc.web.app/portal/ (or local dev)');
}

main().catch(err => { console.error('❌', err.message); process.exit(1); });
