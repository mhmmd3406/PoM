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
import FeatureFlagsPage from './pages/FeatureFlagsPage'
import LegalTextsPage from './pages/LegalTextsPage'
import AnnouncementsPage from './pages/AnnouncementsPage'
import BanksPage from './pages/BanksPage'
import DisputesPage from './pages/DisputesPage'
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
      { path: '/',                        element: <DashboardPage /> },
      { path: '/users',                   element: <UsersPage /> },
      { path: '/thresholds',              element: <ThresholdsPage /> },
      { path: '/companies',               element: <CompaniesPage /> },
      { path: '/subscriptions',           element: <SubscriptionsPage /> },
      { path: '/departments',             element: <DepartmentsPage /> },
      { path: '/benchmark',               element: <BenchmarkPage /> },
      { path: '/banks',                   element: <BanksPage /> },
      { path: '/disputes',                element: <DisputesPage /> },
      { path: '/announcements',           element: <AnnouncementsPage /> },
      { path: '/feature-flags',           element: <FeatureFlagsPage /> },
      { path: '/legal-texts',             element: <LegalTextsPage /> },
      { path: '/admins',                  element: <AdminsPage /> },
      { path: '/surveys',                 element: <PortalSurveysPage /> },
      { path: '/surveys/new',             element: <PortalSurveyEditorPage /> },
      { path: '/surveys/:id/edit',        element: <PortalSurveyEditorPage /> },
      { path: '/surveys/:id/results',     element: <PortalSurveyResultsPage /> },
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
