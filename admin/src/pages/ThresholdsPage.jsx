import { useEffect, useState } from 'react';
import { doc, onSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../firebase.js';
import { useToast } from '../hooks/useToast.js';

const FIELDS = [
  { key: 'company_privacy_threshold',    label: 'Şirket Gizlilik Eşiği (N)',         min: 7,  max: 50,  default: 15, unit: 'check-in',
    hint: 'Bir bankanın genel skoru yayınlanabilmesi için gereken minimum check-in sayısı. En az 7 olmalı.' },
  { key: 'department_privacy_threshold', label: 'Departman Gizlilik Eşiği (N)',       min: 5,  max: 30,  default: 10, unit: 'check-in',
    hint: 'Departman bazlı skorlar için gereken minimum check-in. En az 5 olmalı.' },
  { key: 'min_company_employees',        label: 'Minimum Çalışan Sayısı',            min: 0,  max: 5000, default: 200, unit: 'kişi',
    hint: "Bu sayının altındaki şirketler platforma dahil edilmez. Yeniden kimlik tespiti riskini azaltır." },
  { key: 'checkin_cooldown_days',        label: 'Check-in Bekleme Süresi',           min: 1,  max: 365, default: 7,   unit: 'gün',
    hint: 'Bir kullanıcının iki check-in arasında beklemesi gereken minimum gün sayısı.' },
  { key: 'max_head_to_head_competitors', label: 'Head-to-Head Maksimum Rakip',       min: 1,  max: 10,  default: 3,   unit: 'banka',
    hint: 'Enterprise müşterilerin karşılaştırma yapabileceği maksimum rakip sayısı.' },
  { key: 'retention_risk_max_months',   label: 'Retention Risk Analiz Penceresi',   min: 2,  max: 24,  default: 12,  unit: 'ay',
    hint: 'Elde tutma riski analizinin bakacağı maksimum geçmiş süre.' },
];

export default function ThresholdsPage() {
  const [current, setCurrent] = useState({});
  const [draft,   setDraft]   = useState({});
  const [loading, setLoading] = useState(false);
  const { toast, show }       = useToast();

  useEffect(() => {
    const unsub = onSnapshot(doc(db, 'platform_config/thresholds'), snap => {
      const data = snap.exists() ? snap.data() : {};
      setCurrent(data);
      const init = {};
      FIELDS.forEach(f => { init[f.key] = data[f.key] ?? f.default; });
      setDraft(init);
    });
    return unsub;
  }, []);

  async function save() {
    setLoading(true);
    try {
      const fn = httpsCallable(functions, 'adminUpdateThresholds');
      await fn(draft);
      show('Eşikler güncellendi ✓');
    } catch (err) {
      show(err.message, 'err');
    } finally {
      setLoading(false);
    }
  }

  function reset() {
    const init = {};
    FIELDS.forEach(f => { init[f.key] = current[f.key] ?? f.default; });
    setDraft(init);
  }

  return (
    <div>
      <h1 style={{ fontSize: 22, fontWeight: 800, marginBottom: 6 }}>⚖ Eşik Yönetimi</h1>
      <p style={{ color: 'var(--muted)', marginBottom: 28, fontSize: 13 }}>
        Gizlilik ve erişim eşiklerini buradan yönet. Güvenlik tabanı: şirket min. 7, departman min. 5 — bunun altına düşürülemez.
      </p>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 16, maxWidth: 640 }}>
        {FIELDS.map(f => (
          <div className="card" key={f.key}>
            <label style={{ fontSize: 13, fontWeight: 600, color: 'var(--text)', marginBottom: 4 }}>
              {f.label}
            </label>
            <p style={{ fontSize: 11, color: 'var(--muted)', marginBottom: 12 }}>{f.hint}</p>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <input
                type="number"
                min={f.min} max={f.max}
                value={draft[f.key] ?? f.default}
                onChange={e => setDraft(d => ({ ...d, [f.key]: Number(e.target.value) }))}
                style={{ width: 90 }}
              />
              <span style={{ color: 'var(--muted)', fontSize: 12 }}>{f.unit}</span>
              {current[f.key] !== undefined && current[f.key] !== draft[f.key] && (
                <span className="badge badge-yellow">
                  Mevcut: {current[f.key]}
                </span>
              )}
            </div>
          </div>
        ))}
      </div>

      <div style={{ display: 'flex', gap: 12, marginTop: 24 }}>
        <button className="btn-primary" onClick={save} disabled={loading}>
          {loading ? 'Kaydediliyor…' : 'Kaydet'}
        </button>
        <button className="btn-ghost" onClick={reset} disabled={loading}>
          Geri Al
        </button>
      </div>

      {toast && <div className={`toast ${toast.type}`}>{toast.msg}</div>}
    </div>
  );
}
