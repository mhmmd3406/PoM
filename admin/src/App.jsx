import { useEffect, useState } from 'react';
import { Routes, Route, Navigate, useNavigate } from 'react-router-dom';
import { onAuthStateChanged } from 'firebase/auth';
import { auth } from './firebase.js';
import Layout from './components/Layout.jsx';
import LoginPage         from './pages/LoginPage.jsx';
import DashboardPage     from './pages/DashboardPage.jsx';
import ThresholdsPage    from './pages/ThresholdsPage.jsx';
import LegalTextsPage    from './pages/LegalTextsPage.jsx';
import BanksPage         from './pages/BanksPage.jsx';
import DisputesPage      from './pages/DisputesPage.jsx';
import FeatureFlagsPage  from './pages/FeatureFlagsPage.jsx';
import AnnouncementsPage from './pages/AnnouncementsPage.jsx';

function Spinner() {
  return (
    <div style={{ display:'flex', alignItems:'center', justifyContent:'center', height:'100vh' }}>
      <div style={{ color:'var(--muted)', fontSize:13 }}>Yükleniyor…</div>
    </div>
  );
}

export default function App() {
  const [user,    setUser]    = useState(undefined); // undefined = loading
  const [isAdmin, setIsAdmin] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      if (!u) { setUser(null); setIsAdmin(false); return; }
      const token = await u.getIdTokenResult();
      if (!token.claims.is_admin) {
        await auth.signOut();
        setUser(null); setIsAdmin(false);
        return;
      }
      setUser(u);
      setIsAdmin(true);
    });
    return unsub;
  }, []);

  if (user === undefined) return <Spinner />;

  if (!user || !isAdmin) {
    return (
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="*"      element={<Navigate to="/login" replace />} />
      </Routes>
    );
  }

  return (
    <Layout user={user}>
      <Routes>
        <Route path="/"              element={<DashboardPage />} />
        <Route path="/thresholds"    element={<ThresholdsPage />} />
        <Route path="/legal"         element={<LegalTextsPage />} />
        <Route path="/banks"         element={<BanksPage />} />
        <Route path="/disputes"      element={<DisputesPage />} />
        <Route path="/flags"         element={<FeatureFlagsPage />} />
        <Route path="/announcements" element={<AnnouncementsPage />} />
        <Route path="*"              element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  );
}
