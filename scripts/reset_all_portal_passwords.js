/**
 * Sets/resets passwords for all portal accounts
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

// All portal accounts from list_auth_users.js output
const PORTAL_ACCOUNTS = [
  { uid: 'MCZ5LPZYgNbASe4DNAGVGqYM6iM2', email: 'admin@pom.app',           password: 'PomAdmin2026!' },
  { uid: '0C0xnhZmhNR2Qj3ZyXh8pHEEapj1', email: 'portal.garanti@pom.app',  password: 'Garanti2026!' },
  { uid: '0LmYYddBxRRQL65zuK4OupeNHcd2', email: 'portal.turkcell@pom.app', password: 'Turkcell2026!' },
  { uid: 'BepcBuJwQ4OjCQJM6fo4bSY39Wr1', email: 'portal.startup@pom.app',  password: 'Startup2026!' },
  { uid: 'truNWl0iXQX7rcxPGGQu3Q1rsb52', email: 'portal.akbank@pom.app',   password: 'Akbank2026!' },
];

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

  console.log('Refreshing OAuth token...');
  const tokenBody = `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(rt)}&grant_type=refresh_token`;
  const tokenRes = await post('oauth2.googleapis.com', '/token',
    { 'Content-Type': 'application/x-www-form-urlencoded' }, tokenBody);
  if (tokenRes.status !== 200) throw new Error(`Token: ${JSON.stringify(tokenRes.body)}`);
  const accessToken = tokenRes.body.access_token;

  console.log('\nSetting passwords:\n');
  for (const acct of PORTAL_ACCOUNTS) {
    const res = await post(
      'identitytoolkit.googleapis.com',
      `/v1/projects/${PROJECT_ID}/accounts:update`,
      { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      { localId: acct.uid, password: acct.password }
    );
    const ok = res.status === 200;
    console.log(`  ${ok ? '✓' : '✗'} ${acct.email.padEnd(28)} → ${acct.password}  [${res.status}]`);
    if (!ok) console.log('    Error:', JSON.stringify(res.body).substring(0, 120));
  }

  console.log('\n✅ All portal credentials:');
  console.log('  URL: https://pomapp-c3ccc.web.app\n');
  PORTAL_ACCOUNTS.forEach(a =>
    console.log(`  ${a.email.padEnd(28)} / ${a.password}`)
  );
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
