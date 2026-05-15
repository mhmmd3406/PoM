import { useEffect, useState } from 'react';
import { doc, onSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../firebase.js';
import { useToast } from '../hooks/useToast.js';

const TEXTS = [
  { key: 'kvkk',            label: 'KVKK Aydınlatma Metni',       required: true },
  { key: 'privacy_policy',  label: 'Gizlilik Politikası',          required: true },
  { key: 'terms_of_service',label: 'Kullanım Şartları',            required: true },
  { key: 'community_rules', label: 'Topluluk Kuralları',           required: false },
  { key: 'fraud_policy',    label: 'Sahte Veri Politikası',        required: false },
];

export default function LegalTextsPage() {
  const [data,    setData]    = useState({});
  const [active,  setActive]  = useState('kvkk');
  const [text,    setText]    = useState('');
  const [version, setVersion] = useState('');
  const [loading, setLoading] = useState(false);
  const { toast, show }       = useToast();

  useEffect(() => {
    const unsub = onSnapshot(doc(db, 'platform_config/legal_texts'), snap => {
      setData(snap.exists() ? snap.data() : {});
    });
    return unsub;
  }, []);

  useEffect(() => {
    setText(data[`${active}_text`] || '');
    setVersion(data[`${active}_version`] || '');
  }, [active, data]);

  async function save() {
    if (!text.trim()) return;
    setLoading(true);
    try {
      const newVersion = version || `${Date.now()}`;
      const fn = httpsCallable(functions, 'adminUpdateLegalText');
      await fn({ key: active, text, version: newVersion });
      show('Metin güncellendi — kullanıcılar yeni versiyonu onaylamak zorunda kalacak ✓');
    } catch (err) {
      show(err.message, 'err');
    } finally {
      setLoading(false);
    }
  }

  const cur = TEXTS.find(t => t.key === active);
  const updatedAt = data[`${active}_updated_at`]?.toDate?.()?.toLocaleDateString('tr-TR');

  return (
    <div>
      <h1 style={{ fontSize: 22, fontWeight: 800, marginBottom: 6 }}>📄 Hukuki Metinler</h1>
      <p style={{ color: 'var(--muted)', marginBottom: 24, fontSize: 13 }}>
        Bir metin güncellendiğinde, kayıtlı kullanıcılar uygulamada tekrar onay vermek zorunda kalır.
      </p>

      <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
        {TEXTS.map(t => (
          <button
            key={t.key}
            onClick={() => setActive(t.key)}
            className={active === t.key ? 'btn-primary btn-sm' : 'btn-ghost btn-sm'}
          >
            {t.label}
            {t.required && <span style={{ color: 'var(--negative)', marginLeft: 4 }}>*</span>}
          </button>
        ))}
      </div>

      <div className="card">
        <div className="card-title">
          {cur?.label}
          {version && <span className="badge badge-blue" style={{ marginLeft: 8 }}>v{version}</span>}
          {updatedAt && <span style={{ fontSize: 11, color: 'var(--muted)', marginLeft: 8 }}>— {updatedAt}</span>}
        </div>

        <div style={{ marginBottom: 14 }}>
          <label>Versiyon Etiketi (değişiklik sonrası otomatik güncellenir)</label>
          <input
            value={version}
            onChange={e => setVersion(e.target.value)}
            placeholder={`${Date.now()}`}
            style={{ maxWidth: 200 }}
          />
        </div>

        <div style={{ marginBottom: 16 }}>
          <label>Metin</label>
          <textarea
            value={text}
            onChange={e => setText(e.target.value)}
            placeholder="Metin buraya yazılır…"
            style={{ minHeight: 360 }}
          />
        </div>

        <div style={{ display: 'flex', gap: 12 }}>
          <button className="btn-primary" onClick={save} disabled={loading || !text.trim()}>
            {loading ? 'Kaydediliyor…' : 'Yayınla'}
          </button>
        </div>
      </div>

      {toast && <div className={`toast ${toast.type}`}>{toast.msg}</div>}
    </div>
  );
}
