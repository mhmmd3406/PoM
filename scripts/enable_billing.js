/**
 * Lists GCP billing accounts and links pomapp-c3ccc to one via Cloud Billing API.
 * Uses the firebase-tools OAuth token (ozkanmuhammed2@gmail.com, cloud-platform scope).
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
  const bodyStr = body ? JSON.stringify(body) : '';
  return new Promise((resolve, reject) => {
    const r = https.request({
      hostname, path: path_, method,
      headers: {
        ...headers,
        ...(bodyStr ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(bodyStr) } : {}),
      },
    }, (res) => {
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
    { 'Content-Type': 'application/x-www-form-urlencoded' }, null);
  // manual post for form data
  return new Promise((resolve, reject) => {
    const r = https.request({
      hostname: 'oauth2.googleapis.com', path: '/token', method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(body) },
    }, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => { try { resolve(JSON.parse(d)); } catch (e) { resolve(d); } });
    });
    r.on('error', reject);
    r.write(body);
    r.end();
  });
}

async function main() {
  const config = JSON.parse(fs.readFileSync(FIREBASE_TOOLS_JSON, 'utf8'));
  const rt = config.tokens.refresh_token;

  console.log('[1] Refreshing token...');
  const tokenData = await refreshToken(rt);
  if (!tokenData.access_token) throw new Error(`Token refresh failed: ${JSON.stringify(tokenData)}`);
  const token = tokenData.access_token;
  console.log('    ✓');

  console.log('[2] Listing billing accounts...');
  const billingRes = await req('GET', 'cloudbilling.googleapis.com',
    '/v1/billingAccounts',
    { Authorization: `Bearer ${token}` });
  console.log(`    Status: ${billingRes.status}`);

  if (billingRes.status !== 200) {
    console.log('    Response:', JSON.stringify(billingRes.body, null, 2));
    return;
  }

  const accounts = billingRes.body.billingAccounts || [];
  console.log(`    Found ${accounts.length} billing account(s):`);
  accounts.forEach(a => console.log(`    - ${a.name}: ${a.displayName} (open=${a.open})`));

  if (accounts.length === 0) {
    console.log('\n⚠️  No billing accounts found for this Google account.');
    console.log('   You need to create a billing account first at:');
    console.log('   https://console.cloud.google.com/billing/create');
    return;
  }

  // Check current billing info for the project
  console.log('\n[3] Checking current billing for pomapp-c3ccc...');
  const infoRes = await req('GET', 'cloudbilling.googleapis.com',
    `/v1/projects/${PROJECT_ID}/billingInfo`,
    { Authorization: `Bearer ${token}` });
  console.log(`    Status: ${infoRes.status}`);
  console.log('    Current:', JSON.stringify(infoRes.body, null, 2));

  const openAccount = accounts.find(a => a.open === true);
  if (!openAccount) {
    console.log('\n⚠️  All billing accounts are closed/inactive.');
    return;
  }

  // Link the billing account to the project
  console.log(`\n[4] Linking ${openAccount.name} to ${PROJECT_ID}...`);
  const linkRes = await req('PUT', 'cloudbilling.googleapis.com',
    `/v1/projects/${PROJECT_ID}/billingInfo`,
    { Authorization: `Bearer ${token}` },
    { billingAccountName: openAccount.name }
  );
  console.log(`    Status: ${linkRes.status}`);
  console.log('    Response:', JSON.stringify(linkRes.body, null, 2));

  if (linkRes.status === 200) {
    console.log('\n✅ Billing enabled! Project is now on Blaze plan.');
    console.log('   Run: firebase deploy --only functions');
  }
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
