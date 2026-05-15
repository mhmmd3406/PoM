import { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../firebase.js';

export default function LoginPage() {
  const [email, setEmail]       = useState('');
  const [password, setPassword] = useState('');
  const [error, setError]       = useState('');
  const [loading, setLoading]   = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError(''); setLoading(true);
    try {
      const cred = await signInWithEmailAndPassword(auth, email, password);
      // Verify is_admin claim
      const token = await cred.user.getIdTokenResult();
      if (!token.claims.is_admin) {
        await auth.signOut();
        setError('Bu hesapta admin yetkisi yok.');
      }
    } catch (err) {
      setError('Giriş başarısız: ' + err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{
      minHeight: '100vh', display: 'flex',
      alignItems: 'center', justifyContent: 'center',
      background: 'var(--bg)',
    }}>
      <div className="card" style={{ width: 360 }}>
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={{ fontSize: 32, marginBottom: 8 }}>⬡</div>
          <div style={{ fontSize: 20, fontWeight: 800, color: 'var(--accent2)' }}>PoM Admin</div>
          <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 4 }}>
            Yalnızca yetkili yöneticiler giriş yapabilir
          </div>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div>
            <label>E-posta</label>
            <input
              type="email" value={email} autoComplete="username"
              onChange={e => setEmail(e.target.value)} required
            />
          </div>
          <div>
            <label>Şifre</label>
            <input
              type="password" value={password} autoComplete="current-password"
              onChange={e => setPassword(e.target.value)} required
            />
          </div>
          {error && (
            <div style={{ color: 'var(--negative)', fontSize: 12, textAlign: 'center' }}>
              {error}
            </div>
          )}
          <button type="submit" className="btn-primary" disabled={loading} style={{ marginTop: 4 }}>
            {loading ? 'Giriş yapılıyor…' : 'Giriş Yap'}
          </button>
        </form>
      </div>
    </div>
  );
}
