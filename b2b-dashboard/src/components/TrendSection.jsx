import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  ResponsiveContainer, LineChart, Line, XAxis, YAxis,
  CartesianGrid, Tooltip, Legend,
} from 'recharts';
import { getMockTrend } from '../api/mockData';
import styles from './TrendSection.module.css';

const MOCK = import.meta.env.VITE_MOCK !== 'false';

const LINES = [
  { key: 'overall',   label: 'Overall',    color: '#a78bfa' },
  { key: 'salary',    label: 'Salary',     color: '#34d399' },
  { key: 'benefits',  label: 'Benefits',   color: '#60a5fa' },
  { key: 'workModel', label: 'Work Model', color: '#fbbf24' },
  { key: 'culture',   label: 'Culture',    color: '#f87171' },
  { key: 'wlb',       label: 'WLB',        color: '#e879f9' },
];

const MONTH_ABBR = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

export default function TrendSection({ businessFamily }) {
  const { data, isLoading, isError } = useQuery({
    queryKey: ['trend', businessFamily],
    queryFn: () => MOCK
      ? Promise.resolve(getMockTrend(businessFamily))
      : import('../api/client').then(m =>
          m.fetchTrend(businessFamily, 2025, 11, 2026, 5)
        ),
  });

  if (isLoading) return <div className={styles.skeleton} />;
  if (isError || !data) return <p className={styles.error}>⚠️ Failed to load trend data.</p>;

  const chartData = data.points.map((p) => ({
    label: `${MONTH_ABBR[p.month]} ${p.year}`,
    ...p.averages,
  }));

  const [visible, setVisible] = useToggleSet(new Set(LINES.map((l) => l.key)));

  return (
    <div className={styles.card}>
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={chartData} margin={{ top: 10, right: 16, bottom: 0, left: -10 }}>
          <CartesianGrid stroke="rgba(255,255,255,0.05)" vertical={false} />
          <XAxis
            dataKey="label"
            tick={{ fill: 'var(--muted)', fontSize: 11 }}
            axisLine={{ stroke: 'var(--border)' }}
            tickLine={false}
          />
          <YAxis
            domain={[1, 5]}
            ticks={[1, 2, 3, 4, 5]}
            tick={{ fill: 'var(--muted)', fontSize: 11 }}
            axisLine={false}
            tickLine={false}
          />
          <Tooltip content={<CustomTooltip />} />
          {LINES.map((l) =>
            visible.has(l.key) ? (
              <Line
                key={l.key}
                type="monotone"
                dataKey={l.key}
                stroke={l.color}
                strokeWidth={2}
                dot={{ r: 4, fill: l.color, strokeWidth: 0 }}
                activeDot={{ r: 6, strokeWidth: 0 }}
                name={l.label}
              />
            ) : null,
          )}
        </LineChart>
      </ResponsiveContainer>

      {/* Custom toggle legend */}
      <div className={styles.legend}>
        {LINES.map((l) => (
          <button
            key={l.key}
            className={`${styles.legendBtn} ${!visible.has(l.key) ? styles.inactive : ''}`}
            onClick={() => setVisible(l.key)}
            style={{ '--c': l.color }}
          >
            <span className={styles.legendDot} />
            {l.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function CustomTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div className={styles.tooltip}>
      <div className={styles.tooltipLabel}>{label}</div>
      {payload.map((p) => (
        <div key={p.dataKey} className={styles.tooltipRow}>
          <span className={styles.tooltipDot} style={{ background: p.stroke }} />
          <span className={styles.tooltipName}>{p.name}</span>
          <span className={styles.tooltipVal}>{p.value?.toFixed(2)}</span>
        </div>
      ))}
    </div>
  );
}

function useToggleSet(initial) {
  const [set, setSet] = useState(initial);
  const toggle = (key) =>
    setSet((prev) => {
      const next = new Set(prev);
      next.has(key) ? next.delete(key) : next.add(key);
      return next;
    });
  return [set, toggle];
}
