import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useApiKey } from './api/client'
import LoginPage from './pages/LoginPage'
import Layout from './components/Layout'
import OverviewPage from './pages/OverviewPage'
import TrendsPage from './pages/TrendsPage'
import DepartmentsPage from './pages/DepartmentsPage'
import BenchmarkPage from './pages/BenchmarkPage'

function ProtectedRoutes() {
  return (
    <Layout>
      <Routes>
        <Route path="/overview" element={<OverviewPage />} />
        <Route path="/trends" element={<TrendsPage />} />
        <Route path="/departments" element={<DepartmentsPage />} />
        <Route path="/benchmark" element={<BenchmarkPage />} />
        <Route path="*" element={<Navigate to="/overview" replace />} />
      </Routes>
    </Layout>
  )
}

export default function App() {
  const { apiKey } = useApiKey()

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/*"
          element={apiKey ? <ProtectedRoutes /> : <Navigate to="/login" replace />}
        />
      </Routes>
    </BrowserRouter>
  )
}
