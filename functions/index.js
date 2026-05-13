'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const { mapTitleToBusinessFamily } = require('./src/titleMapper');
const { grantSignupBonus, awardCheckinCredits, authorizeQuery, recordMicropayment } = require('./src/credits');
const { updateAggregation, reconcileAggregations, getInsights, getTrendData } = require('./src/aggregations');

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Auth: on user creation via LinkedIn OAuth
// Hashes the LinkedIn UID and creates the user document.
// ---------------------------------------------------------------------------
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
  const crypto = require('crypto');
  const salt = process.env.LINKEDIN_ID_SALT;
  if (!salt) throw new functions.https.HttpsError('internal', 'Salt not configured');

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
// Callable: B2B trend data (restricted to authenticated bank portal users)
// ---------------------------------------------------------------------------
exports.getBankTrend = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');

  // B2B callers must have a custom claim set server-side during B2B onboarding
  if (!context.auth.token?.b2b_bank_id) {
    throw new functions.https.HttpsError('permission-denied', 'B2B access only');
  }

  const bankId = context.auth.token.b2b_bank_id;
  const { businessFamily, fromYear, fromMonth, toYear, toMonth } = data;

  const trend = await getTrendData(bankId, businessFamily, fromYear, fromMonth, toYear, toMonth);
  return { trend };
});

// ---------------------------------------------------------------------------
// Scheduled: nightly aggregation reconciliation (Cloud Scheduler cron)
// ---------------------------------------------------------------------------
exports.reconcileAggregationsScheduled = functions.pubsub
  .schedule('0 3 * * *') // 03:00 UTC daily
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = now.getUTCMonth() + 1;
    // Reconcile current month and previous month (covers month boundaries)
    const prevMonth = month === 1 ? 12 : month - 1;
    const prevYear = month === 1 ? year - 1 : year;

    await Promise.all([
      reconcileAggregations(year, month),
      reconcileAggregations(prevYear, prevMonth),
    ]);
    console.log(`Reconciliation complete for ${year}-${month} and ${prevYear}-${prevMonth}`);
  });
