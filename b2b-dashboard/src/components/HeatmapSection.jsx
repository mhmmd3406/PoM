import { useQuery } from '@tanstack/react-query';
import { METRICS } from '../api/client';
import { getMockHeatmap } from '../api/mockData';
import PrivacyCell from './PrivacyCell';
import styles from './HeatmapSection.module.css';

const MOCK = import.meta.env.VITE_MOCK !== 'false';
const PRIVACY_THRESHOLD = 7;

function scoreColor(v) {
  if (v == null) return 'var(--muted)';
  if (v >= 4.0) return 'var(--positive)';
  if (v >= 3.0) return 'var(--warning)';
  return 'var(--negative)';
}

function scoreBackground(v) {
  if (v == null) return 'transparent';
  if (v >= 4.0) return 'rgba(52,211,153,0.10)';
  if (v >= 3.0) return 'rgba(251,191,36,0.10)';
  return 'rgba(248,113,113,0.10)';
}

export default function HeatmapSection({ year, month, selectedFamily, onSelectFamily }) {
  const { data: rows = [], isLoading, isError } = useQuery({
    queryKey: ['heatmap', year, month],
    queryFn: () => MOCK
      ? Promise.resolve(getMockHeatmap(year, month))
      : import('../api/client').then(m => m.fetchHeatmap(year, month)),
  });

  if (isLoading) return <Skeleton />;
  if (isError)   return <Error />;

  return (
    <div className={styles.wrapper}>
      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th className={styles.familyHeader}>Business Family</th>
              <th className={styles.countHeader}>#</th>
              {METRICS.map((m) => (
                <th key={m.key} className={styles.metricHeader}>
                  <span>{m.icon}</span>
                  <span>{m.label}</span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map(({ family, data }) => {
              if (!family) return null;
              const isPrivate = !data || data.bankEntryCount < PRIVACY_THRESHOLD;
              const isSelected = family.id === selectedFamily;

              return (
                <tr
                  key={family.id}
                  className={`${styles.row} ${isSelected ? styles.rowSelected : ''}`}
                  onClick={() => onSelectFamily(family.id)}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && onSelectFamily(family.id)}
                >
                  <td className={styles.familyCell}>
                    <span className={styles.familyName}>{family.label}</span>
                  </td>
                  <td className={styles.countCell}>
                    {isPrivate ? (
                      <span className={styles.privateCount}>—</span>
                    ) : (
                      <span className={styles.count}>{data.bankEntryCount}</span>
                    )}
                  </td>
                  {METRICS.map((m) => {
                    if (isPrivate) {
                      return (
                        <td key={m.key} className={styles.scoreCell}>
                          <PrivacyCell />
                        </td>
                      );
                    }
                    const metric = data.metrics.find(
                      (x) => x.name.toLowerCase() === m.label.toLowerCase(),
                    );
                    const val = metric?.bankValue;
                    const delta = metric?.delta;
                    return (
                      <td
                        key={m.key}
                        className={styles.scoreCell}
                        style={{ background: scoreBackground(val) }}
                      >
                        <span className={styles.score} style={{ color: scoreColor(val) }}>
                          {val != null ? val.toFixed(1) : '—'}
                        </span>
                        {delta != null && (
                          <span
                            className={styles.delta}
                            style={{ color: delta >= 0 ? 'var(--positive)' : 'var(--negative)' }}
                          >
                            {delta >= 0 ? '+' : ''}{delta.toFixed(1)}
                          </span>
                        )}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Legend */}
      <div className={styles.legend}>
        <LegendDot color="var(--positive)" label="4.0 – 5.0  Thriving" />
        <LegendDot color="var(--warning)"  label="3.0 – 3.9  Average" />
        <LegendDot color="var(--negative)" label="< 3.0  Needs attention" />
        <span className={styles.legendSep} />
        <span className={styles.legendNote}>
          ±delta vs. sector average &nbsp;·&nbsp; click row to drill into trend
        </span>
      </div>
    </div>
  );
}

function LegendDot({ color, label }) {
  return (
    <span className={styles.legendItem}>
      <span className={styles.legendDot} style={{ background: color }} />
      {label}
    </span>
  );
}

function Skeleton() {
  return (
    <div className={styles.skeleton}>
      {[...Array(7)].map((_, i) => (
        <div key={i} className={styles.skeletonRow} style={{ opacity: 1 - i * 0.1 }} />
      ))}
    </div>
  );
}

function Error() {
  return (
    <div className={styles.error}>
      ⚠️ Failed to load heatmap data. Check API connectivity.
    </div>
  );
}
