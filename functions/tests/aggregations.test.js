'use strict';

// Unit tests for aggregation pure-logic:
// - aggDocId format
// - Welford incremental mean
// - Privacy threshold enforcement
// - Overall score computation
// All Firestore I/O is tested in the integration suite; these are pure math tests.

const METRICS = ['salary', 'benefits', 'work_model', 'culture', 'wlb'];
const PRIVACY_THRESHOLD = 7;

// ── Inline helpers mirroring aggregations.js ───────────────────────────────

function aggDocId(bankId, businessFamily, year, month) {
  const bankPart = bankId || 'SECTOR';
  return `${bankPart}_${businessFamily}_${year}_${String(month).padStart(2, '0')}`;
}

function computeOverall(ratings) {
  return METRICS.reduce((sum, m) => sum + (ratings[m] || 0), 0) / METRICS.length;
}

function incrementalMean(oldAvg, oldN, newValue) {
  return (oldAvg * oldN + newValue) / (oldN + 1);
}

function meetsPrivacyThreshold(entryCount) {
  return entryCount >= PRIVACY_THRESHOLD;
}

// ── Tests ──────────────────────────────────────────────────────────────────

describe('aggDocId', () => {
  test('bank aggregation', () => {
    expect(aggDocId('barclays', 'IT', 2024, 7)).toBe('barclays_IT_2024_07');
  });

  test('sector aggregation (null bankId)', () => {
    expect(aggDocId(null, 'all', 2024, 12)).toBe('SECTOR_all_2024_12');
  });

  test('zero-pads month', () => {
    expect(aggDocId('bank1', 'all', 2024, 1)).toBe('bank1_all_2024_01');
  });
});

describe('Overall score computation', () => {
  test('average of all 5 metrics', () => {
    const ratings = { salary: 4, benefits: 3, work_model: 5, culture: 4, wlb: 3 };
    const overall = computeOverall(ratings);
    expect(overall).toBeCloseTo((4 + 3 + 5 + 4 + 3) / 5);
  });

  test('all 5s gives 5.0', () => {
    const ratings = { salary: 5, benefits: 5, work_model: 5, culture: 5, wlb: 5 };
    expect(computeOverall(ratings)).toBe(5);
  });

  test('all 1s gives 1.0', () => {
    const ratings = { salary: 1, benefits: 1, work_model: 1, culture: 1, wlb: 1 };
    expect(computeOverall(ratings)).toBe(1);
  });

  test('missing metric defaults to 0', () => {
    const ratings = { salary: 4, benefits: 4, work_model: 4, culture: 4 }; // no wlb
    const overall = computeOverall(ratings);
    expect(overall).toBeCloseTo(16 / 5);
  });
});

describe('Welford incremental mean', () => {
  test('first entry: mean equals the value', () => {
    expect(incrementalMean(0, 0, 3)).toBe(3);
  });

  test('second entry: mean is simple average', () => {
    const m1 = incrementalMean(0, 0, 4); // 4
    const m2 = incrementalMean(m1, 1, 2); // (4+2)/2 = 3
    expect(m2).toBeCloseTo(3);
  });

  test('online mean converges to batch mean', () => {
    const values = [3, 4, 5, 2, 4, 3, 5];
    let mean = 0;
    for (let i = 0; i < values.length; i++) {
      mean = incrementalMean(mean, i, values[i]);
    }
    const batchMean = values.reduce((s, v) => s + v, 0) / values.length;
    expect(mean).toBeCloseTo(batchMean, 10);
  });

  test('large N: online mean matches batch mean', () => {
    const values = Array.from({ length: 100 }, (_, i) => (i % 5) + 1);
    let mean = 0;
    for (let i = 0; i < values.length; i++) {
      mean = incrementalMean(mean, i, values[i]);
    }
    const batchMean = values.reduce((s, v) => s + v, 0) / values.length;
    expect(mean).toBeCloseTo(batchMean, 8);
  });
});

describe('Privacy threshold', () => {
  test('exactly 7 entries is public', () => {
    expect(meetsPrivacyThreshold(7)).toBe(true);
  });

  test('6 entries is withheld', () => {
    expect(meetsPrivacyThreshold(6)).toBe(false);
  });

  test('0 entries is withheld', () => {
    expect(meetsPrivacyThreshold(0)).toBe(false);
  });

  test('100 entries is public', () => {
    expect(meetsPrivacyThreshold(100)).toBe(true);
  });
});
