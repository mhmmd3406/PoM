import { NavLink, useNavigate } from 'react-router-dom';
import { signOut } from 'firebase/auth';
import { auth } from '../firebase.js';

const NAV = [
  { to: '/',              label: '⬡ Dashboard'      },
  { to: '/thresholds',   label: '⚖ Eşikler'         },
  { to: '/legal',        label: '📄 Hukuki Metinler' },
  { to: '/banks',        label: '🏦 Bankalar'        },
  { to: '/disputes',     label: '📬 İtirazlar'       },
  { to: '/flags',        label: '🚩 Feature Flags'   },
  { to: '/announcements',label: '📢 Duyurular'       },
];

export default function Layout({ children, user }) {
  const navigate = useNavigate();

  async function handleSignOut() {
    await signOut(auth);
    navigate('/login');
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh' }}>
      {/* Sidebar */}
      <aside style={{
        width: 220, background: 'var(--bg2)',
        borderRight: '1px solid var(--border)',
        display: 'flex', flexDirection: 'column',
        padding: '24px 0', flexShrink: 0,
      }}>
        <div style={{ padding: '0 20px 24px', borderBottom: '1px solid var(--border)' }}>
          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--accent2)' }}>PoM Admin</div>
          <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 2 }}>{user?.email}</div>
        </div>

        <nav style={{ flex: 1, padding: '12px 12px' }}>
          {NAV.map(({ to, label }) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              style={({ isActive }) => ({
                display: 'block',
                padding: '9px 12px',
                borderRadius: 8,
                marginBottom: 2,
                color: isActive ? '#fff' : 'var(--muted)',
                background: isActive ? 'var(--accent)' : 'transparent',
                fontWeight: isActive ? 600 : 400,
                fontSize: 13,
                textDecoration: 'none',
                transition: 'background 0.15s',
              })}
            >
              {label}
            </NavLink>
          ))}
        </nav>

        <div style={{ padding: '12px 20px', borderTop: '1px solid var(--border)' }}>
          <button className="btn-ghost btn-sm" style={{ width: '100%' }} onClick={handleSignOut}>
            Çıkış Yap
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main style={{ flex: 1, padding: 32, overflowY: 'auto' }}>
        {children}
      </main>
    </div>
  );
}
