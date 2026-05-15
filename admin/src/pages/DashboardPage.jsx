import { useEffect, useState } from 'react';
import { collection, getCountFromServer, query, where, doc, getDoc } from 'firebase/firestore';
import { db } from '../firebase.js';

function StatCard({ label, value, sub, color }) {
  return (
    <div className="card" style={{ flex: 1 }}>
      <div style={{ fontSize: 28, fontWeight: 800, color: color || 'var(--text)' }}>{value ?? '—'}</div>
      <div style={{ fontSize: 13, fontWeight: 600, marginTop: 4 }}>{label}</div>
      {sub && <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 2 }}>{sub}</div>}
    </div>
  );
}

export default function DashboardPage() {
  const [stats, setStats] = useState({});
  const [thresholds, setThresholds] = useState(null);
  const [flags, setFlags] = useState(null);

  useEffect(() => {
    async function load() {
      const [users, banks, disputes, checkins, threshSnap, flagsSnap] = await Promise.all([
        getCountFromServer(collection(db, 'users')),
        getCountFromServer(query(collection(db, 'banks'), where('is_active', '==', true))),
        getCountFromServer(query(collection(db, 'disputes'), where('status', '==', 'pending'))),
        getCountFromServer(collection(db, 'checkins')),
        getDoc(doc(db, 'platform_config/thresholds')),
        getDoc(doc(db, 'platform_config/feature_flags')),
      ]);
      setStats({
        users:    users.data().count,
        banks:    banks.data().count,
        disputes: disputes.data().count,
        checkins: checkins.data().count,
      });
      setThresholds(threshSnap.exists() ? threshSnap.data() : null);
      setFlags(flagsSnap.exists() ? flagsSnap.data() : null);
    }
    load();
  }, []);

  return (
    <div>
      <h1 style={{ fontSize: 22, fontWeight: 800, marginBottom: 8 }}>Dashboard</h1>
      <p style={{ color: 'var(--muted)', marginBottom: 28, fontSize: 13 }}>
        Platform sağlık özeti
      </p>

      <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', marginBottom: 28 }}>
        <StatCard label="Aktif Kullanıcı"    value={stats.users}    color="var(--accent2)" />
        <StatCard label="Aktif Banka"        value={stats.banks}    color="var(--positive)" />
        <StatCard label="Bekleyen İtiraz"    value={stats.disputes} color={stats.disputes > 0 ? 'var(--warning)' : 'var(--positive)'} />
        <StatCard label="Toplam Check-in"    value={stats.checkins} />
      </div>

      <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
        <div className="card" style={{ flex: 1, minWidth: 260 }}>
          <div className="card-title">⚖ Aktif Eşikler</div>
          {thresholds ? (
            <table>
              <tbody>
                <tr><td>Şirket eşiği</td><td><strong>N ≥ {thresholds.company_privacy_threshold ?? 15}</strong></td></tr>
                <tr><td>Departman eşiği</td><td><strong>N ≥ {thresholds.department_privacy_threshold ?? 10}</strong></td></tr>
                <tr><td>Min. çalışan</td><td><strong>{thresholds.min_company_employees ?? 200}+</strong></td></tr>
                <tr><td>Check-in bekleme</td><td><strong>{thresholds.checkin_cooldown_days ?? 7} gün</strong></td></tr>
                <tr><td>Max rakip</td><td><strong>{thresholds.max_head_to_head_competitors ?? 3}</strong></td></tr>
              </tbody>
            </table>
          ) : (
            <p style={{ color: 'var(--muted)', fontSize: 12 }}>Varsayılan değerler aktif (config bulunamadı)</p>
          )}
        </div>

        <div className="card" style={{ flex: 1, minWidth: 260 }}>
          <div className="card-title">🚩 Feature Flags</div>
          {flags ? (
            <table>
              <tbody>
                <tr>
                  <td>Head-to-Head</td>
                  <td><span className={`badge badge-${flags.head_to_head_enabled !== false ? 'green' : 'red'}`}>{flags.head_to_head_enabled !== false ? 'Açık' : 'Kapalı'}</span></td>
                </tr>
                <tr>
                  <td>Retention Risk</td>
                  <td><span className={`badge badge-${flags.retention_risk_enabled !== false ? 'green' : 'red'}`}>{flags.retention_risk_enabled !== false ? 'Açık' : 'Kapalı'}</span></td>
                </tr>
                <tr>
                  <td>Bakım Modu</td>
                  <td><span className={`badge badge-${flags.maintenance_mode ? 'yellow' : 'green'}`}>{flags.maintenance_mode ? 'Aktif' : 'Kapalı'}</span></td>
                </tr>
              </tbody>
            </table>
          ) : (
            <p style={{ color: 'var(--muted)', fontSize: 12 }}>Varsayılan değerler aktif</p>
          )}
        </div>
      </div>
    </div>
  );
}
