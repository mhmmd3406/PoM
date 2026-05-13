import { useState } from 'react';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { FAMILIES, METRICS } from '../api/client';
import { getMockHeatmap } from '../api/mockData';
import styles from './ExportButton.module.css';

const MOCK = import.meta.env.VITE_MOCK !== 'false';
const PRIVACY_THRESHOLD = 7;

export default function ExportButton({ year, month }) {
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);

  async function handleExport(format) {
    setOpen(false);
    setLoading(true);
    try {
      const rows = MOCK
        ? getMockHeatmap(year, month)
        : await import('../api/client').then((m) => m.fetchHeatmap(year, month));

      if (format === 'pdf') exportPDF(rows, year, month);
      else exportCSV(rows, year, month);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className={styles.wrap}>
      <button
        className={styles.btn}
        onClick={() => setOpen((o) => !o)}
        disabled={loading}
        aria-expanded={open}
      >
        {loading ? '⏳ Generating…' : '↓ Export'}
      </button>
      {open && (
        <div className={styles.dropdown}>
          <button className={styles.item} onClick={() => handleExport('pdf')}>
            <span>📄</span> Export PDF Report
          </button>
          <button className={styles.item} onClick={() => handleExport('csv')}>
            <span>📊</span> Export CSV / Excel
          </button>
        </div>
      )}
    </div>
  );
}

// ── PDF export ────────────────────────────────────────────────────────────────

function exportPDF(rows, year, month) {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
  const period = new Date(year, month - 1, 1).toLocaleString('en-GB', {
    month: 'long', year: 'numeric',
  });

  // Title
  doc.setFontSize(18);
  doc.setTextColor(124, 92, 252);
  doc.text('✦ PoM — B2B Executive Report', 14, 20);
  doc.setFontSize(11);
  doc.setTextColor(123, 125, 145);
  doc.text(`Period: ${period}  ·  Confidential`, 14, 28);

  const head = [['Business Family', '#', ...METRICS.map((m) => `${m.icon} ${m.label}`)]];
  const body = rows.map(({ family, data }) => {
    if (!data || data.bankEntryCount < PRIVACY_THRESHOLD) {
      return [family?.label ?? '—', '🔒', ...METRICS.map(() => '— (N<7)')];
    }
    return [
      family.label,
      data.bankEntryCount,
      ...METRICS.map((m) => {
        const metric = data.metrics.find((x) => x.name.toLowerCase() === m.label.toLowerCase());
        const v = metric?.bankValue;
        const d = metric?.delta;
        if (v == null) return '—';
        return `${v.toFixed(1)}  (${d >= 0 ? '+' : ''}${d?.toFixed(1) ?? '—'})`;
      }),
    ];
  });

  autoTable(doc, {
    startY: 34,
    head,
    body,
    theme: 'grid',
    headStyles: { fillColor: [17, 19, 31], textColor: [123, 125, 145], fontSize: 9 },
    bodyStyles: { fontSize: 9, textColor: [241, 241, 245] },
    alternateRowStyles: { fillColor: [24, 26, 42] },
    styles: { fillColor: [17, 19, 31], cellPadding: 3 },
  });

  doc.save(`PoM-Report-${year}-${String(month).padStart(2, '0')}.pdf`);
}

// ── CSV export ────────────────────────────────────────────────────────────────

function exportCSV(rows, year, month) {
  const cols = ['Business Family', 'Responses', ...METRICS.map((m) => m.label), ...METRICS.map((m) => `${m.label} Delta`)];
  const lines = [cols.join(',')];

  for (const { family, data } of rows) {
    if (!data || data.bankEntryCount < PRIVACY_THRESHOLD) {
      lines.push([family?.label ?? '', 'N<7', ...METRICS.map(() => ''), ...METRICS.map(() => '')].join(','));
      continue;
    }
    const vals = METRICS.map((m) => {
      const met = data.metrics.find((x) => x.name.toLowerCase() === m.label.toLowerCase());
      return met?.bankValue?.toFixed(2) ?? '';
    });
    const deltas = METRICS.map((m) => {
      const met = data.metrics.find((x) => x.name.toLowerCase() === m.label.toLowerCase());
      return met?.delta?.toFixed(2) ?? '';
    });
    lines.push([family.label, data.bankEntryCount, ...vals, ...deltas].join(','));
  }

  const blob = new Blob([lines.join('\n')], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `PoM-Report-${year}-${String(month).padStart(2, '0')}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}
