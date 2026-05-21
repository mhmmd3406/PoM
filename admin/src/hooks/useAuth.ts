// Re-export from the single AuthContext so all components share one auth state.
export { useAuth, AuthProvider } from '../contexts/AuthContext'
export type { UserRole, AuthState } from '../contexts/AuthContext'
