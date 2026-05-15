'use strict';

const admin = require('firebase-admin');
const { getThresholds } = require('./platformConfig');

const CREDITS = {
  SIGNUP_BONUS: 3,
  WEEKLY_CHECKIN: 2,
  QUERY_COST: 1,
};

/**
 * Atomically award credits and record the transaction.
 * Uses a Firestore transaction to guarantee balance consistency.
 */
async function awardCredits(userId, type, amount, metadata = {}) {
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);
  const txnRef = db.collection('credit_transactions').doc();

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) throw new Error(`User ${userId} not found`);

    const currentBalance = userSnap.data().credits || 0;
    const balanceAfter = currentBalance + amount;
    if (balanceAfter < 0) throw new Error('insufficient_credits');

    tx.update(userRef, { credits: admin.firestore.FieldValue.increment(amount) });
    tx.set(txnRef, {
      user_id: userId,
      type,
      amount,
      balance_after: balanceAfter,
      metadata,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

/**
 * Grant signup bonus (idempotent — checks existing transaction).
 */
async function grantSignupBonus(userId) {
  const db = admin.firestore();
  const existing = await db
    .collection('credit_transactions')
    .where('user_id', '==', userId)
    .where('type', '==', 'signup_bonus')
    .limit(1)
    .get();

  if (!existing.empty) return; // already granted
  await awardCredits(userId, 'signup_bonus', CREDITS.SIGNUP_BONUS);
}

/**
 * Award weekly check-in credits.
 * Enforces: max one award per calendar week (ISO week).
 */
async function awardCheckinCredits(userId) {
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);
  const userSnap = await userRef.get();

  if (!userSnap.exists) throw new Error(`User ${userId} not found`);

  const lastCheckin = userSnap.data().last_checkin_at?.toDate();
  const now = new Date();

  const cfg = await getThresholds().catch(() => ({ checkinCooldownDays: 7 }));
  const cooldownMs = cfg.checkinCooldownDays * 24 * 60 * 60 * 1000;

  if (lastCheckin && now - lastCheckin < cooldownMs) {
    throw new Error('checkin_too_soon');
  }

  await awardCredits(userId, 'weekly_checkin', CREDITS.WEEKLY_CHECKIN);

  // Update last_checkin_at and streak
  const newStreak = lastCheckin && now - lastCheckin < 2 * cooldownMs
    ? (userSnap.data().checkin_streak || 0) + 1
    : 1;

  await userRef.update({
    last_checkin_at: admin.firestore.FieldValue.serverTimestamp(),
    checkin_streak: newStreak,
  });

  return { creditsAwarded: CREDITS.WEEKLY_CHECKIN, newStreak };
}

/**
 * Deduct one credit for a query (or validate active session).
 * Returns true if access is granted.
 */
async function authorizeQuery(userId, bankId) {
  const db = admin.firestore();

  // Check for an active session (day-pass or bank-unlock)
  const sessionSnap = await db
    .collection('query_sessions')
    .where('user_id', '==', userId)
    .where('expires_at', '>', admin.firestore.Timestamp.now())
    .limit(5)
    .get();

  for (const doc of sessionSnap.docs) {
    const { type, bank_ids } = doc.data();
    if (type === 'day_pass') return true; // blanket access
    if (type === 'bank_unlock' && bank_ids.includes(bankId)) return true;
  }

  // Fall back to per-query credit
  await awardCredits(userId, 'query_used', -CREDITS.QUERY_COST, { bank_id: bankId });
  return true;
}

/**
 * Record a micro-payment and grant a query session.
 * `sessionType`: "day_pass" | "bank_unlock"
 * `bankIds`: string[] (required for bank_unlock, empty for day_pass)
 */
async function recordMicropayment(userId, sessionType, bankIds = [], paymentRef) {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + (sessionType === 'day_pass' ? 24 * 60 * 60 * 1000 : 30 * 24 * 60 * 60 * 1000),
  );

  const batch = db.batch();

  const sessionRef = db.collection('query_sessions').doc();
  batch.set(sessionRef, {
    user_id: userId,
    type: sessionType,
    bank_ids: bankIds,
    expires_at: expiresAt,
    created_at: now,
  });

  const txnRef = db.collection('credit_transactions').doc();
  batch.set(txnRef, {
    user_id: userId,
    type: sessionType,
    amount: 0, // paid externally — no credit movement
    balance_after: null,
    metadata: { payment_ref: paymentRef, bank_ids: bankIds },
    created_at: now,
  });

  await batch.commit();
  return sessionRef.id;
}

module.exports = {
  CREDITS,
  grantSignupBonus,
  awardCheckinCredits,
  authorizeQuery,
  recordMicropayment,
};
