'use strict';

/**
 * Firestore security rules integration tests.
 * Run against the local Firestore Emulator — requires Java 11+.
 *
 * Start manually:  firebase emulators:start --only firestore
 * Run via CI:      firebase emulators:exec --only firestore "npm run test:integration"
 */

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { resolve } = require('path');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  addDoc,
  collection,
  serverTimestamp,
} = require('firebase/firestore');

const RULES_PATH = resolve(__dirname, '../../../firestore/firestore.rules');
const PROJECT_ID = 'pom-test';

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
}, 20_000);

afterAll(() => testEnv?.cleanup());

afterEach(() => testEnv?.clearFirestore());

// ── Helpers ────────────────────────────────────────────────────────────────

function authedDb(uid, claims = {}) {
  return testEnv.authenticatedContext(uid, claims).firestore();
}

function unauthedDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seedDoc(collectionPath, docId, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), collectionPath, docId), data);
  });
}

const validCheckin = {
  user_hash: 'abc123hash',
  bank_id: 'test-bank',
  business_family: 'IT',
  department_type: 'all',
  seniority_level: 'mid',
  year: 2024,
  month: 11,
  week_number: 45,
  ratings: { salary: 4, benefits: 3, work_model: 5, culture: 4, wlb: 3 },
  created_at: new Date(),
};

// ── users ──────────────────────────────────────────────────────────────────

describe('users collection', () => {
  test('unauthenticated cannot read', async () => {
    await seedDoc('users', 'uid1', { credits: 3, linkedin_hash: 'hash', joined_at: new Date() });
    await assertFails(getDoc(doc(unauthedDb(), 'users', 'uid1')));
  });

  test('user can read own document', async () => {
    await seedDoc('users', 'uid1', { credits: 3, linkedin_hash: 'hash', joined_at: new Date() });
    await assertSucceeds(getDoc(doc(authedDb('uid1'), 'users', 'uid1')));
  });

  test('user cannot read another user document', async () => {
    await seedDoc('users', 'uid2', { credits: 3, linkedin_hash: 'hash', joined_at: new Date() });
    await assertFails(getDoc(doc(authedDb('uid1'), 'users', 'uid2')));
  });

  test('user cannot create own document directly', async () => {
    await assertFails(
      setDoc(doc(authedDb('uid1'), 'users', 'uid1'), {
        credits: 3, linkedin_hash: 'hash', joined_at: new Date(),
      }),
    );
  });

  test('user cannot modify credits field', async () => {
    await seedDoc('users', 'uid1', {
      credits: 3, linkedin_hash: 'hash', joined_at: new Date(),
      bank_id: null, business_family: null,
    });
    await assertFails(
      updateDoc(doc(authedDb('uid1'), 'users', 'uid1'), { credits: 999 }),
    );
  });

  test('user cannot modify linkedin_hash', async () => {
    await seedDoc('users', 'uid1', {
      credits: 3, linkedin_hash: 'original', joined_at: new Date(),
    });
    await assertFails(
      updateDoc(doc(authedDb('uid1'), 'users', 'uid1'), { linkedin_hash: 'tampered' }),
    );
  });

  test('user can update non-protected fields (bank_id)', async () => {
    await seedDoc('users', 'uid1', {
      credits: 3, linkedin_hash: 'hash', joined_at: new Date(),
      bank_id: null, business_family: null, department_type: null, seniority_level: null,
    });
    await assertSucceeds(
      updateDoc(doc(authedDb('uid1'), 'users', 'uid1'), { bank_id: 'new-bank' }),
    );
  });
});

// ── checkins ───────────────────────────────────────────────────────────────

describe('checkins collection', () => {
  test('nobody can read checkins', async () => {
    await seedDoc('checkins', 'ci1', validCheckin);
    await assertFails(getDoc(doc(authedDb('uid1'), 'checkins', 'ci1')));
    await assertFails(getDoc(doc(unauthedDb(), 'checkins', 'ci1')));
  });

  test('authenticated user can create a valid checkin', async () => {
    await assertSucceeds(
      addDoc(collection(authedDb('uid1'), 'checkins'), validCheckin),
    );
  });

  test('unauthenticated cannot create checkin', async () => {
    await assertFails(
      addDoc(collection(unauthedDb(), 'checkins'), validCheckin),
    );
  });

  test('checkin with out-of-range rating (0) is rejected', async () => {
    await assertFails(
      addDoc(collection(authedDb('uid1'), 'checkins'), {
        ...validCheckin,
        ratings: { ...validCheckin.ratings, salary: 0 },
      }),
    );
  });

  test('checkin with out-of-range rating (6) is rejected', async () => {
    await assertFails(
      addDoc(collection(authedDb('uid1'), 'checkins'), {
        ...validCheckin,
        ratings: { ...validCheckin.ratings, wlb: 6 },
      }),
    );
  });

  test('checkin missing required field is rejected', async () => {
    const { user_hash: _removed, ...incomplete } = validCheckin;
    await assertFails(
      addDoc(collection(authedDb('uid1'), 'checkins'), incomplete),
    );
  });

  test('checkin with invalid month (13) is rejected', async () => {
    await assertFails(
      addDoc(collection(authedDb('uid1'), 'checkins'), { ...validCheckin, month: 13 }),
    );
  });
});

// ── aggregations (N<7 privacy gate) ───────────────────────────────────────

describe('aggregations — privacy threshold', () => {
  test('N >= 7 allows authenticated read', async () => {
    await seedDoc('aggregations', 'bank1_IT_2024_11', {
      entry_count: 7, averages: { overall: 4.0 },
    });
    await assertSucceeds(
      getDoc(doc(authedDb('uid1'), 'aggregations', 'bank1_IT_2024_11')),
    );
  });

  test('N < 7 blocks read (privacy gate)', async () => {
    await seedDoc('aggregations', 'bank1_IT_2024_11', {
      entry_count: 6, averages: { overall: 4.0 },
    });
    await assertFails(
      getDoc(doc(authedDb('uid1'), 'aggregations', 'bank1_IT_2024_11')),
    );
  });

  test('N = 0 blocks read', async () => {
    await seedDoc('aggregations', 'bank1_IT_2024_11', { entry_count: 0 });
    await assertFails(
      getDoc(doc(authedDb('uid1'), 'aggregations', 'bank1_IT_2024_11')),
    );
  });

  test('unauthenticated cannot read even with N >= 7', async () => {
    await seedDoc('aggregations', 'bank1_IT_2024_11', { entry_count: 100 });
    await assertFails(
      getDoc(doc(unauthedDb(), 'aggregations', 'bank1_IT_2024_11')),
    );
  });

  test('nobody can write aggregations', async () => {
    await assertFails(
      setDoc(doc(authedDb('uid1'), 'aggregations', 'tampered'), { entry_count: 999 }),
    );
  });
});

// ── sector_aggregations (same N<7 rule) ────────────────────────────────────

describe('sector_aggregations — privacy threshold', () => {
  test('N >= 7 allows read', async () => {
    await seedDoc('sector_aggregations', 'SECTOR_all_2024_11', { entry_count: 10 });
    await assertSucceeds(
      getDoc(doc(authedDb('uid1'), 'sector_aggregations', 'SECTOR_all_2024_11')),
    );
  });

  test('N = 6 blocks read', async () => {
    await seedDoc('sector_aggregations', 'SECTOR_all_2024_11', { entry_count: 6 });
    await assertFails(
      getDoc(doc(authedDb('uid1'), 'sector_aggregations', 'SECTOR_all_2024_11')),
    );
  });
});

// ── b2b_snapshots ──────────────────────────────────────────────────────────

describe('b2b_snapshots — bank-scoped access', () => {
  beforeEach(async () => {
    await seedDoc('b2b_snapshots', 'bank1_all_2024_11', {
      bank_id: 'bank1', business_family: 'all', entry_count: 20, averages: {},
    });
  });

  test('unauthenticated cannot read', async () => {
    await assertFails(
      getDoc(doc(unauthedDb(), 'b2b_snapshots', 'bank1_all_2024_11')),
    );
  });

  test('regular user without b2b_bank_id claim cannot read', async () => {
    await assertFails(
      getDoc(doc(authedDb('uid1'), 'b2b_snapshots', 'bank1_all_2024_11')),
    );
  });

  test('B2B user for a different bank cannot read', async () => {
    await assertFails(
      getDoc(
        doc(authedDb('b2b-uid', { b2b_bank_id: 'bank2' }), 'b2b_snapshots', 'bank1_all_2024_11'),
      ),
    );
  });

  test('B2B user for the correct bank can read', async () => {
    await assertSucceeds(
      getDoc(
        doc(authedDb('b2b-uid', { b2b_bank_id: 'bank1' }), 'b2b_snapshots', 'bank1_all_2024_11'),
      ),
    );
  });

  test('nobody can write b2b_snapshots', async () => {
    await assertFails(
      setDoc(
        doc(authedDb('b2b-uid', { b2b_bank_id: 'bank1' }), 'b2b_snapshots', 'injected'),
        { bank_id: 'bank1', averages: {} },
      ),
    );
  });
});

// ── b2b_snapshots_archive ──────────────────────────────────────────────────

describe('b2b_snapshots_archive — fully locked', () => {
  test('nobody can read archive', async () => {
    await seedDoc('b2b_snapshots_archive', 'archive1', { bank_id: 'bank1' });
    await assertFails(
      getDoc(doc(authedDb('b2b-uid', { b2b_bank_id: 'bank1' }), 'b2b_snapshots_archive', 'archive1')),
    );
    await assertFails(
      getDoc(doc(unauthedDb(), 'b2b_snapshots_archive', 'archive1')),
    );
  });
});

// ── credit_transactions ────────────────────────────────────────────────────

describe('credit_transactions', () => {
  test('user can read own transactions', async () => {
    await seedDoc('credit_transactions', 'txn1', { user_id: 'uid1', amount: 3 });
    await assertSucceeds(
      getDoc(doc(authedDb('uid1'), 'credit_transactions', 'txn1')),
    );
  });

  test('user cannot read another user transactions', async () => {
    await seedDoc('credit_transactions', 'txn1', { user_id: 'uid2', amount: 3 });
    await assertFails(
      getDoc(doc(authedDb('uid1'), 'credit_transactions', 'txn1')),
    );
  });

  test('nobody can write credit_transactions directly', async () => {
    await assertFails(
      setDoc(doc(authedDb('uid1'), 'credit_transactions', 'fake-txn'), {
        user_id: 'uid1', amount: 1000,
      }),
    );
  });
});
