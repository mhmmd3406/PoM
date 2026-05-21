import { useEffect, ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { signOut } from 'firebase/auth'
import { auth } from '../firebase'
import { useAuth, UserRole } from '../hooks/useAuth'

interface Props {
  children: ReactNode
  allowedRoles?: UserRole[]
}

export function ProtectedRoute({ children, allowedRoles }: Props) {
  const { authState } = useAuth()

  // If the user has a Firebase Auth session but no valid role, sign them out
  // so they can log in fresh. Without this, they're stuck: the login page
  // calls signInWithEmailAndPassword which triggers a sign-out/sign-in pair,
  // and without clearing the session first the double-event can race.
  useEffect(() => {
    if (authState.status === 'unauthorized') {
      signOut(auth)
    }
  }, [authState.status])

  if (authState.status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-4 border-brand-600 border-t-transparent rounded-full animate-spin" />
          <p className="text-sm text-gray-500">Yükleniyor…</p>
        </div>
      </div>
    )
  }

  if (authState.status !== 'authenticated') {
    return <Navigate to="/login" replace />
  }

  if (allowedRoles && !allowedRoles.includes(authState.role)) {
    const home = authState.role === 'super_admin' ? '/' : '/portal'
    return <Navigate to={home} replace />
  }

  return <>{children}</>
}
