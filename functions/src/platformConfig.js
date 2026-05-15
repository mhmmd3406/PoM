'use strict';

const admin = require('firebase-admin');

// Simple in-process cache — avoids Firestore read on every function invocation.
// Each Cloud Function instance gets its own cache (warm start reuse).
const _cache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

async function _fetchDoc(docPath) {
  const now = Date.now();
  const cached = _cache.get(docPath);
  if (cached && now - cached.ts < CACHE_TTL_MS) return cached.data;

  const snap = await admin.firestore().doc(docPath).get();
  const data = snap.exists ? snap.data() : {};
  _cache.set(docPath, { data, ts: now });
  return data;
}

/**
 * Returns platform thresholds with safety floors applied.
 * Safety floors are enforced here (not just in admin validation) so that
 * even a direct Firestore write cannot break privacy guarantees.
 */
async function getThresholds() {
  const d = await _fetchDoc('platform_config/thresholds');
  return {
    companyThreshold:    Math.max(7,  d.company_privacy_threshold    ?? 15),
    departmentThreshold: Math.max(5,  d.department_privacy_threshold ?? 10),
    minEmployees:        Math.max(0,  d.min_company_employees        ?? 200),
    checkinCooldownDays: Math.max(1,  d.checkin_cooldown_days        ?? 7),
    maxHeadToHead:       Math.min(10, Math.max(1, d.max_head_to_head_competitors ?? 3)),
    retentionMaxMonths:  Math.min(24, Math.max(2, d.retention_risk_max_months    ?? 12)),
  };
}

async function getLegalTexts() {
  return _fetchDoc('platform_config/legal_texts');
}

async function getFeatureFlags() {
  const d = await _fetchDoc('platform_config/feature_flags');
  return {
    headToHeadEnabled:    d.head_to_head_enabled    ?? true,
    retentionRiskEnabled: d.retention_risk_enabled  ?? true,
    maintenanceMode:      d.maintenance_mode         ?? false,
    maintenanceMessage:   d.maintenance_message      ?? '',
  };
}

/** Call after an admin writes to platform_config to flush the local cache. */
function invalidateCache(docPath) {
  _cache.delete(docPath);
}

module.exports = { getThresholds, getLegalTexts, getFeatureFlags, invalidateCache };
