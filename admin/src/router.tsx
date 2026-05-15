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

export const router = createBrowserRouter([
  {
    path: '/login',
    element: <LoginPage />,
  },
  {
    element: (
      <ProtectedRoute>
        <Layout />
      </ProtectedRoute>
    ),
    children: [
      { path: '/',             element: <DashboardPage /> },
      { path: '/users',        element: <UsersPage /> },
      { path: '/thresholds',   element: <ThresholdsPage /> },
      { path: '/companies',    element: <CompaniesPage /> },
      { path: '/subscriptions',element: <SubscriptionsPage /> },
      { path: '/admins',       element: <AdminsPage /> },
    ],
  },
])
