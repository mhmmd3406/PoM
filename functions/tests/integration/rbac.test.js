'use strict';

/**
 * RBAC Integration Tests — Firestore Security Rules
 *
 * Verifies that subscription_tier custom claims correctly gate access to
 * aggregations, sector_aggregations, and b2b_snapshots collections.
 *
 * Run: firebase emulators:exec --only firestore "npm run test:integration"
 */

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { resolve } = require('path');
const { doc, getDoc, setDoc, updateDoc } = require('firebase/firestore');

const RULES_PATH = resolve(__dirname, '../../../firestore/firestore.rules');
const PROJECT_ID = 'pom-rbac-test';

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

function db(uid, claims = {}) {
  return testEnv.authenticatedContext(uid, claims).firestore();
}

function unauthedDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

// Standard aggregation docs for testing
const OVERALL_AGG = {
  bank_id: 'akbank',
  business_family: 'all',
  entry_count: 15,
  averages: { salary: 4.1, benefits: 3.8, work_model: 3.6, culture: 4.0, wlb: 3.7, overall: 3.84 },
};

const FAMILY_AGG = {
  bank_id: 'akbank',
  business_family: 'hq_it',
  entry_count: 10,
  averages: { salary: 4.3, benefits: 3.9, work_model: 4.8, culture: 4.1, wlb: 4.0, overall: 4.22 },
};

const LOW_COUNT_AGG = {
  bank_id: 'akbank',
  business_family: 'risk_compliance',
  entry_count: 4, // below N<7
  averages: { salary: 4.0, benefits: 4.0, work_model: 4.0, culture: 4.0, wlb: 3.0, overall: 3.8 },
};

const B2B_SNAPSHOT = {
  bank_id: 'akbank',
  business_family: 'hq_it',
  entry_count: 10,
  averages: { salary: 4.3, benefits: 3.9, work_model: 4.8, culture: 4.1, wlb: 4.0, overall: 4.22 },
};

// ── 1. Unauthenticated access ──────────────────────────────────────────────

describe('Unauthenticated user', () => {
  it('cannot read aggregations', async () => {
    await seed('aggregations/akbank_all_2026_05', OVERALL_AGG);
    await assertFails(getDoc(doc(unauthedDb(), 'aggregations/akbank_all_2026_05')));
  });

  it('cannot read b2b_snapshots', async () => {
    await seed('b2b_snapshots/akbank_hq_it_2026_05', B2B_SNAPSHOT);
    await assertFails(getDoc(doc(unauthedDb(), 'b2b_snapshots/akbank_hq_it_2026_05')));
  });
});

// ── 2. Free tier ───────────────────────────────────────────────────────────

describe('Free tier user', () => {
  const FREE = { uid: 'free_user', claims: { subscription_tier: 'free' } };

  it('CAN read overall aggregation (business_family = "all")', async () => {
    await seed('aggregations/akbank_all_2026_05', OVERALL_AGG);
    await assertSucceeds(
      getDoc(doc(db(FREE.uid, FREE.claims), 'aggregations/akbank_all_2026_05')),
    );
  });

  it('CANNOT read family-level aggregation', async () => {
    await seed('aggregations/akbank_hq_it_2026_05', FAMILY_AGG);
    await assertFails(
      getDoc(doc(db(FREE.uid, FREE.claims), 'aggregations/akbank_hq_it_2026_05')),
    );
  });

  it('CANNOT read sector_aggregations with family breakdown', async () => {
    await seed('sector_aggregations/SECTOR_hq_it_2026_05', { ...FAMILY_AGG, bank_id: null });
    await assertFails(
      getDoc(doc(db(FREE.uid, FREE.claims), 'sector_aggregations/SECTOR_hq_it_2026_05')),
    );
  });

  it('CAN read sector_aggregations overall (business_family = "all")', async () => {
    await seed('sector_aggregations/SECTOR_all_2026_05', { ...OVERALL_AGG, bank_id: null });
    await assertSucceeds(
      getDoc(doc(db(FREE.uid, FREE.claims), 'sector_aggregations/SECTOR_all_2026_05')),
    );
  });

  it('CANNOT read b2b_snapshots', async () => {
    await seed('b2b_snapshots/akbank_hq_it_2026_05', B2B_SNAPSHOT);
    await assertFails(
      getDoc(doc(db(FREE.uid, FREE.claims), 'b2b_snapshots/akbank_hq_it_2026_05')),
    );
  });

  it('CANNOT read aggregation below N<7 threshold', async () => {
    await seed('aggregations/akbank_risk_compliance_2026_05', LOW_COUNT_AGG);
    await assertFails(
      getDoc(doc(db(FREE.uid, FREE.claims), 'aggregations/akbank_risk_compliance_2026_05')),
    );
  });
});

// ── 3. Pro tier ────────────────────────────────────────────────────────────

describe('Pro tier user', () => {
  const PRO = { uid: 'pro_user', claims: { subscription_tier: 'pro' } };

  it('CAN read family-level aggregation', async () => {
    await seed('aggregations/akbank_hq_it_2026_05', FAMILY_AGG);
    await assertSucceeds(
      getDoc(doc(db(PRO.uid, PRO.claims), 'aggregations/akbank_hq_it_2026_05')),
    );
  });

  it('CAN read sector family breakdown', async () => {
    await seed('sector_aggregations/SECTOR_hq_it_2026_05', { ...FAMILY_AGG, bank_id: null });
    await assertSucceeds(
      getDoc(doc(db(PRO.uid, PRO.claims), 'sector_aggregations/SECTOR_hq_it_2026_05')),
    );
  });

  it('CANNOT read b2b_snapshots (enterprise required)', async () => {
    await seed('b2b_snapshots/akbank_hq_it_2026_05', B2B_SNAPSHOT);
    await assertFails(
      getDoc(
        doc(
          db(PRO.uid, { ...PRO.claims, b2b_bank_id: 'akbank' }),
          'b2b_snapshots/akbank_hq_it_2026_05',
        ),
      ),
    );
  });

  it('CANNOT read aggregation below N<7', async () => {
    await seed('aggregations/akbank_risk_compliance_2026_05', LOW_COUNT_AGG);
    await assertFails(
      getDoc(doc(db(PRO.uid, PRO.claims), 'aggregations/akbank_risk_compliance_2026_05')),
    );
  });
});

// ── 4. Enterprise tier ─────────────────────────────────────────────────────

describe('Enterprise tier B2B user', () => {
  const ENT = {
    uid: 'ent_user',
    claims: { subscription_tier: 'enterprise', b2b_bank_id: 'akbank' },
  };

  it('CAN read b2b_snapshots for own bank', async () => {
    await seed('b2b_snapshots/akbank_hq_it_2026_05', B2B_SNAPSHOT);
    await assertSucceeds(
      getDoc(doc(db(ENT.uid, ENT.claims), 'b2b_snapshots/akbank_hq_it_2026_05')),
    );
  });

  it('CANNOT read b2b_snapshots for a different bank', async () => {
    await seed('b2b_snapshots/garanti_hq_it_2026_05', { ...B2B_SNAPSHOT, bank_id: 'garanti_bbva' });
    await assertFails(
      getDoc(doc(db(ENT.uid, ENT.claims), 'b2b_snapshots/garanti_hq_it_2026_05')),
    );
  });

  it('CAN read all aggregation breakdowns', async () => {
    await seed('aggregations/akbank_hq_it_2026_05', FAMILY_AGG);
    await assertSucceeds(
      getDoc(doc(db(ENT.uid, ENT.claims), 'aggregations/akbank_hq_it_2026_05')),
    );
  });
});

// ── 5. DaaS tier ───────────────────────────────────────────────────────────

describe('DaaS tier user', () => {
  const DAAS = {
    uid: 'daas_user',
    claims: { subscription_tier: 'daas', b2b_bank_id: 'akbank' },
  };

  it('CAN read b2b_snapshots for own bank', async () => {
    await seed('b2b_snapshots/akbank_hq_it_2026_05', B2B_SNAPSHOT);
    await assertSucceeds(
      getDoc(doc(db(DAAS.uid, DAAS.claims), 'b2b_snapshots/akbank_hq_it_2026_05')),
    );
  });
});

// ── 6. User document protection ────────────────────────────────────────────

describe('User document RBAC field protection', () => {
  const USER_ID = 'test_user_123';
  const USER_DOC = {
    linkedin_hash: 'abc123',
    bank_id: 'akbank',
    credits: 5,
    subscription_tier: 'free',
    joined_at: new Date(),
  };

  beforeEach(async () => {
    await seed(`users/${USER_ID}`, USER_DOC);
  });

  it('user can update their own non-protected fields', async () => {
    // bank_id is a mutable profile field
    await assertSucceeds(
      updateDoc(doc(db(USER_ID), `users/${USER_ID}`), { bank_id: 'garanti_bbva' }),
    );
  });

  it('user CANNOT update subscription_tier directly', async () => {
    await assertFails(
      updateDoc(doc(db(USER_ID), `users/${USER_ID}`), { subscription_tier: 'enterprise' }),
    );
  });

  it('user CANNOT update credits directly', async () => {
    await assertFails(
      updateDoc(doc(db(USER_ID), `users/${USER_ID}`), { credits: 999 }),
    );
  });

  it('user CANNOT update linkedin_hash', async () => {
    await assertFails(
      updateDoc(doc(db(USER_ID), `users/${USER_ID}`), { linkedin_hash: 'hacked' }),
    );
  });

  it('different user CANNOT read another user document', async () => {
    await assertFails(
      getDoc(doc(db('other_user_456'), `users/${USER_ID}`)),
    );
  });
});
