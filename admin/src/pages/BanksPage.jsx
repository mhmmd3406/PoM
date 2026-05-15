import { useEffect, useState } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../firebase.js';
import { useToast } from '../hooks/useToast.js';

export default function BanksPage() {
  const [banks,   setBanks]   = useState([]);
  const [form,    setForm]    = useState({ bank_id: '', display_name: '', employee_count: 0, is_active: true, logo_url: '' });
  const [editing, setEditing] = useState(null);
  const [loading, setLoading] = useState(false);
  const { toast, show }       = useToast();

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'banks'), snap => {
      setBanks(snap.docs.map(d => ({ id: d.id, ...d.data() })).sort((a,b) => a.id.localeCompare(b.id)));
    });
    return unsub;
  }, []);

  function startEdit(bank) {
    setEditing(bank.id);
    setForm({
      bank_id:        bank.id,
      display_name:   bank.display_name || '',
      employee_count: bank.employee_count || 0,
      is_active:      bank.is_active !== false,
      logo_url:       bank.logo_url || '',
    });
  }

  function startNew() {
    setEditing('__new__');
    setForm({ bank_id: '', display_name: '', employee_count: 200, is_active: true, logo_url: '' });
  }

  async function save() {
    if (!form.bank_id.trim()) return;
    setLoading(true);
    try {
      const fn = httpsCallable(functions, 'adminUpsertBank');
      await fn(form);
      show('Banka güncellendi ✓');
      setEditing(null);
    } catch (err) {
      show(err.message, 'err');
    } finally {
      setLoading(false);
    }
  }

  async function toggleActive(bank) {
    try {
      const fn = httpsCallable(functions, 'adminUpsertBank');
      await fn({ bank_id: bank.id, is_active: !bank.is_active });
      show(bank.is_active ? 'Banka devre dışı bırakıldı' : 'Banka aktifleştirildi');
    } catch (err) {
      show(err.message, 'err');
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 800 }}>🏦 Banka Yönetimi</h1>
          <p style={{ color: 'var(--muted)', fontSize: 13, marginTop: 4 }}>
            Aktif bankalar, çalışan sayısı filtresi ve itiraz dondurma
          </p>
        </div>
        <button className="btn-primary" onClick={startNew}>+ Yeni Banka</button>
      </div>

      {editing && (
        <div className="card" style={{ marginBottom: 24, maxWidth: 540 }}>
          <div className="card-title">{editing === '__new__' ? 'Yeni Banka Ekle' : 'Banka Düzenle'}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label>Banka ID (benzersiz, değiştirilemez)</label>
              <input
                value={form.bank_id} disabled={editing !== '__new__'}
                onChange={e => setForm(f => ({ ...f, bank_id: e.target.value.toLowerCase().replace(/\s/g, '_') }))}
                placeholder="akbank"
              />
            </div>
            <div>
              <label>Görünen Ad</label>
              <input value={form.display_name} onChange={e => setForm(f => ({ ...f, display_name: e.target.value }))} placeholder="Akbank" />
            </div>
            <div>
              <label>Çalışan Sayısı (200+ filtresi için)</label>
              <input type="number" min={0} value={form.employee_count} onChange={e => setForm(f => ({ ...f, employee_count: Number(e.target.value) }))} />
            </div>
            <div>
              <label>Logo URL (isteğe bağlı)</label>
              <input value={form.logo_url} onChange={e => setForm(f => ({ ...f, logo_url: e.target.value }))} placeholder="https://…" />
            </div>
            <div className="toggle-wrap">
              <div className={`toggle ${form.is_active ? 'on' : ''}`} onClick={() => setForm(f => ({ ...f, is_active: !f.is_active }))} />
              <span style={{ fontSize: 13 }}>Aktif</span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <button className="btn-primary" onClick={save} disabled={loading}>
              {loading ? 'Kaydediliyor…' : 'Kaydet'}
            </button>
            <button className="btn-ghost" onClick={() => setEditing(null)}>İptal</button>
          </div>
        </div>
      )}

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>Banka ID</th><th>Görünen Ad</th><th>Çalışan</th><th>Durum</th><th></th>
            </tr>
          </thead>
          <tbody>
            {banks.map(b => (
              <tr key={b.id}>
                <td><code style={{ fontSize: 12 }}>{b.id}</code></td>
                <td>{b.display_name || '—'}</td>
                <td>
                  {b.employee_count >= 200
                    ? <span className="badge badge-green">{b.employee_count}</span>
                    : <span className="badge badge-red">{b.employee_count || 0} &lt;200</span>
                  }
                </td>
                <td>
                  <span className={`badge badge-${b.is_active !== false ? 'green' : 'red'}`}>
                    {b.is_active !== false ? 'Aktif' : 'Pasif'}
                  </span>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button className="btn-ghost btn-sm" onClick={() => startEdit(b)}>Düzenle</button>
                    <button className="btn-ghost btn-sm" onClick={() => toggleActive(b)}>
                      {b.is_active !== false ? 'Dondur' : 'Aktifleştir'}
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {banks.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center', color: 'var(--muted)' }}>Henüz banka yok</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {toast && <div className={`toast ${toast.type}`}>{toast.msg}</div>}
    </div>
  );
}
