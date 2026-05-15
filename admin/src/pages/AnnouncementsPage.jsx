import { useEffect, useState } from 'react';
import { collection, query, orderBy, onSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../firebase.js';
import { useToast } from '../hooks/useToast.js';

const TIERS = [
  { value: 'all',        label: 'Tüm Kullanıcılar' },
  { value: 'free',       label: 'Free'              },
  { value: 'pro',        label: 'Pro'               },
  { value: 'enterprise', label: 'Enterprise'        },
];

export default function AnnouncementsPage() {
  const [items,   setItems]   = useState([]);
  const [form,    setForm]    = useState({ title: '', body: '', target_tier: 'all', expires_at: '' });
  const [loading, setLoading] = useState(false);
  const [show2,   setShow2]   = useState(false);
  const { toast, show }       = useToast();

  useEffect(() => {
    const q    = query(collection(db, 'announcements'), orderBy('published_at', 'desc'));
    const unsub = onSnapshot(q, snap => {
      setItems(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return unsub;
  }, []);

  async function publish() {
    if (!form.title || !form.body) return;
    setLoading(true);
    try {
      const fn = httpsCallable(functions, 'adminPublishAnnouncement');
      await fn({
        ...form,
        expires_at: form.expires_at ? new Date(form.expires_at).getTime() : null,
      });
      show('Duyuru yayınlandı ✓');
      setForm({ title: '', body: '', target_tier: 'all', expires_at: '' });
      setShow2(false);
    } catch (err) {
      show(err.message, 'err');
    } finally {
      setLoading(false);
    }
  }

  async function toggle(item) {
    try {
      const fn = httpsCallable(functions, 'adminToggleAnnouncement');
      await fn({ announcement_id: item.id, is_active: !item.is_active });
    } catch (err) {
      show(err.message, 'err');
    }
  }

  function fmt(ts) {
    return ts?.toDate?.()?.toLocaleDateString('tr-TR') || '—';
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 800 }}>📢 Duyurular</h1>
          <p style={{ color: 'var(--muted)', fontSize: 13, marginTop: 4 }}>
            Uygulama içi banner bildirimleri
          </p>
        </div>
        <button className="btn-primary" onClick={() => setShow2(!show2)}>+ Yeni Duyuru</button>
      </div>

      {show2 && (
        <div className="card" style={{ marginBottom: 24, maxWidth: 520 }}>
          <div className="card-title">Yeni Duyuru</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label>Başlık</label>
              <input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} placeholder="Kısa başlık" />
            </div>
            <div>
              <label>İçerik</label>
              <textarea value={form.body} onChange={e => setForm(f => ({ ...f, body: e.target.value }))} placeholder="Duyuru metni…" style={{ minHeight: 80 }} />
            </div>
            <div>
              <label>Hedef Kitle</label>
              <select value={form.target_tier} onChange={e => setForm(f => ({ ...f, target_tier: e.target.value }))}>
                {TIERS.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
              </select>
            </div>
            <div>
              <label>Son Geçerlilik Tarihi (isteğe bağlı)</label>
              <input type="date" value={form.expires_at} onChange={e => setForm(f => ({ ...f, expires_at: e.target.value }))} />
            </div>
          </div>
          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <button className="btn-primary" onClick={publish} disabled={loading || !form.title || !form.body}>
              {loading ? 'Yayınlanıyor…' : 'Yayınla'}
            </button>
            <button className="btn-ghost" onClick={() => setShow2(false)}>İptal</button>
          </div>
        </div>
      )}

      <div className="card">
        <table>
          <thead>
            <tr><th>Başlık</th><th>Hedef</th><th>Tarih</th><th>Durum</th><th></th></tr>
          </thead>
          <tbody>
            {items.map(a => (
              <tr key={a.id}>
                <td><strong>{a.title}</strong><div style={{ fontSize: 11, color: 'var(--muted)' }}>{a.body?.slice(0,50)}…</div></td>
                <td><span className="badge badge-blue">{a.target_tier}</span></td>
                <td style={{ fontSize: 12, color: 'var(--muted)' }}>{fmt(a.published_at)}</td>
                <td><span className={`badge badge-${a.is_active ? 'green' : 'red'}`}>{a.is_active ? 'Aktif' : 'Pasif'}</span></td>
                <td>
                  <button className="btn-ghost btn-sm" onClick={() => toggle(a)}>
                    {a.is_active ? 'Kapat' : 'Aç'}
                  </button>
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center', color: 'var(--muted)' }}>Henüz duyuru yok</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {toast && <div className={`toast ${toast.type}`}>{toast.msg}</div>}
    </div>
  );
}
