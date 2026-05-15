import { useEffect, useState } from 'react';
import { collection, query, orderBy, onSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../firebase.js';
import { useToast } from '../hooks/useToast.js';

const STATUS_LABELS = {
  pending:      { label: 'Bekliyor',     badge: 'yellow' },
  under_review: { label: 'İnceleniyor', badge: 'blue'   },
  resolved:     { label: 'Çözüldü',     badge: 'green'  },
  rejected:     { label: 'Reddedildi',  badge: 'red'    },
};

const CATEGORY_LABELS = {
  methodology:          'Metodoloji',
  data_accuracy:        'Veri Doğruluğu',
  manipulation_suspicion:'Manipülasyon Şüphesi',
  other:                'Diğer',
};

export default function DisputesPage() {
  const [disputes, setDisputes] = useState([]);
  const [selected, setSelected] = useState(null);
  const [note,     setNote]     = useState('');
  const [status,   setStatus]   = useState('under_review');
  const [loading,  setLoading]  = useState(false);
  const { toast, show }         = useToast();

  useEffect(() => {
    const q    = query(collection(db, 'disputes'), orderBy('submitted_at', 'desc'));
    const unsub = onSnapshot(q, snap => {
      setDisputes(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return unsub;
  }, []);

  async function resolve() {
    if (!selected) return;
    setLoading(true);
    try {
      const fn = httpsCallable(functions, 'adminResolveDispute');
      await fn({ dispute_id: selected.id, status, admin_note: note });
      show('İtiraz güncellendi ✓');
      setSelected(null);
    } catch (err) {
      show(err.message, 'err');
    } finally {
      setLoading(false);
    }
  }

  function fmt(ts) {
    return ts?.toDate?.()?.toLocaleDateString('tr-TR') || '—';
  }

  return (
    <div>
      <h1 style={{ fontSize: 22, fontWeight: 800, marginBottom: 6 }}>📬 İtiraz Yönetimi</h1>
      <p style={{ color: 'var(--muted)', marginBottom: 24, fontSize: 13 }}>
        Bankalar tarafından gönderilen metodoloji ve veri doğruluğu itirazları
      </p>

      <div style={{ display: 'flex', gap: 20 }}>
        <div className="card" style={{ flex: 2 }}>
          <table>
            <thead>
              <tr><th>Banka</th><th>Kategori</th><th>Tarih</th><th>Durum</th><th></th></tr>
            </thead>
            <tbody>
              {disputes.map(d => {
                const s = STATUS_LABELS[d.status] || { label: d.status, badge: 'blue' };
                return (
                  <tr key={d.id}>
                    <td><code style={{ fontSize: 12 }}>{d.bank_id}</code></td>
                    <td>{CATEGORY_LABELS[d.category] || d.category}</td>
                    <td style={{ fontSize: 12, color: 'var(--muted)' }}>{fmt(d.submitted_at)}</td>
                    <td><span className={`badge badge-${s.badge}`}>{s.label}</span></td>
                    <td>
                      <button className="btn-ghost btn-sm" onClick={() => {
                        setSelected(d);
                        setNote(d.admin_note || '');
                        setStatus(d.status === 'pending' ? 'under_review' : d.status);
                      }}>İncele</button>
                    </td>
                  </tr>
                );
              })}
              {disputes.length === 0 && (
                <tr><td colSpan={5} style={{ textAlign: 'center', color: 'var(--muted)' }}>Henüz itiraz yok</td></tr>
              )}
            </tbody>
          </table>
        </div>

        {selected && (
          <div className="card" style={{ flex: 1, minWidth: 280 }}>
            <div className="card-title">İtiraz Detayı</div>
            <div style={{ fontSize: 12, color: 'var(--muted)', marginBottom: 4 }}>Banka</div>
            <div style={{ fontWeight: 600, marginBottom: 12 }}>{selected.bank_id}</div>

            <div style={{ fontSize: 12, color: 'var(--muted)', marginBottom: 4 }}>Açıklama</div>
            <div style={{
              background: 'var(--bg)', borderRadius: 8, padding: 12,
              fontSize: 12, lineHeight: 1.6, marginBottom: 16
            }}>
              {selected.description}
            </div>

            <div style={{ marginBottom: 12 }}>
              <label>Durum</label>
              <select value={status} onChange={e => setStatus(e.target.value)}>
                <option value="under_review">İnceleniyor</option>
                <option value="resolved">Çözüldü</option>
                <option value="rejected">Reddedildi</option>
              </select>
            </div>

            <div style={{ marginBottom: 16 }}>
              <label>Admin Notu</label>
              <textarea value={note} onChange={e => setNote(e.target.value)} placeholder="İçeride görünür not…" style={{ minHeight: 80 }} />
            </div>

            <div style={{ display: 'flex', gap: 8 }}>
              <button className="btn-primary" onClick={resolve} disabled={loading}>
                {loading ? 'Kaydediliyor…' : 'Kaydet'}
              </button>
              <button className="btn-ghost" onClick={() => setSelected(null)}>Kapat</button>
            </div>
          </div>
        )}
      </div>

      {toast && <div className={`toast ${toast.type}`}>{toast.msg}</div>}
    </div>
  );
}
