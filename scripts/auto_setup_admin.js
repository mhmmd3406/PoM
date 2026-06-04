/**
 * auto_setup_admin.js
 * 1. Reads refresh_token from firebase-tools.json
 * 2. Gets a fresh access_token via Google OAuth
 * 3. Lists service accounts for pomapp-c3ccc
 * 4. Creates a key for the firebase-adminsdk SA
 * 5. Saves key to disk as sa_key.json
 * 6. Sets is_admin=true on the target email via Firebase Admin SDK
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
const SA_KEY_PATH = path.join(__dirname, 'sa_key.json');

// Target email for admin claim – use the firebase project owner
const ADMIN_EMAIL = 'ozkanmuhammed2@gmail.com';

function httpsRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function refreshToken(refreshToken) {
  console.log('[1/5] Refreshing OAuth token...');
  const body = new URLSearchParams({
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  }).toString();

  const res = await httpsRequest({
    hostname: 'oauth2.googleapis.com',
    path: '/token',
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body),
    },
  }, body);

  if (res.status !== 200) {
    throw new Error(`Token refresh failed ${res.status}: ${JSON.stringify(res.body)}`);
  }
  console.log('    ✓ Got fresh access token');
  return res.body.access_token;
}

async function listServiceAccounts(accessToken) {
  console.log('[2/5] Listing service accounts...');
  const res = await httpsRequest({
    hostname: 'iam.googleapis.com',
    path: `/v1/projects/${PROJECT_ID}/serviceAccounts`,
    method: 'GET',
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (res.status !== 200) {
    throw new Error(`List SA failed ${res.status}: ${JSON.stringify(res.body)}`);
  }

  const accounts = res.body.accounts || [];
  console.log(`    ✓ Found ${accounts.length} service accounts`);
  accounts.forEach(a => console.log(`      - ${a.email}`));
  return accounts;
}

async function createServiceAccountKey(accessToken, saEmail) {
  console.log(`[3/5] Creating key for ${saEmail}...`);
  const encodedEmail = encodeURIComponent(saEmail);
  const res = await httpsRequest({
    hostname: 'iam.googleapis.com',
    path: `/v1/projects/${PROJECT_ID}/serviceAccounts/${encodedEmail}/keys`,
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'Content-Length': 2,
    },
  }, '{}');

  if (res.status !== 200) {
    throw new Error(`Create key failed ${res.status}: ${JSON.stringify(res.body)}`);
  }

  // privateKeyData is base64-encoded JSON
  const keyJson = Buffer.from(res.body.privateKeyData, 'base64').toString('utf8');
  console.log('    ✓ Key created');
  return keyJson;
}

async function setAdminClaim(saKeyPath, email) {
  console.log(`[4/5] Initializing Firebase Admin SDK...`);

  // We need firebase-admin – check if available
  let admin;
  try {
    admin = require('firebase-admin');
  } catch (e) {
    // Try installing it first
    throw new Error('firebase-admin not found. Will use set_admin_claim.js instead.');
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(require(saKeyPath)),
    });
  }

  console.log(`[5/5] Setting is_admin=true on ${email}...`);
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { is_admin: true });
  console.log(`    ✓ is_admin=true set on uid=${user.uid}`);
  await admin.app().delete();
}

async function main() {
  // Read refresh token
  const config = JSON.parse(fs.readFileSync(FIREBASE_TOOLS_JSON, 'utf8'));
  const rt = config.tokens && config.tokens.refresh_token;
  if (!rt) throw new Error('No refresh_token found in firebase-tools.json');

  // Step 1: refresh
  const accessToken = await refreshToken(rt);

  // Step 2: list SAs
  const accounts = await listServiceAccounts(accessToken);

  // Find firebase-adminsdk SA
  const adminSA = accounts.find(a => a.email.startsWith('firebase-adminsdk'));
  if (!adminSA) throw new Error('No firebase-adminsdk service account found!');
  console.log(`    Using SA: ${adminSA.email}`);

  // Step 3: create key
  const keyJson = await createServiceAccountKey(accessToken, adminSA.email);
  fs.writeFileSync(SA_KEY_PATH, keyJson);
  console.log(`    ✓ Key saved to ${SA_KEY_PATH}`);

  // Step 4+5: set admin claim
  try {
    await setAdminClaim(SA_KEY_PATH, ADMIN_EMAIL);
    console.log('\n✅ Done! Admin claim set. Sign out and back in on the portal.');
  } catch (e) {
    if (e.message.includes('not found')) {
      // Fallback: use set_admin_claim.js
      console.log('    firebase-admin not available, running set_admin_claim.js...');
      const { execSync } = require('child_process');
      const cmd = `set GOOGLE_APPLICATION_CREDENTIALS=${SA_KEY_PATH} && node "${path.join(__dirname, 'set_admin_claim.js')}" ${ADMIN_EMAIL}`;
      console.log(`    Running: ${cmd}`);
      const out = execSync(cmd, { cwd: path.join(__dirname, '..', '..'), encoding: 'utf8' });
      console.log(out);
      console.log('\n✅ Done! Admin claim set. Sign out and back in on the portal.');
    } else {
      throw e;
    }
  }
}

main().catch(err => {
  console.error('❌ Error:', err.message || err);
  process.exit(1);
});
