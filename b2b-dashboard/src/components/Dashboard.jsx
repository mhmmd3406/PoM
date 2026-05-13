import { useState } from 'react';
import Header from './Header';
import HeatmapSection from './HeatmapSection';
import TrendSection from './TrendSection';
import ExportButton from './ExportButton';
import styles from './Dashboard.module.css';

const NOW = new Date();

export default function Dashboard() {
  const [year]  = useState(NOW.getFullYear());
  const [month] = useState(NOW.getMonth() + 1);
  const [selectedFamily, setSelectedFamily] = useState('hq_it');

  return (
    <div className={styles.root}>
      <Header year={year} month={month} />

      <main className={styles.main}>
        {/* ── Heatmap ─────────────────────────────────── */}
        <section className={styles.section}>
          <div className={styles.sectionHead}>
            <div>
              <h2 className={styles.sectionTitle}>Business Family Heatmap</h2>
              <p className={styles.sectionSub}>
                Your bank's happiness scores vs. sector average · {monthLabel(year, month)}
              </p>
            </div>
            <ExportButton year={year} month={month} />
          </div>
          <HeatmapSection
            year={year}
            month={month}
            selectedFamily={selectedFamily}
            onSelectFamily={setSelectedFamily}
          />
        </section>

        {/* ── Trend ───────────────────────────────────── */}
        <section className={styles.section}>
          <div className={styles.sectionHead}>
            <div>
              <h2 className={styles.sectionTitle}>6-Month Trend</h2>
              <p className={styles.sectionSub}>
                Month-over-month happiness for <strong>{familyLabel(selectedFamily)}</strong>
              </p>
            </div>
          </div>
          <TrendSection businessFamily={selectedFamily} />
        </section>
      </main>
    </div>
  );
}

function monthLabel(y, m) {
  return new Date(y, m - 1, 1).toLocaleString('en-GB', { month: 'long', year: 'numeric' });
}

function familyLabel(id) {
  const map = {
    hq_it: 'HQ IT & Technology', branch_operations: 'Branch Operations',
    corporate_banking: 'Corporate Banking', retail_banking: 'Retail Banking',
    risk_compliance: 'Risk & Compliance', human_resources: 'Human Resources',
    finance_accounting: 'Finance & Accounting',
  };
  return map[id] ?? id;
}
