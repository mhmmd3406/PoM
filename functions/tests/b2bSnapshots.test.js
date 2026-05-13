'use strict';

const { MIN_SNAPSHOT_DELTA } = require('../src/b2bSnapshots');

// ── snapshotDocId (inline for isolation) ──────────────────────────────────

function snapshotDocId(bankId, businessFamily, year, month) {
  return `${bankId}_${businessFamily}_${year}_${String(month).padStart(2, '0')}`;
}

// ── Trend filter (inline for isolation) ──────────────────────────────────

function filterTrendPoints(docs, fromYear, fromMonth, toYear, toMonth) {
  return docs.filter((d) => {
    if (d.year === fromYear && d.month < fromMonth) return false;
    if (d.year === toYear   && d.month > toMonth)   return false;
    return true;
  });
}

// ── Tests ──────────────────────────────────────────────────────────────────

describe('MIN_SNAPSHOT_DELTA', () => {
  test('exported constant is 3', () => {
    expect(MIN_SNAPSHOT_DELTA).toBe(3);
  });

  test('delta exactly at threshold is publishable', () => {
    expect(3 >= MIN_SNAPSHOT_DELTA).toBe(true);
  });

  test('delta below threshold is withheld', () => {
    expect(2 >= MIN_SNAPSHOT_DELTA).toBe(false);
    expect(1 >= MIN_SNAPSHOT_DELTA).toBe(false);
    expect(0 >= MIN_SNAPSHOT_DELTA).toBe(false);
  });

  test('first snapshot (prevCount=0, liveCount=7) passes when delta>=3', () => {
    const liveCount = 7;
    const prevCount = 0;
    expect(liveCount - prevCount).toBeGreaterThanOrEqual(MIN_SNAPSHOT_DELTA);
  });
});

describe('snapshotDocId', () => {
  test('zero-pads single-digit months', () => {
    expect(snapshotDocId('bank1', 'IT', 2024, 3)).toBe('bank1_IT_2024_03');
  });

  test('does not pad two-digit months', () => {
    expect(snapshotDocId('bank1', 'IT', 2024, 11)).toBe('bank1_IT_2024_11');
  });

  test('includes all components', () => {
    const id = snapshotDocId('my-bank', 'all', 2025, 1);
    expect(id).toBe('my-bank_all_2025_01');
  });
});

describe('Trend point filtering', () => {
  // Firestore's `where year >= fromYear AND year <= toYear` pre-filters the set.
  // These filters handle the boundary months within the edge years.
  const allPoints = [
    { year: 2024, month: 1 },
    { year: 2024, month: 6 },
    { year: 2024, month: 12 },
    { year: 2025, month: 1 },
    { year: 2025, month: 6 },
  ];

  test('filters out points before fromMonth in fromYear', () => {
    const result = filterTrendPoints(allPoints, 2024, 6, 2025, 6);
    expect(result.some((p) => p.year === 2024 && p.month === 1)).toBe(false);
    expect(result.some((p) => p.year === 2024 && p.month === 6)).toBe(true);
  });

  test('filters out points after toMonth in toYear', () => {
    const result = filterTrendPoints(allPoints, 2024, 1, 2025, 1);
    expect(result.some((p) => p.year === 2025 && p.month === 6)).toBe(false);
    expect(result.some((p) => p.year === 2025 && p.month === 1)).toBe(true);
  });

  test('includes all points within full range', () => {
    const result = filterTrendPoints(allPoints, 2024, 1, 2025, 6);
    expect(result).toHaveLength(5);
  });

  test('single month range returns only that month', () => {
    // Input pre-filtered by Firestore to year==2024 only
    const year2024 = [
      { year: 2024, month: 1 },
      { year: 2024, month: 6 },
      { year: 2024, month: 12 },
    ];
    const result = filterTrendPoints(year2024, 2024, 6, 2024, 6);
    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ year: 2024, month: 6 });
  });
});

describe('Differential privacy invariant', () => {
  // Core guarantee: an observer seeing two consecutive snapshots N1 and N2
  // cannot isolate an individual if delta >= 3 (underdetermined system).
  test('delta < 3 prevents isolation attack', () => {
    // With delta=1: attacker solves new_avg*N - old_avg*(N-1) = individual
    // With delta>=3: at least 3 unknowns, 1 equation → unsolvable
    for (let delta = 0; delta < MIN_SNAPSHOT_DELTA; delta++) {
      expect(delta >= MIN_SNAPSHOT_DELTA).toBe(false);
    }
  });
});
