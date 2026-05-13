'use strict';

const axios = require('axios');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { defineSecret, defineString } = require('firebase-functions/params');

// Secrets stored in Google Cloud Secret Manager.
// Set via: firebase functions:secrets:set LINKEDIN_CLIENT_SECRET
// Set via: firebase functions:secrets:set LINKEDIN_ID_SALT
const linkedinClientSecret = defineSecret('LINKEDIN_CLIENT_SECRET');
const linkedinIdSalt = defineSecret('LINKEDIN_ID_SALT');

// Non-secret config (safe to be in environment)
const LINKEDIN_CLIENT_ID = defineString('LINKEDIN_CLIENT_ID');
const LINKEDIN_REDIRECT_URI = defineString('LINKEDIN_REDIRECT_URI');

/**
 * Exchange LinkedIn auth code for an access token.
 */
async function exchangeCode(code) {
  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: LINKEDIN_REDIRECT_URI.value(),
    client_id: LINKEDIN_CLIENT_ID.value(),
    client_secret: linkedinClientSecret.value(),
  });

  const { data } = await axios.post(
    'https://www.linkedin.com/oauth/v2/accessToken',
    params.toString(),
    { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } },
  );
  return data.access_token;
}

/**
 * Fetch LinkedIn profile using the OpenID Connect userinfo endpoint.
 * Scopes required: openid, profile
 * Returns: { sub, name, headline }
 */
async function fetchLinkedInProfile(accessToken) {
  const { data } = await axios.get('https://api.linkedin.com/v2/userinfo', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  // `sub` is the stable LinkedIn member identifier
  return { linkedinId: data.sub, name: data.name, headline: data.headline || '' };
}

/**
 * Hash the LinkedIn ID with HMAC-SHA256 + server-side salt.
 * The hash is the only persistent identifier stored in Firestore.
 */
function hashLinkedInId(linkedinId) {
  return crypto.createHmac('sha256', linkedinIdSalt.value()).update(linkedinId).digest('hex');
}

/**
 * Find or create a Firebase Auth user whose displayName encodes the linkedin_hash.
 * We use linkedin_hash as the Firebase UID to guarantee uniqueness without storing PII.
 *
 * Firebase UID max length is 128 chars; SHA-256 hex = 64 chars → safe.
 */
async function getOrCreateFirebaseUser(linkedinHash, headline) {
  try {
    return await admin.auth().getUser(linkedinHash);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;

    return admin.auth().createUser({
      uid: linkedinHash,
      // Store headline in displayName for the Cloud Function trigger —
      // never stored in Firestore; used only to bootstrap business_family mapping.
      displayName: headline.slice(0, 256),
    });
  }
}

const MOBILE_CALLBACK_SCHEME = 'com.pom.app';

/**
 * Redirects to the mobile deep-link with the result encoded as query params.
 * FlutterWebAuth2 captures this redirect and returns the URL to the app.
 */
function redirectToApp(res, params) {
  const url = new URL(`${MOBILE_CALLBACK_SCHEME}://callback`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, String(v));
  return res.redirect(302, url.toString());
}

/**
 * Main handler: LinkedIn OAuth callback → mobile deep-link redirect.
 *
 * GET /linkedinCallback?code=...&state=...
 *
 * On success:  redirects → com.pom.app://callback?customToken=...&isNewUser=...&state=...
 * On cancel:   redirects → com.pom.app://callback?error=access_denied&error_description=...
 * On failure:  redirects → com.pom.app://callback?error=<code>
 */
async function handleLinkedInCallback(req, res) {
  const { code, state, error, error_description } = req.query;

  // LinkedIn sends error=access_denied when user cancels
  if (error) {
    return redirectToApp(res, {
      error,
      error_description: error_description || 'Login was cancelled or denied.',
    });
  }

  if (!code) {
    return redirectToApp(res, { error: 'missing_code' });
  }

  if (!state || state.length < 8) {
    return redirectToApp(res, { error: 'invalid_state' });
  }

  let accessToken;
  try {
    accessToken = await exchangeCode(code);
  } catch (err) {
    console.error('LinkedIn token exchange failed:', err.response?.data || err.message);
    return redirectToApp(res, { error: 'linkedin_token_exchange_failed' });
  }

  let profile;
  try {
    profile = await fetchLinkedInProfile(accessToken);
  } catch (err) {
    console.error('LinkedIn profile fetch failed:', err.response?.data || err.message);
    return redirectToApp(res, { error: 'linkedin_profile_fetch_failed' });
  }

  const linkedinHash = hashLinkedInId(profile.linkedinId);

  let firebaseUser;
  let isNewUser = false;
  try {
    const existing = await admin.auth().getUser(linkedinHash).catch(() => null);
    isNewUser = !existing;
    firebaseUser = await getOrCreateFirebaseUser(linkedinHash, profile.headline);
  } catch (err) {
    console.error('Firebase user creation failed:', err.message);
    return redirectToApp(res, { error: 'firebase_user_error' });
  }

  const customToken = await admin.auth().createCustomToken(firebaseUser.uid, {
    linkedin_hash: linkedinHash,
    headline: profile.headline.slice(0, 256),
  });

  return redirectToApp(res, { customToken, isNewUser, state });
}

// Exported for index.js to declare secrets on the HTTP trigger
module.exports = {
  handleLinkedInCallback,
  hashLinkedInId,
  linkedinSecrets: [linkedinClientSecret, linkedinIdSalt],
};
