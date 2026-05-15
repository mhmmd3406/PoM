#!/usr/bin/env node
/**
 * One-time setup: writes default platform_config documents to Firestore.
 * Run against the emulator:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/init_platform_config.js
 * Run against production (with credentials):
 *   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccount.json node scripts/init_platform_config.js
 */
'use strict';

const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'pom-dev';
admin.initializeApp({ projectId });
const db = admin.firestore();

async function run() {
  const now = admin.firestore.FieldValue.serverTimestamp();

  await db.doc('platform_config/thresholds').set({
    company_privacy_threshold:    15,
    department_privacy_threshold: 10,
    min_company_employees:        200,
    checkin_cooldown_days:        7,
    max_head_to_head_competitors: 3,
    retention_risk_max_months:    12,
    updated_at: now,
    updated_by: 'init_script',
  });

  await db.doc('platform_config/legal_texts').set({
    kvkk_version:          '',
    kvkk_text:             '',
    privacy_policy_version:'',
    privacy_policy_text:   '',
    terms_of_service_version: '',
    terms_of_service_text:    '',
    community_rules_version:  '',
    community_rules_text:     '',
    fraud_policy_version:     '',
    fraud_policy_text:        '',
    updated_at: now,
    updated_by: 'init_script',
  });

  await db.doc('platform_config/feature_flags').set({
    head_to_head_enabled:    true,
    retention_risk_enabled:  true,
    maintenance_mode:        false,
    maintenance_message:     '',
    updated_at: now,
    updated_by: 'init_script',
  });

  console.log('✓ platform_config documents initialized');
  process.exit(0);
}

run().catch(err => { console.error(err); process.exit(1); });
