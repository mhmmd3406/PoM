'use strict';

const admin = require('firebase-admin');
const { getThresholds } = require('./platformConfig');

// Minimum new entries required between snapshots.
// With delta >= 3, an attacker observing two consecutive snapshots gets one
// linear equation with ≥3 unknowns — mathematically unsolvable for individual scores.
const MIN_SNAPSHOT_DELTA = 3;

/**
 * Builds the latest-snapshot query document ID.
 * Format: {bankId}_{businessFamily}_{year}_{MM}
 * We store one "current" document per bank×family×month and archive old ones.
 */
function snapshotDocId(bankId, businessFamily, year, month) {
  return `${bankId}_${businessFamily}_${year}_${String(month).padStart(2, '0')}`;
}

/**
 * Daily Cloud Scheduler job: generate B2B snapshots.
 *
 * For each bank×family×month aggregation:
 *  1. Read current live aggregation (entry_count, averages).
 *  2. Read the last published snapshot for that combination.
 *  3. Compute delta = current.entry_count - lastSnapshot.entry_count.
 *  4. Only publish a new snapshot if delta >= MIN_SNAPSHOT_DELTA.
 *
 * This ensures no single submission is individually traceable in B2B reports.
 */
async function generateB2BSnapshots() {
  const db = admin.firestore();
  const now = new Date();
  const snapshotTimestamp = admin.firestore.Timestamp.fromDate(now);

  // Process current month and previous month (boundary coverage)
  const periods = [
    { year: now.getUTCFullYear(), month: now.getUTCMonth() + 1 },
  ];
  if (now.getUTCMonth() === 0) {
    periods.push({ year: now.getUTCFullYear() - 1, month: 12 });
  } else {
    periods.push({ year: now.getUTCFullYear(), month: now.getUTCMonth() });
  }

  let published = 0;
  let skipped = 0;

  const cfg = await getThresholds().catch(() => ({ companyThreshold: 15, departmentThreshold: 10 }));

  for (const { year, month } of periods) {
    // Fetch all live aggregations — filter by threshold in memory (different thresholds per family)
    const liveSnap = await db
      .collection('aggregations')
      .where('year', '==', year)
      .where('month', '==', month)
      .get();

    const batch = db.batch();

    for (const liveDoc of liveSnap.docs) {
      const live = liveDoc.data();
      const { bank_id, business_family } = live;

      // Apply dynamic threshold (company vs department)
      const threshold = business_family === 'all' ? cfg.companyThreshold : cfg.departmentThreshold;
      if (live.entry_count < threshold) { skipped++; continue; }

      const docId = snapshotDocId(bank_id, business_family, year, month);
      const snapshotRef = db.collection('b2b_snapshots').doc(docId);
      const prevSnap = await snapshotRef.get();

      const prevEntryCount = prevSnap.exists ? prevSnap.data().entry_count : 0;
      const delta = live.entry_count - prevEntryCount;

      if (delta < MIN_SNAPSHOT_DELTA) {
        skipped++;
        continue; // Not enough new entries — withhold update to prevent differential attack
      }

      batch.set(snapshotRef, {
        bank_id,
        business_family,
        department_type: live.department_type || 'all',
        year,
        month,
        entry_count: live.entry_count,
        delta_count: delta,
        averages: live.averages,
        snapshot_date: snapshotTimestamp,
        previous_snapshot_date: prevSnap.exists
          ? prevSnap.data().snapshot_date
          : null,
      });

      // Archive the replaced snapshot for audit trail
      if (prevSnap.exists) {
        const archiveRef = db
          .collection('b2b_snapshots_archive')
          .doc(`${docId}_${prevSnap.data().snapshot_date.toDate().toISOString().slice(0, 10)}`);
        batch.set(archiveRef, prevSnap.data());
      }

      published++;
    }

    await batch.commit();
  }

  return { published, skipped };
}

/**
 * Fetch month-over-month B2B trend data from snapshots (not live aggregations).
 * Only snapshot data is served to B2B clients — never real-time.
 */
async function getB2BTrendFromSnapshots(bankId, businessFamily, fromYear, fromMonth, toYear, toMonth) {
  const db = admin.firestore();

  const snaps = await db
    .collection('b2b_snapshots')
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
      if (d.year === fromYear && d.month < fromMonth) return false;
      if (d.year === toYear && d.month > toMonth) return false;
      return true;
    })
    .map((d) => ({
      year: d.year,
      month: d.month,
      averages: d.averages,
      entryCount: d.entry_count,
      snapshotDate: d.snapshot_date.toDate().toISOString().slice(0, 10),
    }));
}

module.exports = {
  generateB2BSnapshots,
  getB2BTrendFromSnapshots,
  MIN_SNAPSHOT_DELTA,
};
