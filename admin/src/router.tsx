import { createBrowserRouter } from 'react-router-dom'
import { ProtectedRoute } from './components/ProtectedRoute'
import { Layout } from './components/Layout'
import LoginPage from './pages/LoginPage'
import DashboardPage from './pages/DashboardPage'
import UsersPage from './pages/UsersPage'
import ThresholdsPage from './pages/ThresholdsPage'
import CompaniesPage from './pages/CompaniesPage'
import SubscriptionsPage from './pages/SubscriptionsPage'
import AdminsPage from './pages/AdminsPage'
import DepartmentsPage from './pages/DepartmentsPage'
import BenchmarkPage from './pages/BenchmarkPage'
import PortalDashboardPage from './pages/portal/PortalDashboardPage'
import PortalSurveysPage from './pages/portal/PortalSurveysPage'
import PortalSurveyEditorPage from './pages/portal/PortalSurveyEditorPage'
import PortalSurveyResultsPage from './pages/portal/PortalSurveyResultsPage'

export const router = createBrowserRouter([
  {
    path: '/login',
    element: <LoginPage />,
  },

  // ── Super admin routes ────────────────────────────────────────────────────
  {
    element: (
      <ProtectedRoute allowedRoles={['super_admin']}>
        <Layout />
      </ProtectedRoute>
    ),
    children: [
      { path: '/',              element: <DashboardPage /> },
      { path: '/users',         element: <UsersPage /> },
      { path: '/thresholds',    element: <ThresholdsPage /> },
      { path: '/companies',     element: <CompaniesPage /> },
      { path: '/subscriptions', element: <SubscriptionsPage /> },
      { path: '/departments',   element: <DepartmentsPage /> },
      { path: '/benchmark',     element: <BenchmarkPage /> },
      { path: '/admins',        element: <AdminsPage /> },
    ],
  },

  // ── Company admin (portal) routes ─────────────────────────────────────────
  {
    element: (
      <ProtectedRoute allowedRoles={['company_admin']}>
        <Layout />
      </ProtectedRoute>
    ),
    children: [
      { path: '/portal',                     element: <PortalDashboardPage /> },
      { path: '/portal/surveys',             element: <PortalSurveysPage /> },
      { path: '/portal/surveys/new',         element: <PortalSurveyEditorPage /> },
      { path: '/portal/surveys/:id/edit',    element: <PortalSurveyEditorPage /> },
      { path: '/portal/surveys/:id/results', element: <PortalSurveyResultsPage /> },
    ],
  },
])
