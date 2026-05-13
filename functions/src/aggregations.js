'use strict';

const admin = require('firebase-admin');

const METRICS = ['salary', 'benefits', 'work_model', 'culture', 'wlb'];
const PRIVACY_THRESHOLD = 7;

/**
 * Builds the aggregation document ID.
 * bank_id = null → sector-wide aggregation
 */
function aggDocId(bankId, businessFamily, year, month) {
  const bankPart = bankId || 'SECTOR';
  return `${bankPart}_${businessFamily}_${year}_${String(month).padStart(2, '0')}`;
}

/**
 * Incrementally updates a running average stored in Firestore.
 * Uses the Welford online algorithm approximation via atomic increment + re-average.
 *
 * For correctness in high-concurrency, the authoritative recount is done
 * by a scheduled nightly reconciliation function (see reconcileAggregations).
 * The real-time path uses a fast-path increment that is eventually consistent.
 */
async function updateAggregation(db, bankId, checkinData) {
  const { business_family, year, month, ratings } = checkinData;

  const targets = [
    { colId: 'aggregations', docId: aggDocId(bankId, business_family, year, month), bankId },
    { colId: 'aggregations', docId: aggDocId(bankId, 'all', year, month), bankId },
    { colId: 'sector_aggregations', docId: aggDocId(null, business_family, year, month), bankId: null },
    { colId: 'sector_aggregations', docId: aggDocId(null, 'all', year, month), bankId: null },
  ];

  const overall =
    METRICS.reduce((sum, m) => sum + (ratings[m] || 0), 0) / METRICS.length;

  const updates = targets.map(async ({ colId, docId, bankId: tBankId }) => {
    const ref = db.collection(colId).doc(docId);

    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);

      if (!snap.exists) {
        const baseAverages = Object.fromEntries(METRICS.map((m) => [m, ratings[m] || 0]));
        baseAverages.overall = overall;

        tx.set(ref, {
          bank_id: tBankId,
          business_family: colId === 'aggregations' ? business_family : business_family,
          department_type: 'all',
          year,
          month,
          entry_count: 1,
          averages: baseAverages,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      const data = snap.data();
      const n = data.entry_count;
      const newN = n + 1;

      // Incremental mean: newAvg = (oldAvg * n + newValue) / (n + 1)
      const newAverages = {};
      for (const m of METRICS) {
        newAverages[m] = ((data.averages[m] || 0) * n + (ratings[m] || 0)) / newN;
      }
      newAverages.overall = ((data.averages.overall || 0) * n + overall) / newN;

      tx.update(ref, {
        entry_count: newN,
        averages: newAverages,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  });

  await Promise.all(updates);
}

/**
 * Nightly reconciliation: recomputes aggregations from raw checkins.
 * Corrects any incremental drift. Triggered by Cloud Scheduler.
 */
async function reconcileAggregations(year, month) {
  const db = admin.firestore();

  const checkinsSnap = await db
    .collection('checkins')
    .where('year', '==', year)
    .where('month', '==', month)
    .get();

  // Group by bank × family
  const groups = {};

  for (const doc of checkinsSnap.docs) {
    const d = doc.data();
    const keys = [
      `${d.bank_id}|${d.business_family}`,
      `${d.bank_id}|all`,
      `SECTOR|${d.business_family}`,
      `SECTOR|all`,
    ];

    for (const key of keys) {
      if (!groups[key]) groups[key] = [];
      groups[key].push(d.ratings);
    }
  }

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const [key, ratingsList] of Object.entries(groups)) {
    const [bankPart, familyPart] = key.split('|');
    const isBank = bankPart !== 'SECTOR';
    const colId = isBank ? 'aggregations' : 'sector_aggregations';
    const docId = `${bankPart}_${familyPart}_${year}_${String(month).padStart(2, '0')}`;
    const ref = db.collection(colId).doc(docId);

    const n = ratingsList.length;
    const averages = Object.fromEntries(
      METRICS.map((m) => [m, ratingsList.reduce((s, r) => s + (r[m] || 0), 0) / n]),
    );
    averages.overall = METRICS.reduce((s, m) => s + averages[m], 0) / METRICS.length;

    batch.set(
      ref,
      {
        bank_id: isBank ? bankPart : null,
        business_family: familyPart,
        department_type: 'all',
        year,
        month,
        entry_count: n,
        averages,
        updated_at: now,
      },
      { merge: true },
    );
  }

  await batch.commit();
}

/**
 * Fetch insights for a bank+family combination, enforcing the N < 7 rule.
 * Returns null if the privacy threshold is not met.
 */
async function getInsights(bankId, businessFamily, year, month) {
  const db = admin.firestore();
  const docId = aggDocId(bankId, businessFamily || 'all', year, month);
  const snap = await db.collection('aggregations').doc(docId).get();

  if (!snap.exists) return null;

  const data = snap.data();
  if (data.entry_count < PRIVACY_THRESHOLD) return null; // privacy gate

  // Also fetch sector baseline for comparison
  const sectorId = aggDocId(null, businessFamily || 'all', year, month);
  const sectorSnap = await db.collection('sector_aggregations').doc(sectorId).get();

  return {
    bank: {
      averages: data.averages,
      entryCount: data.entry_count,
    },
    sector: sectorSnap.exists && sectorSnap.data().entry_count >= PRIVACY_THRESHOLD
      ? { averages: sectorSnap.data().averages }
      : null,
    period: { year, month },
  };
}

/**
 * Fetch month-over-month trend data for B2B reporting.
 * Returns an array of monthly snapshots, skipping months below threshold.
 */
async function getTrendData(bankId, businessFamily, fromYear, fromMonth, toYear, toMonth) {
  const db = admin.firestore();

  const snaps = await db
    .collection('aggregations')
    .where('bank_id', '==', bankId)
    .where('business_family', '==', businessFamily || 'all')
    .where('year', '>=', fromYear)
    .where('year', '<=', toYear)
    .orderBy('year')
    .orderBy('month')
    .get();

  return snaps.docs
    .map((d) => d.data())
    .filter((d) => {
      // Clamp to requested range
      if (d.year === fromYear && d.month < fromMonth) return false;
      if (d.year === toYear && d.month > toMonth) return false;
      return d.entry_count >= PRIVACY_THRESHOLD;
    })
    .map((d) => ({
      year: d.year,
      month: d.month,
      averages: d.averages,
      entryCount: d.entry_count,
    }));
}

module.exports = {
  PRIVACY_THRESHOLD,
  updateAggregation,
  reconcileAggregations,
  getInsights,
  getTrendData,
};
