#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS first.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.applicationDefault() });

const auth = admin.auth();
const db   = admin.firestore();

const PASSWORD = 'PoM_Test_2025!';

const TEST_USERS = [
  {
    uid:         'test-user-free',
    email:       'test.free@pom.app',
    displayName: 'Test Free',
    role:        'free',
    companyId:   null,
    department:  'Genel',
  },
  {
    uid:         'test-user-pro',
    email:       'test.pro@pom.app',
    displayName: 'Test Pro',
    role:        'pro',
    companyId:   null,
    department:  'Yazılım',
  },
  {
    uid:         'test-user-enterprise',
    email:       'test.enterprise@pom.app',
    displayName: 'Test Enterprise',
    role:        'enterprise',
    companyId:   'company_1',
    department:  'İK',
  },
  {
    uid:         'test-user-daas',
    email:       'test.daas@pom.app',
    displayName: 'Test DaaS',
    role:        'daas',
    companyId:   'company_2',
    department:  'Veri Analiz',
  },
];

async function run() {
  for (const u of TEST_USERS) {
    // Create or update Auth user
    try {
      await auth.createUser({
        uid:          u.uid,
        email:        u.email,
        password:     PASSWORD,
        displayName:  u.displayName,
        emailVerified: true,
      });
      console.log(`Created auth: ${u.email}`);
    } catch (err) {
      if (err.code === 'auth/uid-already-exists' || err.code === 'auth/email-already-exists') {
        await auth.updateUser(u.uid, { password: PASSWORD, displayName: u.displayName });
        console.log(`Updated auth: ${u.email}`);
      } else {
        throw err;
      }
    }

    // Write Firestore user document
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.collection('users').doc(u.uid).set({
      uid:         u.uid,
      email:       u.email,
      displayName: u.displayName,
      role:        u.role,
      companyId:   u.companyId,
      department:  u.department,
      deleted:     false,
      created_at:  now,
      updated_at:  now,
    }, { merge: true });
    console.log(`Firestore doc: ${u.uid} (${u.role})`);
  }

  console.log('\nDone. All test users created.');
  process.exit(0);
}

run().catch(err => { console.error(err); process.exit(1); });
