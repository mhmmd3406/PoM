import { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'

interface Props {
  children: ReactNode
}

export function ProtectedRoute({ children }: Props) {
  const { authState } = useAuth()

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

  return <>{children}</>
}
