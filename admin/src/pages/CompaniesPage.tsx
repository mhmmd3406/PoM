import { useState, useMemo } from 'react'
import { useCollection, Timestamp } from '../hooks/useFirestore'
import { DataTable, Column } from '../components/DataTable'

// ── Types ────────────────────────────────────────────────────────────────────

interface CompanyDoc {
  id: string
  name?: string
  plan?: string
  industry?: string
  employee_count?: number
  contact_email?: string
  created_at?: Timestamp
  active?: boolean
  /** True when synthesized from users data because no companies/{id} doc exists. */
  _derived?: boolean
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function tsToString(ts: Timestamp | undefined): string {
  if (!ts) return '—'
  const d = ts.toDate ? ts.toDate() : new Date((ts as { seconds: number }).seconds * 1000)
  return d.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

/** Turn a companyId like "garanti_bbva" into a readable "Garanti Bbva". */
function prettifyCompanyId(id: string): string {
  return id.replace(/[_-]+/g, ' ').replace(/\b\w/g, (m) => m.toUpperCase())
}

const PLAN_BADGE: Record<string, string> = {
  free:       'bg-gray-100 text-gray-600',
  pro:        'bg-green-100 text-green-700',
  enterprise: 'bg-blue-100 text-blue-700',
  daas:       'bg-violet-100 text-violet-700',
}

function PlanBadge({ plan }: { plan?: string }) {
  const p = plan ?? 'free'
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${PLAN_BADGE[p] ?? 'bg-gray-100 text-gray-600'}`}>
      {p}
    </span>
  )
}

// ── Detail Modal ──────────────────────────────────────────────────────────────

interface DetailModalProps {
  company: CompanyDoc
  userCount: number
  onClose: () => void
}

function DetailModal({ company, userCount, onClose }: DetailModalProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="card w-full max-w-md p-6">
        <div className="flex items-start justify-between mb-4">
          <h2 className="text-base font-semibold text-gray-900">{company.name ?? company.id}</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <XIcon className="w-5 h-5" />
          </button>
        </div>

        <dl className="space-y-3 text-sm">
          <div className="flex justify-between border-b border-gray-50 pb-2">
            <dt className="text-gray-500">Şirket ID</dt>
            <dd className="font-mono text-xs text-gray-600 max-w-[200px] truncate">{company.id}</dd>
          </div>
          <div className="flex justify-between border-b border-gray-50 pb-2">
            <dt className="text-gray-500">Plan</dt>
            <dd><PlanBadge plan={company.plan} /></dd>
          </div>
          <div className="flex justify-between border-b border-gray-50 pb-2">
            <dt className="text-gray-500">Sektör</dt>
            <dd className="text-gray-700">{company.industry ?? '—'}</dd>
          </div>
          <div className="flex justify-between border-b border-gray-50 pb-2">
            <dt className="text-gray-500">Çalışan Sayısı</dt>
            <dd className="text-gray-700 tabular-nums">{company.employee_count?.toLocaleString('tr-TR') ?? '—'}</dd>
          </div>
          <div className="flex justify-between border-b border-gray-50 pb-2">
            <dt className="text-gray-500">Kayıtlı Kullanıcı</dt>
            <dd className="text-gray-700 tabular-nums font-semibold">{userCount}</dd>
          </div>
          <div className="flex justify-between border-b border-gray-50 pb-2">
            <dt className="text-gray-500">İletişim E-posta</dt>
            <dd className="text-gray-700">{company.contact_email ?? '—'}</dd>
          </div>
          <div className="flex justify-between border-b border-gray-50 pb-2">
            <dt className="text-gray-500">Oluşturulma</dt>
            <dd className="text-gray-700">{tsToString(company.created_at)}</dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-gray-500">Durum</dt>
            <dd>
              <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                company.active !== false ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-600'
              }`}>
                {company.active !== false ? 'Aktif' : 'Pasif'}
              </span>
            </dd>
          </div>
        </dl>

        <div className="mt-5 flex justify-end">
          <button onClick={onClose} className="btn-secondary text-sm py-1.5 px-4">Kapat</button>
        </div>
      </div>
    </div>
  )
}

// ── Main Page ────────────────────────────────────────────────────────────────

export default function CompaniesPage() {
  const [search, setSearch] = useState('')
  const [planFilter, setPlanFilter] = useState<string>('all')
  const [detailCompany, setDetailCompany] = useState<CompanyDoc | null>(null)

  const { data: companyDocs, isLoading } = useCollection<CompanyDoc>(
    'companies',
    // No orderBy('created_at'): Firestore's orderBy silently excludes docs that
    // lack the field. Sort client-side instead (see `filtered`).
    [],
    ['companies', 'table'],
  )

  const { data: users } = useCollection<{ id: string; companyId?: string }>(
    'users',
    [],
    ['users', 'companyCount'],
  )

  // Count users per company
  const userCountMap = useMemo(() => {
    const map: Record<string, number> = {}
    for (const u of users ?? []) {
      if (u.companyId) map[u.companyId] = (map[u.companyId] ?? 0) + 1
    }
    return map
  }, [users])

  // Merge the companies collection with company IDs that appear on user docs.
  // Several companies exist only as a companyId on users/checkins with no
  // companies/{id} document (F-ADM3: page showed 5/10). Synthesize entries for
  // those so every active company is listed; they are flagged _derived so the
  // admin can see which still need a real company record (or a backfill).
  const companies = useMemo<CompanyDoc[]>(() => {
    const byId = new Map<string, CompanyDoc>()
    for (const c of companyDocs ?? []) byId.set(c.id, c)
    for (const u of users ?? []) {
      const cid = u.companyId
      if (cid && !byId.has(cid)) {
        byId.set(cid, { id: cid, name: prettifyCompanyId(cid), _derived: true })
      }
    }
    return Array.from(byId.values())
  }, [companyDocs, users])

  const plans = useMemo(() => {
    const set = new Set<string>()
    for (const c of companies) if (c.plan) set.add(c.plan)
    return Array.from(set)
  }, [companies])

  const filtered = useMemo(() => {
    let list = companies
    if (planFilter !== 'all') list = list.filter((c) => c.plan === planFilter)
    if (search.trim()) {
      const q = search.trim().toLowerCase()
      list = list.filter(
        (c) =>
          c.id.toLowerCase().includes(q) ||
          c.name?.toLowerCase().includes(q) ||
          c.contact_email?.toLowerCase().includes(q) ||
          c.industry?.toLowerCase().includes(q),
      )
    }
    // Sort by created_at desc; derived entries (no created_at) sort last.
    return [...list].sort(
      (a, b) => (b.created_at?.seconds ?? 0) - (a.created_at?.seconds ?? 0),
    )
  }, [companies, planFilter, search])

  const columns: Column<CompanyDoc>[] = [
    {
      key: 'name',
      header: 'Şirket Adı',
      sortable: true,
      exportValue: (c) => c.name ?? c.id,
      render: (c) => (
        <div>
          <div className="flex items-center gap-1.5">
            <p className="text-sm font-medium text-gray-900">{c.name ?? '—'}</p>
            {c._derived && (
              <span
                className="inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-semibold bg-amber-50 text-amber-700"
                title="Bu şirketin Firestore companies kaydı yok — kullanıcı verisinden türetildi"
              >
                kayıt yok
              </span>
            )}
          </div>
          <p className="text-[11px] font-mono text-gray-400">{c.id.slice(0, 8)}…</p>
        </div>
      ),
    },
    {
      key: 'plan',
      header: 'Plan',
      sortable: true,
      exportValue: (c) => c.plan ?? 'free',
      render: (c) => <PlanBadge plan={c.plan} />,
    },
    {
      key: 'industry',
      header: 'Sektör',
      sortable: true,
      exportValue: (c) => c.industry ?? '',
      render: (c) => <span className="text-sm text-gray-600">{c.industry ?? '—'}</span>,
    },
    {
      key: 'userCount',
      header: 'Kullanıcı',
      exportValue: (c) => userCountMap[c.id] ?? 0,
      render: (c) => (
        <span className="text-sm font-semibold tabular-nums text-gray-800">
          {(userCountMap[c.id] ?? 0).toLocaleString('tr-TR')}
        </span>
      ),
    },
    {
      key: 'employee_count',
      header: 'Çalışan',
      sortable: true,
      exportValue: (c) => c.employee_count ?? '',
      render: (c) => (
        <span className="text-sm tabular-nums text-gray-600">
          {c.employee_count?.toLocaleString('tr-TR') ?? '—'}
        </span>
      ),
    },
    {
      key: 'created_at',
      header: 'Oluşturulma',
      sortable: true,
      exportValue: (c) => tsToString(c.created_at),
      render: (c) => <span className="text-xs text-gray-500">{tsToString(c.created_at)}</span>,
    },
    {
      key: 'active',
      header: 'Durum',
      exportValue: (c) => c.active !== false ? 'Aktif' : 'Pasif',
      render: (c) => (
        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
          c.active !== false ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-600'
        }`}>
          {c.active !== false ? 'Aktif' : 'Pasif'}
        </span>
      ),
    },
    {
      key: 'actions',
      header: '',
      render: (c) => (
        <button
          onClick={() => setDetailCompany(c)}
          className="text-xs text-brand-600 hover:text-brand-800 font-medium"
        >
          Detay
        </button>
      ),
    },
  ]

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h1 className="text-xl font-bold text-gray-900">Şirketler</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            {isLoading ? 'Yükleniyor…' : `${filtered.length} şirket`}
          </p>
        </div>

        {/* Plan filter */}
        <div className="flex items-center gap-2 flex-wrap">
          {(['all', ...plans]).map((p) => (
            <button
              key={p}
              onClick={() => setPlanFilter(p)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                planFilter === p
                  ? 'bg-brand-600 text-white'
                  : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
              }`}
            >
              {p === 'all' ? 'Tümü' : p}
            </button>
          ))}
        </div>
      </div>

      <DataTable
        columns={columns}
        data={filtered}
        keyExtractor={(c) => c.id}
        loading={isLoading}
        emptyMessage="Şirket bulunamadı."
        searchValue={search}
        onSearchChange={setSearch}
        searchPlaceholder="Şirket adı, ID ara…"
        exportFilename="pom-sirketler"
      />

      {detailCompany && (
        <DetailModal
          company={detailCompany}
          userCount={userCountMap[detailCompany.id] ?? 0}
          onClose={() => setDetailCompany(null)}
        />
      )}
    </div>
  )
}

function XIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18 18 6M6 6l12 12" />
    </svg>
  )
}
