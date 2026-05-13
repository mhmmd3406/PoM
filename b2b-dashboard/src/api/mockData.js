/**
 * Mock data for local dev without a live API.
 * Mirrors the BenchmarkResponse shape.
 * Set VITE_MOCK=true to use this instead of the real API.
 */

import { FAMILIES, METRICS } from './client';

const BANK_ID = 'garanti_bbva';

// Family-level personality (mirrors seed_data.js deltas)
const FAMILY_PROFILES = {
  hq_it:             { salary: 4.55, benefits: 4.2, workModel: 5.2, culture: 4.2, wlb: 4.15 },
  branch_operations: { salary: 4.2,  benefits: 4.05,workModel: 2.75,culture: 4.1, wlb: 3.25 },
  corporate_banking: { salary: 4.75, benefits: 4.35,workModel: 4.0, culture: 4.25,wlb: 3.45 },
  retail_banking:    { salary: 4.1,  benefits: 4.0, workModel: 3.6, culture: 4.35,wlb: 3.55 },
  risk_compliance:   { salary: 4.4,  benefits: 4.2, workModel: 4.1, culture: 4.4, wlb: 3.15 },
  human_resources:   { salary: 4.15, benefits: 4.25,workModel: 4.1, culture: 4.6, wlb: 4.45 },
  finance_accounting:{ salary: 4.6,  benefits: 4.15,workModel: 3.85,culture: 4.2, wlb: 3.9  },
};

const SECTOR_PROFILES = {
  hq_it:             { salary: 4.2,  benefits: 3.95,workModel: 4.9, culture: 4.0, wlb: 3.9  },
  branch_operations: { salary: 3.85, benefits: 3.7, workModel: 2.6, culture: 3.9, wlb: 3.1  },
  corporate_banking: { salary: 4.45, benefits: 4.1, workModel: 3.85,culture: 4.0, wlb: 3.3  },
  retail_banking:    { salary: 3.75, benefits: 3.65,workModel: 3.45,culture: 4.05,wlb: 3.4  },
  risk_compliance:   { salary: 4.0,  benefits: 4.0, workModel: 3.9, culture: 4.1, wlb: 2.95 },
  human_resources:   { salary: 3.8,  benefits: 4.0, workModel: 4.0, culture: 4.35,wlb: 4.2  },
  finance_accounting:{ salary: 4.2,  benefits: 3.9, workModel: 3.75,culture: 3.95,wlb: 3.7  },
};

function makeMetrics(bankProf, sectorProf) {
  return METRICS.map(({ key, label }) => {
    const bankVal  = Math.min(5, Math.max(1, bankProf[key]   ?? 0));
    const secVal   = Math.min(5, Math.max(1, sectorProf[key] ?? 0));
    const overall  = key === 'overall';
    return {
      name: label,
      bankValue:   overall
        ? +(Object.values(bankProf).reduce((a,b)=>a+b,0) / 5).toFixed(2)
        : +bankVal.toFixed(2),
      sectorValue: overall
        ? +(Object.values(sectorProf).reduce((a,b)=>a+b,0) / 5).toFixed(2)
        : +secVal.toFixed(2),
      delta: overall
        ? +((Object.values(bankProf).reduce((a,b)=>a+b,0)/5) - (Object.values(sectorProf).reduce((a,b)=>a+b,0)/5)).toFixed(2)
        : +(bankVal - secVal).toFixed(2),
    };
  });
}

export function getMockHeatmap(year, month) {
  return FAMILIES.filter(f => f.id !== 'all').map((family) => {
    const bankProf   = FAMILY_PROFILES[family.id];
    const sectorProf = SECTOR_PROFILES[family.id];
    // risk_compliance only has 5 members → simulate N<7 for one bank
    const entryCount = family.id === 'risk_compliance' ? 5 : 12 + Math.floor(Math.random() * 6);
    return {
      family,
      data: {
        bankId: BANK_ID,
        businessFamily: family.id,
        year,
        month,
        bankEntryCount: entryCount,
        metrics: makeMetrics(bankProf, sectorProf),
      },
    };
  });
}

export function getMockTrend(businessFamily) {
  const months = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(2026, 4 - i, 1);
    const prof = FAMILY_PROFILES[businessFamily] ?? FAMILY_PROFILES.hq_it;
    const drift = i * 0.04;
    months.push({
      year: d.getFullYear(),
      month: d.getMonth() + 1,
      entryCount: 15,
      snapshotDate: d.toISOString(),
      averages: {
        salary:    +(prof.salary    - drift).toFixed(2),
        benefits:  +(prof.benefits  - drift * 0.5).toFixed(2),
        workModel: +(prof.workModel - drift * 0.3).toFixed(2),
        culture:   +(prof.culture   - drift * 0.2).toFixed(2),
        wlb:       +(prof.wlb       - drift * 0.6).toFixed(2),
        overall:   +((prof.salary + prof.benefits + prof.workModel + prof.culture + prof.wlb) / 5 - drift * 0.3).toFixed(2),
      },
    });
  }
  return { bankId: BANK_ID, businessFamily, points: months };
}
