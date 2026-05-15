import { useEffect, useState } from 'react';
import { doc, onSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../firebase.js';
import { useToast } from '../hooks/useToast.js';

const FLAGS = [
  { key: 'head_to_head_enabled',    label: 'Head-to-Head Karşılaştırma',
    hint: 'Enterprise müşterilerin rakip bankalarla karşılaştırma yapabilmesini sağlar.' },
  { key: 'retention_risk_enabled',  label: 'Retention Risk Analizi',
    hint: 'Çalışan elde tutma riski raporunu aktif eder.' },
  { key: 'maintenance_mode',        label: 'Bakım Modu',
    hint: 'Tüm kullanıcılara bakım ekranı gösterir. Dikkatli kullan!' },
];

export default function FeatureFlagsPage() {
  const [data,    setData]    = useState({});
  const [draft,   setDraft]   = useState({});
  const [loading, setLoading] = useState(false);
  const { toast, show }       = useToast();

  useEffect(() => {
    const unsub = onSnapshot(doc(db, 'platform_config/feature_flags'), snap => {
      const d = snap.exists() ? snap.data() : {};
      setData(d);
      const init = {};
      FLAGS.forEach(f => { init[f.key] = d[f.key] ?? true; });
      init.maintenance_mode    = d.maintenance_mode    ?? false;
      init.maintenance_message = d.maintenance_message ?? '';
      setDraft(init);
    });
    return unsub;
  }, []);

  async function save() {
    setLoading(true);
    try {
      const fn = httpsCallable(functions, 'adminUpdateFeatureFlags');
      await fn(draft);
      show('Feature flags güncellendi ✓');
    } catch (err) {
      show(err.message, 'err');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <h1 style={{ fontSize: 22, fontWeight: 800, marginBottom: 6 }}>🚩 Feature Flags</h1>
      <p style={{ color: 'var(--muted)', marginBottom: 28, fontSize: 13 }}>
        Özellikleri deploy yapmadan aç/kapat. Değişiklikler anında etkin olur.
      </p>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 14, maxWidth: 600 }}>
        {FLAGS.map(f => (
          <div className="card" key={f.key}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 16 }}>
              <div>
                <div style={{ fontWeight: 600, fontSize: 14 }}>{f.label}</div>
                <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 2 }}>{f.hint}</div>
              </div>
              <div
                className={`toggle ${draft[f.key] !== false ? 'on' : ''}`}
                style={{ flexShrink: 0, marginTop: 2 }}
                onClick={() => setDraft(d => ({ ...d, [f.key]: !d[f.key] }))}
              />
            </div>
            {f.key === 'maintenance_mode' && draft.maintenance_mode && (
              <div style={{ marginTop: 12 }}>
                <label>Bakım Mesajı (kullanıcıya gösterilecek)</label>
                <input
                  value={draft.maintenance_message || ''}
                  onChange={e => setDraft(d => ({ ...d, maintenance_message: e.target.value }))}
                  placeholder="Kısa süreliğine bakım yapılıyor…"
                />
              </div>
            )}
          </div>
        ))}
      </div>

      <button className="btn-primary" style={{ marginTop: 20 }} onClick={save} disabled={loading}>
        {loading ? 'Kaydediliyor…' : 'Kaydet'}
      </button>

      {toast && <div className={`toast ${toast.type}`}>{toast.msg}</div>}
    </div>
  );
}
