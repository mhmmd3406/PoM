'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const { mapTitleToBusinessFamily } = require('./src/titleMapper');
const { grantSignupBonus, awardCheckinCredits, authorizeQuery, recordMicropayment } = require('./src/credits');
const { updateAggregation, reconcileAggregations, getInsights } = require('./src/aggregations');
const { generateB2BSnapshots, getB2BTrendFromSnapshots } = require('./src/b2bSnapshots');
const { handleLinkedInCallback, linkedinSecrets } = require('./src/linkedinAuth');
const {
  handleSubscriptionWebhook,
  syncSubscriptionClaim,
  createCheckoutSession,
  createPortalSession,
  subscriptionSecrets,
} = require('./src/subscriptions');
const { defineSecret } = require('firebase-functions/params');

// All secrets are stored in Google Cloud Secret Manager.
// Provision via: firebase functions:secrets:set <NAME>
const linkedinIdSalt = defineSecret('LINKEDIN_ID_SALT');

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Auth: on user creation via LinkedIn OAuth
// Hashes the LinkedIn UID and creates the user document.
// ---------------------------------------------------------------------------
exports.onUserCreated = functions
  .runWith({ secrets: ['LINKEDIN_ID_SALT'] })
  .auth.user()
  .onCreate(async (user) => {
    const crypto = require('crypto');
    const salt = linkedinIdSalt.value();

    const linkedinHash = crypto
      .createHmac('sha256', salt)
      .update(user.uid)
      .digest('hex');

  await db.collection('users').doc(user.uid).set({
    linkedin_hash: linkedinHash,
    bank_id: null,
    business_family: null,
    department_type: null,
    seniority_level: null,
    credits: 0,
    joined_at: admin.firestore.FieldValue.serverTimestamp(),
    last_checkin_at: null,
    checkin_streak: 0,
  });

  await grantSignupBonus(user.uid);
});

// ---------------------------------------------------------------------------
// Callable: complete profile (called once after LinkedIn OAuth + title known)
// ---------------------------------------------------------------------------
exports.completeProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');

  const { linkedinTitle, bankId } = data;
  if (!linkedinTitle || !bankId) {
    throw new functions.https.HttpsError('invalid-argument', 'linkedinTitle and bankId are required');
  }

  const { businessFamily, departmentType, seniorityLevel } = mapTitleToBusinessFamily(linkedinTitle);

  await db.collection('users').doc(context.auth.uid).update({
    bank_id: bankId,
    business_family: businessFamily,
    department_type: departmentType,
    seniority_level: seniorityLevel,
  });

  return { businessFamily, departmentType, seniorityLevel };
});

// ---------------------------------------------------------------------------
// Callable: submit weekly check-in (the core "Pulse" action)
// ---------------------------------------------------------------------------
exports.submitCheckin = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');

  const { ratings } = data; // { salary, benefits, work_model, culture, wlb } each 1-5
  const METRICS = ['salary', 'benefits', 'work_model', 'culture', 'wlb'];

  for (const m of METRICS) {
    const v = ratings?.[m];
    if (!Number.isInteger(v) || v < 1 || v > 5) {
      throw new functions.https.HttpsError('invalid-argument', `Invalid rating for ${m}`);
    }
  }

  const userSnap = await db.collection('users').doc(context.auth.uid).get();
  if (!userSnap.exists) throw new functions.https.HttpsError('not-found', 'User profile not found');

  const user = userSnap.data();
  if (!user.bank_id || !user.business_family) {
    throw new functions.https.HttpsError('failed-precondition', 'Complete your profile first');
  }

  const now = new Date();
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth() + 1;

  // ISO week number
  const startOfYear = new Date(Date.UTC(year, 0, 1));
  const weekNumber = Math.ceil(((now - startOfYear) / 86400000 + startOfYear.getUTCDay() + 1) / 7);

  const checkinData = {
    user_hash: user.linkedin_hash,
    bank_id: user.bank_id,
    business_family: user.business_family,
    department_type: user.department_type,
    seniority_level: user.seniority_level,
    year,
    month,
    week_number: weekNumber,
    ratings,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('checkins').add(checkinData);

  // Award credits — may throw 'checkin_too_soon'
  let creditResult;
  try {
    creditResult = await awardCheckinCredits(context.auth.uid);
  } catch (err) {
    if (err.message === 'checkin_too_soon') {
      throw new functions.https.HttpsError('resource-exhausted', 'Already checked in this week');
    }
    throw err;
  }

  // Update aggregations (non-blocking — failure is tolerated; nightly reconcile corrects)
  updateAggregation(db, user.bank_id, checkinData).catch(console.error);

  return { success: true, ...creditResult };
});

// ---------------------------------------------------------------------------
// Callable: query insights (consumes 1 credit or active session)
// ---------------------------------------------------------------------------
exports.queryInsights = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');

  const { bankId, businessFamily, year, month } = data;

  try {
    await authorizeQuery(context.auth.uid, bankId);
  } catch (err) {
    if (err.message === 'insufficient_credits') {
      throw new functions.https.HttpsError('resource-exhausted', 'No credits remaining');
    }
    throw err;
  }

  const result = await getInsights(bankId, businessFamily, year, month);

  if (!result) {
    // Privacy threshold not met — return a generic response (don't reveal entry count)
    return { available: false, reason: 'insufficient_data' };
  }

  return { available: true, ...result };
});

// ---------------------------------------------------------------------------
// Callable: purchase a session (day-pass or bank-unlock)
// In production, validate `paymentRef` against your payment provider first.
// ---------------------------------------------------------------------------
exports.purchaseSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');

  const { sessionType, bankIds = [], paymentRef } = data;

  if (!['day_pass', 'bank_unlock'].includes(sessionType)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid sessionType');
  }
  if (sessionType === 'bank_unlock' && (!bankIds.length)) {
    throw new functions.https.HttpsError('invalid-argument', 'bank_unlock requires at least one bankId');
  }
  if (!paymentRef) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentRef is required');
  }

  const sessionId = await recordMicropayment(context.auth.uid, sessionType, bankIds, paymentRef);
  return { sessionId };
});

// ---------------------------------------------------------------------------
// Callable: map a LinkedIn title (utility — also used during onboarding)
// ---------------------------------------------------------------------------
exports.mapTitle = functions.https.onCall((data) => {
  const { title } = data;
  if (!title) throw new functions.https.HttpsError('invalid-argument', 'title is required');
  return mapTitleToBusinessFamily(title);
});

// ---------------------------------------------------------------------------
// Callable: B2B trend data — reads from SNAPSHOTS, never from live aggregations.
//
// Privacy rationale: live aggregations update on every check-in, enabling a
// differential attack (observer computes new_avg * N - old_avg * (N-1) to
// recover the exact score of the Nth submitter). Snapshots are published only
// when delta_count >= MIN_SNAPSHOT_DELTA (3), making individual scores
// mathematically irrecoverable from consecutive snapshots.
// ---------------------------------------------------------------------------
exports.getBankTrend = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');

  if (!context.auth.token?.b2b_bank_id) {
    throw new functions.https.HttpsError('permission-denied', 'B2B access only');
  }

  const bankId = context.auth.token.b2b_bank_id;
  const { businessFamily, fromYear, fromMonth, toYear, toMonth } = data;

  const trend = await getB2BTrendFromSnapshots(
    bankId, businessFamily, fromYear, fromMonth, toYear, toMonth,
  );
  return { trend };
});

// ---------------------------------------------------------------------------
// HTTP: LinkedIn OAuth callback (called by Flutter via deep-link redirect)
// ---------------------------------------------------------------------------
exports.linkedinCallback = functions
  .runWith({ secrets: linkedinSecrets })
  .https.onRequest(handleLinkedInCallback);

// ---------------------------------------------------------------------------
// Stripe: payment intents + micropayment webhook (secrets via Secret Manager)
// ---------------------------------------------------------------------------
const stripe = require('./src/stripe');
exports.createPaymentIntent = stripe.createPaymentIntent;
exports.confirmPurchase     = stripe.confirmPurchase;
exports.stripeWebhook       = stripe.stripeWebhook;

// ---------------------------------------------------------------------------
// Stripe: subscription lifecycle webhook (invoice.paid, subscription.deleted)
// Uses a separate webhook secret so subscription and micropayment endpoints
// can have independent Stripe webhook registrations.
// ---------------------------------------------------------------------------
exports.stripeSubscriptionWebhook = functions
  .runWith({ secrets: subscriptionSecrets })
  .https.onRequest(handleSubscriptionWebhook);

// ---------------------------------------------------------------------------
// Callable: create Stripe Checkout Session for subscription signup
// ---------------------------------------------------------------------------
exports.createCheckoutSession = functions
  .runWith({ secrets: subscriptionSecrets })
  .https.onCall(createCheckoutSession);

// ---------------------------------------------------------------------------
// Callable: open Stripe Customer Portal for subscription management
// ---------------------------------------------------------------------------
exports.createPortalSession = functions
  .runWith({ secrets: subscriptionSecrets })
  .https.onCall(createPortalSession);

// ---------------------------------------------------------------------------
// Firestore trigger: sync subscription_tier → Firebase Auth custom claim
// Fires whenever a users/{userId} document is updated.
// This is the authoritative source for RBAC in Firestore Rules.
// ---------------------------------------------------------------------------
exports.onUserSubscriptionChanged = functions.firestore
  .document('users/{userId}')
  .onUpdate(syncSubscriptionClaim);

// ---------------------------------------------------------------------------
// Scheduled: nightly aggregation reconciliation — 03:00 UTC
// ---------------------------------------------------------------------------
exports.reconcileAggregationsScheduled = functions.pubsub
  .schedule('0 3 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = now.getUTCMonth() + 1;
    const prevMonth = month === 1 ? 12 : month - 1;
    const prevYear = month === 1 ? year - 1 : year;

    await Promise.all([
      reconcileAggregations(year, month),
      reconcileAggregations(prevYear, prevMonth),
    ]);
    console.log(`Reconciliation complete for ${year}-${month} and ${prevYear}-${prevMonth}`);
  });

// ---------------------------------------------------------------------------
// Scheduled: daily B2B snapshot generation — 04:00 UTC (after reconciliation)
//
// Only publishes a snapshot when delta_count >= 3 new entries exist since the
// last snapshot, preventing differential privacy attacks on B2B trend data.
// ---------------------------------------------------------------------------
exports.generateB2BSnapshotsScheduled = functions.pubsub
  .schedule('0 4 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const { published, skipped } = await generateB2BSnapshots();
    console.log(`B2B snapshots: ${published} published, ${skipped} withheld (delta < 3)`);
  });
