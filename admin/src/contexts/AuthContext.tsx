import {
  createContext,
  useContext,
  useState,
  useEffect,
  useRef,
  ReactNode,
} from 'react'
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  User,
} from 'firebase/auth'
import { auth } from '../firebase'

// ── Types ─────────────────────────────────────────────────────────────────────

export type UserRole = 'super_admin' | 'company_admin'

export type AuthState =
  | { status: 'loading' }
  | { status: 'unauthenticated' }
  | { status: 'authenticated'; user: User; role: UserRole; companyId?: string }
  | { status: 'unauthorized'; user: User }

interface AuthContextValue {
  authState: AuthState
  login: (email: string, password: string) => Promise<{ role: UserRole; companyId?: string }>
  logout: () => Promise<void>
}

// ── Context ───────────────────────────────────────────────────────────────────

const AuthContext = createContext<AuthContextValue | null>(null)

// ── Helpers ───────────────────────────────────────────────────────────────────

async function resolveUserState(user: User): Promise<AuthState> {
  // Always force-refresh so we always have the latest custom claims.
  const tokenResult = await user.getIdTokenResult(true)
  const isAdmin        = tokenResult.claims['is_admin']      === true
  const isCompanyAdmin = tokenResult.claims['company_admin'] === true
  const companyId      = tokenResult.claims['company_id'] as string | undefined

  if (isAdmin)                       return { status: 'authenticated', user, role: 'super_admin' }
  if (isCompanyAdmin && companyId)   return { status: 'authenticated', user, role: 'company_admin', companyId }
  return { status: 'unauthorized', user }
}

// ── Provider ──────────────────────────────────────────────────────────────────

export function AuthProvider({ children }: { children: ReactNode }) {
  const [authState, setAuthState] = useState<AuthState>({ status: 'loading' })
  const loginInProgress = useRef(false)

  useEffect(() => {
    // unsubscribeFn must be in scope for the cleanup to reference it correctly.
    let unsubscribeFn: (() => void) | undefined

    // authStateReady() resolves once Firebase has loaded the persisted session.
    // We assign the unsubscribe inside the promise but the cleanup function
    // below calls it regardless of whether the promise has resolved yet.
    auth.authStateReady().then(() => {
      unsubscribeFn = onAuthStateChanged(auth, async (user) => {
        // IMPORTANT: this guard must come BEFORE the null-user check.
        // signInWithEmailAndPassword can fire two events: sign-out (null) then
        // sign-in. Without this guard the null event would set 'unauthenticated'
        // while login() is still running.
        if (loginInProgress.current) return

        if (!user) {
          setAuthState({ status: 'unauthenticated' })
          return
        }

        try {
          const next = await resolveUserState(user)
          setAuthState(next)
        } catch (err) {
          console.error('[Auth] token refresh failed', err)
          // Keep loading rather than kicking the user out on a network blip.
          // onAuthStateChanged will fire again if auth state actually changes.
        }
      })
    })

    // Cleanup: cancel the listener when AuthProvider unmounts.
    return () => { unsubscribeFn?.() }
  }, [])

  // Re-verify claims every 55 min while authenticated (token expiry safety net).
  useEffect(() => {
    if (authState.status !== 'authenticated') return
    const interval = setInterval(async () => {
      try {
        const next = await resolveUserState(authState.user)
        if (next.status !== 'authenticated') await signOut(auth)
      } catch {
        await signOut(auth)
      }
    }, 55 * 60 * 1000)
    return () => clearInterval(interval)
  }, [authState])

  const login = async (
    email: string,
    password: string,
  ): Promise<{ role: UserRole; companyId?: string }> => {
    loginInProgress.current = true
    try {
      const credential = await signInWithEmailAndPassword(auth, email, password)
      const next       = await resolveUserState(credential.user)

      if (next.status === 'authenticated') {
        setAuthState(next)
        return { role: next.role, companyId: next.companyId }
      }

      // Signed in but no valid role.
      await signOut(auth)
      throw new Error('NOT_ADMIN')
    } finally {
      loginInProgress.current = false
    }
  }

  const logout = () => signOut(auth)

  return (
    <AuthContext.Provider value={{ authState, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

// ── Hook ──────────────────────────────────────────────────────────────────────

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>')
  return ctx
}
