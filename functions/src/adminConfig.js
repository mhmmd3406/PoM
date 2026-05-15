'use strict';

const admin    = require('firebase-admin');
const functions = require('firebase-functions');
const { invalidateCache } = require('./platformConfig');

// ── Auth guard ────────────────────────────────────────────────────────────────

function requireAdmin(context) {
  if (!context.auth)
    throw new functions.https.HttpsError('unauthenticated', 'unauthenticated');
  if (!context.auth.token.is_admin)
    throw new functions.https.HttpsError('permission-denied', 'admin_only');
}

function ts() {
  return admin.firestore.FieldValue.serverTimestamp();
}

// ── Thresholds ────────────────────────────────────────────────────────────────

exports.adminUpdateThresholds = functions.https.onCall(async (data, context) => {
  requireAdmin(context);

  const {
    company_privacy_threshold,
    department_privacy_threshold,
    min_company_employees,
    checkin_cooldown_days,
    max_head_to_head_competitors,
    retention_risk_max_months,
  } = data;

  // Safety floors — even admins cannot break privacy guarantees
  if (company_privacy_threshold    !== undefined && company_privacy_threshold    < 7)
    throw new functions.https.HttpsError('invalid-argument', 'company_threshold_minimum_7');
  if (department_privacy_threshold !== undefined && department_privacy_threshold < 5)
    throw new functions.https.HttpsError('invalid-argument', 'department_threshold_minimum_5');
  if (min_company_employees        !== undefined && min_company_employees        < 0)
    throw new functions.https.HttpsError('invalid-argument', 'min_employees_non_negative');

  const update = { updated_at: ts(), updated_by: context.auth.uid };
  if (company_privacy_threshold    !== undefined) update.company_privacy_threshold    = company_privacy_threshold;
  if (department_privacy_threshold !== undefined) update.department_privacy_threshold = department_privacy_threshold;
  if (min_company_employees        !== undefined) update.min_company_employees        = min_company_employees;
  if (checkin_cooldown_days        !== undefined) update.checkin_cooldown_days        = Math.max(1, checkin_cooldown_days);
  if (max_head_to_head_competitors !== undefined) update.max_head_to_head_competitors = Math.min(10, Math.max(1, max_head_to_head_competitors));
  if (retention_risk_max_months    !== undefined) update.retention_risk_max_months    = Math.min(24, Math.max(2, retention_risk_max_months));

  await admin.firestore().doc('platform_config/thresholds').set(update, { merge: true });
  invalidateCache('platform_config/thresholds');
  return { success: true };
});

// ── Legal texts ───────────────────────────────────────────────────────────────

exports.adminUpdateLegalText = functions.https.onCall(async (data, context) => {
  requireAdmin(context);

  const { key, text, version } = data;
  const allowed = ['kvkk', 'privacy_policy', 'terms_of_service', 'community_rules', 'fraud_policy'];
  if (!allowed.includes(key))
    throw new functions.https.HttpsError('invalid-argument', 'invalid_legal_key');
  if (typeof text !== 'string' || text.trim().length < 10)
    throw new functions.https.HttpsError('invalid-argument', 'text_too_short');

  const update = {
    [`${key}_text`]:       text.trim(),
    [`${key}_version`]:    version || `${Date.now()}`,
    [`${key}_updated_at`]: ts(),
    updated_by: context.auth.uid,
  };

  await admin.firestore().doc('platform_config/legal_texts').set(update, { merge: true });
  invalidateCache('platform_config/legal_texts');
  return { success: true };
});

// ── Feature flags ─────────────────────────────────────────────────────────────

exports.adminUpdateFeatureFlags = functions.https.onCall(async (data, context) => {
  requireAdmin(context);

  const allowed = [
    'head_to_head_enabled', 'retention_risk_enabled',
    'maintenance_mode', 'maintenance_message',
  ];

  const update = { updated_at: ts(), updated_by: context.auth.uid };
  for (const key of allowed) {
    if (data[key] !== undefined) update[key] = data[key];
  }

  await admin.firestore().doc('platform_config/feature_flags').set(update, { merge: true });
  invalidateCache('platform_config/feature_flags');
  return { success: true };
});

// ── Bank management ───────────────────────────────────────────────────────────

exports.adminUpsertBank = functions.https.onCall(async (data, context) => {
  requireAdmin(context);

  const { bank_id, display_name, employee_count, is_active, logo_url } = data;
  if (!bank_id || typeof bank_id !== 'string')
    throw new functions.https.HttpsError('invalid-argument', 'bank_id_required');

  const update = { updated_at: ts(), updated_by: context.auth.uid };
  if (display_name    !== undefined) update.display_name    = display_name;
  if (employee_count  !== undefined) update.employee_count  = Math.max(0, employee_count);
  if (is_active       !== undefined) update.is_active       = Boolean(is_active);
  if (logo_url        !== undefined) update.logo_url        = logo_url;

  await admin.firestore().collection('banks').doc(bank_id).set(update, { merge: true });
  return { success: true };
});

// ── Dispute management ────────────────────────────────────────────────────────

exports.adminResolveDispute = functions.https.onCall(async (data, context) => {
  requireAdmin(context);

  const { dispute_id, status, admin_note } = data;
  const allowed = ['under_review', 'resolved', 'rejected'];
  if (!allowed.includes(status))
    throw new functions.https.HttpsError('invalid-argument', 'invalid_status');

  await admin.firestore().collection('disputes').doc(dispute_id).update({
    status,
    admin_note: admin_note || '',
    resolved_at: ts(),
    resolved_by: context.auth.uid,
  });
  return { success: true };
});

// ── Company dispute submission (callable by B2B users) ────────────────────────

exports.submitDispute = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'unauthenticated');
  if (!context.auth.token.b2b_bank_id)
    throw new functions.https.HttpsError('permission-denied', 'b2b_only');

  const { reason, category, description } = data;
  const allowed = ['methodology', 'data_accuracy', 'manipulation_suspicion', 'other'];
  if (!allowed.includes(category))
    throw new functions.https.HttpsError('invalid-argument', 'invalid_category');
  if (!description || description.trim().length < 20)
    throw new functions.https.HttpsError('invalid-argument', 'description_too_short');

  await admin.firestore().collection('disputes').add({
    bank_id:     context.auth.token.b2b_bank_id,
    submitted_by: context.auth.uid,
    reason:      reason || '',
    category,
    description: description.trim(),
    status:      'pending',
    submitted_at: ts(),
    admin_note:  '',
  });

  return { success: true };
});

// ── Account deletion (callable by any authenticated user — KVKK / GDPR) ───────

exports.deleteAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'unauthenticated');

  const userId = context.auth.uid;
  const db = admin.firestore();

  // 1. Anonymise checkins — replace user_hash with a tombstone marker
  const checkinSnap = await db.collection('checkins').where('user_id', '==', userId).get();
  const batch = db.batch();
  for (const doc of checkinSnap.docs) {
    batch.update(doc.ref, { user_id: '__deleted__', user_hash: '__deleted__' });
  }

  // 2. Delete credit_transactions (financial history not needed post-deletion)
  const txnSnap = await db.collection('credit_transactions').where('user_id', '==', userId).get();
  for (const doc of txnSnap.docs) batch.delete(doc.ref);

  // 3. Delete query_sessions
  const sessSnap = await db.collection('query_sessions').where('user_id', '==', userId).get();
  for (const doc of sessSnap.docs) batch.delete(doc.ref);

  // 4. Delete user document
  batch.delete(db.collection('users').doc(userId));

  await batch.commit();

  // 5. Delete Firebase Auth account
  await admin.auth().deleteUser(userId);

  return { success: true };
});

// ── Announcement management ───────────────────────────────────────────────────

exports.adminPublishAnnouncement = functions.https.onCall(async (data, context) => {
  requireAdmin(context);

  const { title, body, target_tier, expires_at } = data;
  if (!title || !body)
    throw new functions.https.HttpsError('invalid-argument', 'title_and_body_required');

  await admin.firestore().collection('announcements').add({
    title:       title.trim(),
    body:        body.trim(),
    target_tier: target_tier || 'all',
    is_active:   true,
    published_at: ts(),
    expires_at:  expires_at ? admin.firestore.Timestamp.fromMillis(expires_at) : null,
    created_by:  context.auth.uid,
  });
  return { success: true };
});

exports.adminToggleAnnouncement = functions.https.onCall(async (data, context) => {
  requireAdmin(context);
  const { announcement_id, is_active } = data;
  await admin.firestore().collection('announcements').doc(announcement_id).update({
    is_active: Boolean(is_active),
  });
  return { success: true };
});
