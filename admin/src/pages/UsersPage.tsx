import { useState, useMemo } from 'react'
import { doc, updateDoc } from 'firebase/firestore'
import { db } from '../firebase'
import { useCollection, where, Timestamp } from '../hooks/useFirestore'
import { DataTable, Column } from '../components/DataTable'
import { useAuth } from '../hooks/useAuth'

// ── Types ────────────────────────────────────────────────────────────────────

interface UserDoc {
  id: string
  uid?: string
  displayName?: string
  role?: string
  companyId?: string
  department?: string
  created_at?: Timestamp
  updated_at?: Timestamp
  deleted?: boolean
  kvkk_accepted?: boolean
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function tsToString(ts: Timestamp | undefined): string {
  if (!ts) return '—'
  const d = ts.toDate ? ts.toDate() : new Date((ts as { seconds: number }).seconds * 1000)
  return d.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

const ROLE_BADGE: Record<string, string> = {
  free:       'bg-gray-100 text-gray-600',
  pro:        'bg-green-100 text-green-700',
  enterprise: 'bg-blue-100 text-blue-700',
  daas:       'bg-violet-100 text-violet-700',
  admin:      'bg-amber-100 text-amber-700',
}

function RoleBadge({ role }: { role?: string }) {
  const r = role ?? 'free'
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${ROLE_BADGE[r] ?? 'bg-gray-100 text-gray-600'}`}>
      {r}
    </span>
  )
}

const ROLES = ['free', 'pro', 'enterprise', 'daas']

// ── Modal: Change Role ────────────────────────────────────────────────────────

interface ChangeRoleModalProps {
  user: UserDoc
  onClose: () => void
  onSaved: () => void
}

function ChangeRoleModal({ user, onClose, onSaved }: ChangeRoleModalProps) {
  const [selectedRole, setSelectedRole] = useState(user.role ?? 'free')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleSave = async () => {
    setLoading(true)
    setError(null)
    try {
      await updateDoc(doc(db, 'users', user.id), { role: selectedRole })
      onSaved()
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
        <h2 className="text-base font-semibold text-gray-900 mb-4">Rol Değiştir</h2>
        <p className="text-sm text-gray-600 mb-4">
          Kullanıcı:{' '}
          <span className="font-mono text-xs text-gray-500">{user.id.slice(0, 12)}…</span>
        </p>
        <div className="space-y-2 mb-5">
          {ROLES.map((r) => (
            <label key={r} className="flex items-center gap-3 cursor-pointer">
              <input
                type="radio"
                name="role"
                value={r}
                checked={selectedRole === r}
                onChange={() => setSelectedRole(r)}
                className="accent-brand-600"
              />
              <RoleBadge role={r} />
            </label>
          ))}
        </div>
        {error && <p className="text-xs text-red-600 mb-3">{error}</p>}
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="btn-secondary text-sm py-1.5">İptal</button>
          <button onClick={handleSave} disabled={loading} className="btn-primary text-sm py-1.5 min-w-[80px]">
            {loading ? 'Kaydediliyor…' : 'Kaydet'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Modal: Delete Confirm ─────────────────────────────────────────────────────

interface DeleteModalProps {
  user: UserDoc
  onClose: () => void
  onDeleted: () => void
}

function DeleteModal({ user, onClose, onDeleted }: DeleteModalProps) {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleDelete = async () => {
    setLoading(true)
    setError(null)
    try {
      // Soft delete
      await updateDoc(doc(db, 'users', user.id), { deleted: true })
      onDeleted()
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
        <h2 className="text-base font-semibold text-gray-900 mb-2">Kullanıcıyı Sil</h2>
        <p className="text-sm text-gray-600 mb-5">
          <span className="font-mono text-xs text-gray-500">{user.id.slice(0, 12)}…</span>{' '}
          kullanıcısı soft-delete ile işaretlenecek. Bu işlem geri alınabilir.
        </p>
        {error && <p className="text-xs text-red-600 mb-3">{error}</p>}
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="btn-secondary text-sm py-1.5">İptal</button>
          <button onClick={handleDelete} disabled={loading} className="btn-danger text-sm py-1.5 min-w-[80px]">
            {loading ? 'Siliniyor…' : 'Sil'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Main Page ────────────────────────────────────────────────────────────────

export default function UsersPage() {
  useAuth() // ensure auth context is initialized
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState<string>('all')
  const [changeRoleUser, setChangeRoleUser] = useState<UserDoc | null>(null)
  const [deleteUser, setDeleteUser] = useState<UserDoc | null>(null)

  const { data: users, isLoading, refetch } = useCollection<UserDoc>(
    'users',
    // No orderBy('created_at'): Firestore's orderBy silently excludes docs that
    // lack the field, which hid most users (F-ADM2: 34 shown vs 399 real, since
    // older user docs have no created_at). Fetch all non-deleted users and sort
    // client-side instead — consistent with the Dashboard count.
    [where('deleted', '==', false)],
    ['users', 'table'],
  )

  // Filter
  const filtered = useMemo(() => {
    let list = users ?? []
    if (roleFilter !== 'all') list = list.filter((u) => u.role === roleFilter)
    if (search.trim()) {
      const q = search.trim().toLowerCase()
      list = list.filter(
        (u) =>
          u.id.toLowerCase().includes(q) ||
          u.displayName?.toLowerCase().includes(q) ||
          u.companyId?.toLowerCase().includes(q) ||
          u.department?.toLowerCase().includes(q),
      )
    }
    // Sort newest-first client-side; docs without created_at sort last.
    return [...list].sort(
      (a, b) => (b.created_at?.seconds ?? 0) - (a.created_at?.seconds ?? 0),
    )
  }, [users, roleFilter, search])

  const columns: Column<UserDoc>[] = [
    {
      key: 'id',
      header: 'UID',
      exportValue: (u) => u.id,
      render: (u) => (
        <span
          className="font-mono text-xs text-gray-500 cursor-pointer hover:text-gray-800"
          title={u.id}
          onClick={() => navigator.clipboard.writeText(u.id)}
        >
          {u.id.slice(0, 10)}…
        </span>
      ),
    },
    {
      key: 'displayName',
      header: 'Ad Soyad',
      sortable: true,
      exportValue: (u) => u.displayName ?? '',
      render: (u) => (
        <span className="text-sm font-medium text-gray-800">{u.displayName ?? '—'}</span>
      ),
    },
    {
      key: 'role',
      header: 'Rol',
      sortable: true,
      exportValue: (u) => u.role ?? 'free',
      render: (u) => <RoleBadge role={u.role} />,
    },
    {
      key: 'companyId',
      header: 'Şirket ID',
      exportValue: (u) => u.companyId ?? '',
      render: (u) =>
        u.companyId ? (
          <span className="font-mono text-xs text-gray-500" title={u.companyId}>
            {u.companyId.slice(0, 8)}…
          </span>
        ) : (
          <span className="text-gray-300">—</span>
        ),
    },
    {
      key: 'created_at',
      header: 'Oluşturulma',
      sortable: true,
      exportValue: (u) => tsToString(u.created_at),
      render: (u) => <span className="text-xs text-gray-500">{tsToString(u.created_at)}</span>,
    },
    {
      key: 'kvkk_accepted',
      header: 'KVKK',
      exportValue: (u) => u.kvkk_accepted ? 'Evet' : 'Hayır',
      render: (u) => (
        <span
          className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
            u.kvkk_accepted ? 'bg-green-50 text-green-700' : 'bg-gray-100 text-gray-500'
          }`}
        >
          {u.kvkk_accepted ? 'Evet' : 'Hayır'}
        </span>
      ),
    },
    {
      key: 'actions',
      header: 'İşlemler',
      render: (u) => (
        <div className="flex items-center gap-2">
          <button
            onClick={() => setChangeRoleUser(u)}
            className="text-xs text-brand-600 hover:text-brand-800 font-medium"
          >
            Rol Değiştir
          </button>
          <span className="text-gray-200">|</span>
          <button
            onClick={() => setDeleteUser(u)}
            className="text-xs text-red-500 hover:text-red-700 font-medium"
          >
            Sil
          </button>
        </div>
      ),
    },
  ]

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h1 className="text-xl font-bold text-gray-900">Kullanıcılar</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            {isLoading ? 'Yükleniyor…' : `${filtered.length} kullanıcı`}
          </p>
        </div>

        {/* Role filter */}
        <div className="flex items-center gap-2 flex-wrap">
          {(['all', ...ROLES] as const).map((r) => (
            <button
              key={r}
              onClick={() => setRoleFilter(r)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                roleFilter === r
                  ? 'bg-brand-600 text-white'
                  : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
              }`}
            >
              {r === 'all' ? 'Tümü' : r}
            </button>
          ))}
        </div>
      </div>

      <DataTable
        columns={columns}
        data={filtered}
        keyExtractor={(u) => u.id}
        loading={isLoading}
        emptyMessage="Kullanıcı bulunamadı."
        searchValue={search}
        onSearchChange={setSearch}
        searchPlaceholder="UID, ad, şirket ara…"
        exportFilename="pom-kullanicilar"
      />

      {/* Modals */}
      {changeRoleUser && (
        <ChangeRoleModal
          user={changeRoleUser}
          onClose={() => setChangeRoleUser(null)}
          onSaved={() => void refetch()}
        />
      )}
      {deleteUser && (
        <DeleteModal
          user={deleteUser}
          onClose={() => setDeleteUser(null)}
          onDeleted={() => void refetch()}
        />
      )}
    </div>
  )
}

