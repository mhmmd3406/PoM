import { useState, useEffect } from 'react'
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  User,
} from 'firebase/auth'
import { auth } from '../firebase'

export type AuthState =
  | { status: 'loading' }
  | { status: 'unauthenticated' }
  | { status: 'authenticated'; user: User; isAdmin: true }
  | { status: 'unauthorized'; user: User }

export function useAuth() {
  const [authState, setAuthState] = useState<AuthState>({ status: 'loading' })

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setAuthState({ status: 'unauthenticated' })
        return
      }

      try {
        // Force refresh to get latest custom claims
        const tokenResult = await user.getIdTokenResult(true)
        const isAdmin = tokenResult.claims['is_admin'] === true

        if (isAdmin) {
          setAuthState({ status: 'authenticated', user, isAdmin: true })
        } else {
          // Signed in but not admin — sign out immediately
          await signOut(auth)
          setAuthState({ status: 'unauthorized', user })
        }
      } catch {
        setAuthState({ status: 'unauthenticated' })
      }
    })

    return unsubscribe
  }, [])

  // Auto-logout on token expiry: re-verify every 55 minutes
  useEffect(() => {
    if (authState.status !== 'authenticated') return

    const interval = setInterval(async () => {
      try {
        const tokenResult = await authState.user.getIdTokenResult(true)
        const isAdmin = tokenResult.claims['is_admin'] === true
        if (!isAdmin) {
          await signOut(auth)
        }
      } catch {
        await signOut(auth)
      }
    }, 55 * 60 * 1000)

    return () => clearInterval(interval)
  }, [authState])

  const login = async (email: string, password: string) => {
    const credential = await signInWithEmailAndPassword(auth, email, password)
    const tokenResult = await credential.user.getIdTokenResult(true)
    const isAdmin = tokenResult.claims['is_admin'] === true

    if (!isAdmin) {
      await signOut(auth)
      throw new Error('NOT_ADMIN')
    }

    return credential.user
  }

  const logout = () => signOut(auth)

  return { authState, login, logout }
}
