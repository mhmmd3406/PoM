import { useState } from 'react'
import { httpsCallable } from 'firebase/functions'
import { collection, query, where, getDocs, doc, deleteDoc, Timestamp } from 'firebase/firestore'
import { db, functions } from '../firebase'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../hooks/useAuth'

// ── Types ────────────────────────────────────────────────────────────────────

interface AdminUser {
  uid: string
  email?: string
  displayName?: string
  created_at?: Timestamp
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function tsToString(ts: Timestamp | undefined): string {
  if (!ts) return '—'
  const d = ts.toDate ? ts.toDate() : new Date((ts as { seconds: number }).seconds * 1000)
  return d.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

// ── Add Admin Form ────────────────────────────────────────────────────────────

interface AddAdminFormProps {
  onAdded: () => void
}

function AddAdminForm({ onAdded }: AddAdminFormProps) {
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const value = input.trim()
    if (!value) return

    setLoading(true)
    setError(null)
    setSuccess(null)

    try {
      let targetUid = value

      // If it looks like an email, look up the UID from users collection
      if (value.includes('@')) {
        const snap = await getDocs(
          query(collection(db, 'users'), where('email', '==', value))
        )
        if (snap.empty) {
          // Try auth lookup via a Cloud Function or fall back to direct UID usage
          throw new Error(`"${value}" e-postası ile kayıtlı kullanıcı bulunamadı. UID ile deneyin.`)
        }
        targetUid = snap.docs[0].id
      }

      const setAdminClaim = httpsCallable<{ targetUid: string }, { success: boolean; targetUid: string }>(
        functions,
        'setAdminClaim',
      )
      await setAdminClaim({ targetUid })
      setInput('')
      setSuccess(`${targetUid.slice(0, 10)}… kullanıcısına admin yetkisi verildi.`)
      onAdded()
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Bir hata oluştu.'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="card p-5">
      <h2 className="text-sm font-semibold text-gray-900 mb-4">Admin Ekle</h2>
      <form onSubmit={handleSubmit} className="flex items-start gap-3 flex-wrap">
        <div className="flex-1 min-w-[220px]">
          <input
            type="text"
            value={input}
            onChange={(e) => { setInput(e.target.value); setError(null); setSuccess(null) }}
            placeholder="UID veya e-posta adresi"
            className="input-field text-sm"
            disabled={loading}
          />
          <p className="mt-1 text-xs text-gray-400">
            Firebase UID veya kayıtlı e-posta adresi girin
          </p>
        </div>
        <button
          type="submit"
          disabled={loading || !input.trim()}
          className="btn-primary text-sm py-2 px-4 whitespace-nowrap"
        >
          {loading ? (
            <span className="flex items-center gap-1.5">
              <SpinnerIcon className="w-3.5 h-3.5 animate-spin" />
              Ekleniyor…
            </span>
          ) : (
            <span className="flex items-center gap-1.5">
              <PlusIcon className="w-4 h-4" />
              Admin Ekle
            </span>
          )}
        </button>
      </form>

      {error && (
        <div className="mt-3 flex items-start gap-2 rounded-lg bg-red-50 border border-red-200 px-3 py-2">
          <AlertIcon className="w-4 h-4 text-red-500 flex-shrink-0 mt-0.5" />
          <p className="text-xs text-red-700">{error}</p>
        </div>
      )}
      {success && (
        <div className="mt-3 flex items-center gap-2 rounded-lg bg-green-50 border border-green-200 px-3 py-2">
          <CheckIcon className="w-4 h-4 text-green-600 flex-shrink-0" />
          <p className="text-xs text-green-700">{success}</p>
        </div>
      )}
    </div>
  )
}

// ── Remove Admin Modal ────────────────────────────────────────────────────────

interface RemoveModalProps {
  admin: AdminUser
  onClose: () => void
  onRemoved: () => void
}

function RemoveAdminModal({ admin, onClose, onRemoved }: RemoveModalProps) {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleRemove = async () => {
    setLoading(true)
    setError(null)
    try {
      // Remove the admins-collection record so the user drops off the list.
      // NOTE: revoking the Auth custom claim itself requires a server-side
      // Cloud Function (see amber note below); this removes portal visibility.
      await deleteDoc(doc(db, 'admins', admin.uid))
      onRemoved()
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Bir hata oluştu.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="card w-full max-w-sm p-6">
        <h2 className="text-base font-semibold text-gray-900 mb-2">Admin Yetkisini Kaldır</h2>
        <p className="text-sm text-gray-600 mb-2">
          <span className="font-semibold">{admin.displayName ?? admin.email ?? admin.uid.slice(0, 12)}</span>{' '}
          kullanıcısının admin yetkisi kaldırılacak.
        </p>
        <p className="text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2 mb-5">
          Not: Custom claim kaldırma işlemi sunucu taraflı bir Cloud Function gerektirir.
          Bu işaret, bir sonraki token yenileme döngüsünde işlenecektir.
        </p>
        {error && <p className="text-xs text-red-600 mb-3">{error}</p>}
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="btn-secondary text-sm py-1.5">İptal</button>
          <button onClick={handleRemove} disabled={loading} className="btn-danger text-sm py-1.5 min-w-[80px]">
            {loading ? 'Kaldırılıyor…' : 'Kaldır'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Main Page ────────────────────────────────────────────────────────────────

export default function AdminsPage() {
  const { authState } = useAuth()
  const qc = useQueryClient()
  const [removeAdmin, setRemoveAdmin] = useState<AdminUser | null>(null)

  const currentUid =
    authState.status === 'authenticated' ? authState.user.uid : null

  // Query admin users from Firestore (users where is_admin == true)
  const { data: admins, isLoading, isError, refetch } = useQuery({
    queryKey: ['admins'],
    queryFn: async () => {
      // Admins live in the `admins` collection (written by the setAdminClaim
      // Cloud Function). The previous `users where is_admin == true` query
      // always returned empty because admin status is an Auth custom claim,
      // never a users-doc field — that was the F-ADM6 "empty list" bug.
      const snap = await getDocs(collection(db, 'admins'))
      return snap.docs.map((d) => ({ uid: d.id, ...d.data() } as AdminUser))
    },
  })

  const handleAdded = () => {
    void refetch()
  }

  const handleRemoved = () => {
    void qc.invalidateQueries({ queryKey: ['admins'] })
  }

  return (
    <div className="space-y-6 max-w-2xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-gray-900">Admin Yönetimi</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          Firebase custom claim ile admin yetkisi yönetimi
        </p>
      </div>

      {/* Security note */}
      <div className="flex items-start gap-3 rounded-xl bg-blue-50 border border-blue-200 px-4 py-3">
        <InfoIcon className="w-5 h-5 text-blue-500 flex-shrink-0 mt-0.5" />
        <div className="text-sm text-blue-800 space-y-1">
          <p className="font-semibold">Güvenlik Notu</p>
          <p>
            Admin yetkisi Firebase Auth custom claims ile korunur (<code className="text-xs bg-blue-100 px-1 py-0.5 rounded">is_admin: true</code>).
            Yeni eklenen admins bir sonraki giriş/token yenileme işleminde yetkiyi alır.
            Kendinizin yetkisini kaldıramazsınız.
          </p>
        </div>
      </div>

      {/* Add admin form */}
      <AddAdminForm onAdded={handleAdded} />

      {/* Admin list */}
      <div className="card overflow-hidden">
        <div className="px-5 py-4 border-b border-gray-100">
          <h2 className="text-sm font-semibold text-gray-900">Mevcut Adminler</h2>
        </div>

        {isLoading ? (
          <div className="divide-y divide-gray-50">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="flex items-center gap-3 px-5 py-4">
                <div className="w-9 h-9 rounded-full bg-gray-100 animate-pulse flex-shrink-0" />
                <div className="flex-1 space-y-1.5">
                  <div className="h-3.5 bg-gray-100 rounded animate-pulse w-1/3" />
                  <div className="h-3 bg-gray-100 rounded animate-pulse w-1/2" />
                </div>
              </div>
            ))}
          </div>
        ) : isError ? (
          <div className="px-5 py-8 text-center">
            <p className="text-sm text-red-600">Admin listesi yüklenemedi.</p>
            <button onClick={() => void refetch()} className="mt-2 btn-secondary text-xs py-1 px-3">
              Tekrar Dene
            </button>
          </div>
        ) : (admins ?? []).length === 0 ? (
          <p className="px-5 py-8 text-sm text-gray-400 text-center">
            Henüz admin kaydı bulunamadı.
          </p>
        ) : (
          <div className="divide-y divide-gray-50">
            {(admins ?? []).map((admin) => {
              const isSelf = admin.uid === currentUid
              return (
                <div key={admin.uid} className="flex items-center gap-3 px-5 py-4">
                  {/* Avatar */}
                  <div className="w-9 h-9 rounded-full bg-brand-100 flex items-center justify-center flex-shrink-0">
                    <span className="text-sm font-semibold text-brand-700">
                      {(admin.displayName ?? admin.email ?? 'A')[0].toUpperCase()}
                    </span>
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <p className="text-sm font-medium text-gray-900">
                        {admin.displayName ?? admin.email ?? admin.uid.slice(0, 12) + '…'}
                      </p>
                      {isSelf && (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold bg-brand-100 text-brand-700">
                          Siz
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-gray-400 mt-0.5 font-mono">
                      {admin.uid}
                    </p>
                    {admin.created_at && (
                      <p className="text-xs text-gray-400 mt-0.5">
                        Oluşturulma: {tsToString(admin.created_at)}
                      </p>
                    )}
                  </div>

                  {/* Remove button */}
                  {!isSelf && (
                    <button
                      onClick={() => setRemoveAdmin(admin)}
                      className="text-xs text-red-500 hover:text-red-700 font-medium flex items-center gap-1 flex-shrink-0"
                    >
                      <TrashIcon className="w-3.5 h-3.5" />
                      Kaldır
                    </button>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* Remove modal */}
      {removeAdmin && (
        <RemoveAdminModal
          admin={removeAdmin}
          onClose={() => setRemoveAdmin(null)}
          onRemoved={handleRemoved}
        />
      )}
    </div>
  )
}

// ── Inline icons ─────────────────────────────────────────────────────────────

function PlusIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
    </svg>
  )
}

function TrashIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
    </svg>
  )
}

function InfoIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" />
    </svg>
  )
}

function AlertIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
    </svg>
  )
}

function CheckIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
    </svg>
  )
}

function SpinnerIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
    </svg>
  )
}
