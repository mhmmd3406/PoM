import { useMemo, useState } from 'react'
import { useCollection, where, Timestamp } from '../hooks/useFirestore'
import { Pagination } from '../components/Pagination'
import { exportToXlsx } from '../utils/exportXlsx'

// ── Types ────────────────────────────────────────────────────────────────────

interface CheckinDoc {
  id: string
  userId?: string
  companyId?: string
  department?: string
  overallMood?: number
  workStress?: number
  teamHarmony?: number
  personalGrowth?: number
  workLifeBalance?: number
  created_at?: Timestamp
}

interface CompanyDoc {
  id: string
  name?: string
}

interface UserDoc {
  id: string
  companyId?: string
  department?: string
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function avg(nums: number[]): number {
  if (!nums.length) return 0
  return nums.reduce((a, b) => a + b, 0) / nums.length
}

function scoreColor(s: number): string {
  if (s >= 4.2) return 'bg-emerald-100 text-emerald-800'
  if (s >= 3.5) return 'bg-green-50 text-green-700'
  if (s >= 2.8) return 'bg-amber-50 text-amber-700'
  return 'bg-red-50 text-red-700'
}

function scoreBar(s: number): string {
  if (s >= 4.2) return 'bg-emerald-500'
  if (s >= 3.5) return 'bg-green-400'
  if (s >= 2.8) return 'bg-amber-400'
  return 'bg-red-400'
}

const DIMS = [
  { key: 'overallMood',     label: 'Ruh Hali' },
  { key: 'workStress',      label: 'Stres' },
  { key: 'teamHarmony',     label: 'Takım' },
  { key: 'personalGrowth',  label: 'Gelişim' },
  { key: 'workLifeBalance', label: 'Denge' },
] as const

// ── Component ─────────────────────────────────────────────────────────────────

export default function DepartmentsPage() {
  const [selectedCompany, setSelectedCompany] = useState<string>('all')
  const [sortBy, setSortBy] = useState<'dept' | 'score'>('score')
  const [page, setPage] = useState(0)
  const [pageSize, setPageSize] = useState(10)

  const thirtyDaysAgo = useMemo(
    () => Timestamp.fromDate(new Date(Date.now() - 30 * 86400_000)),
    [],
  )

  const { data: checkins, isLoading: checkinsLoading } = useCollection<CheckinDoc>(
    'checkins',
    [],
    ['checkins', 'departments'],
  )

  const { data: companies } = useCollection<CompanyDoc>(
    'companies',
    [],
    ['companies', 'departments'],
  )

  const { data: users } = useCollection<UserDoc>(
    'users',
    [where('deleted', '==', false)],
    ['users', 'departments'],
  )

  // ── Derived ──────────────────────────────────────────────────────────────────

  const companyMap = useMemo(() => {
    const m: Record<string, string> = {}
    for (const c of companies ?? []) m[c.id] = c.name ?? c.id
    return m
  }, [companies])

  const filtered = useMemo(() => {
    if (!checkins) return []
    return selectedCompany === 'all'
      ? checkins
      : checkins.filter((c) => c.companyId === selectedCompany)
  }, [checkins, selectedCompany])

  // Recent (last 30 days) subset
  const recent = useMemo(() => {
    const threshold = thirtyDaysAgo.toDate()
    return filtered.filter((c) => {
      const d = c.created_at?.toDate ? c.created_at.toDate()
        : c.created_at ? new Date((c.created_at as { seconds: number }).seconds * 1000) : null
      return d && d >= threshold
    })
  }, [filtered, thirtyDaysAgo])

  type DeptRow = {
    dept: string
    company: string
    checkinCount: number
    userCount: number
    overallMood: number
    workStress: number
    teamHarmony: number
    personalGrowth: number
    workLifeBalance: number
    avgScore: number
  }

  const rows: DeptRow[] = useMemo(() => {
    const map: Record<string, { company: string; c: CheckinDoc[] }> = {}

    for (const c of recent) {
      if (!c.department) continue
      const key = `${c.companyId ?? 'unknown'}||${c.department}`
      if (!map[key]) map[key] = { company: c.companyId ?? 'unknown', c: [] }
      map[key].c.push(c)
    }

    const usersByDept: Record<string, Set<string>> = {}
    for (const u of users ?? []) {
      if (!u.department || !u.companyId) continue
      if (selectedCompany !== 'all' && u.companyId !== selectedCompany) continue
      const key = `${u.companyId}||${u.department}`
      if (!usersByDept[key]) usersByDept[key] = new Set()
      if (u.id) usersByDept[key].add(u.id)
    }

    return Object.entries(map).map(([key, { company, c: cs }]) => {
      const dept = key.split('||')[1]
      const mood    = avg(cs.map((x) => x.overallMood    ?? 0).filter(Boolean))
      const stress  = avg(cs.map((x) => x.workStress     ?? 0).filter(Boolean))
      const team    = avg(cs.map((x) => x.teamHarmony    ?? 0).filter(Boolean))
      const growth  = avg(cs.map((x) => x.personalGrowth ?? 0).filter(Boolean))
      const balance = avg(cs.map((x) => x.workLifeBalance ?? 0).filter(Boolean))
      return {
        dept,
        company: companyMap[company] ?? company,
        checkinCount: cs.length,
        userCount: usersByDept[key]?.size ?? 0,
        overallMood: mood,
        workStress: stress,
        teamHarmony: team,
        personalGrowth: growth,
        workLifeBalance: balance,
        avgScore: avg([mood, stress, team, growth, balance]),
      }
    }).sort((a, b) =>
      sortBy === 'score' ? b.avgScore - a.avgScore : a.dept.localeCompare(b.dept),
    )
  }, [recent, users, selectedCompany, companyMap, sortBy])

  const loading = checkinsLoading

  const pagedRows = useMemo(
    () => rows.slice(page * pageSize, (page + 1) * pageSize),
    [rows, page, pageSize],
  )

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold text-gray-900">Departman Analizi</h1>
          <p className="text-sm text-gray-500 mt-0.5">Son 30 günlük check-in verileri, departman bazında</p>
        </div>

        <div className="flex items-center gap-2">
          {/* Company filter */}
          <select
            value={selectedCompany}
            onChange={(e) => setSelectedCompany(e.target.value)}
            className="text-sm border border-gray-200 rounded-lg px-3 py-2 bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-brand-500"
          >
            <option value="all">Tüm Şirketler</option>
            {(companies ?? []).map((c) => (
              <option key={c.id} value={c.id}>{c.name ?? c.id}</option>
            ))}
          </select>

          {/* Sort */}
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as 'dept' | 'score')}
            className="text-sm border border-gray-200 rounded-lg px-3 py-2 bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-brand-500"
          >
            <option value="score">Skora göre sırala</option>
            <option value="dept">Departmana göre sırala</option>
          </select>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: 'Departman', value: rows.length },
          { label: 'Check-in', value: rows.reduce((s, r) => s + r.checkinCount, 0) },
          { label: 'En İyi Skor', value: rows.length ? rows.reduce((a, b) => a.avgScore > b.avgScore ? a : b).avgScore.toFixed(2) : '—' },
          { label: 'En Düşük Skor', value: rows.length ? rows.reduce((a, b) => a.avgScore < b.avgScore ? a : b).avgScore.toFixed(2) : '—' },
        ].map(({ label, value }) => (
          <div key={label} className="card p-4">
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">{label}</p>
            <p className="text-2xl font-bold text-gray-900 mt-1">{loading ? '—' : value}</p>
          </div>
        ))}
      </div>

      {/* Heatmap table */}
      <div className="card overflow-hidden">
        <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-gray-700">Boyut Isı Haritası</h2>
          <span className="text-xs text-gray-400">Ort. skor / 5</span>
        </div>

        {loading ? (
          <div className="p-6 space-y-3">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="h-10 bg-gray-100 rounded animate-pulse" />
            ))}
          </div>
        ) : rows.length === 0 ? (
          <div className="p-10 text-center text-sm text-gray-400">Veri bulunamadı.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50">
                  <th className="text-left px-5 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide w-40">Departman</th>
                  {selectedCompany === 'all' && (
                    <th className="text-left px-3 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Şirket</th>
                  )}
                  {DIMS.map((d) => (
                    <th key={d.key} className="text-center px-3 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">{d.label}</th>
                  ))}
                  <th className="text-center px-3 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Ort.</th>
                  <th className="text-right px-5 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Check-in</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {pagedRows.map((r) => (
                  <tr key={`${r.company}-${r.dept}`} className="hover:bg-gray-50 transition-colors">
                    <td className="px-5 py-3.5 font-medium text-gray-900">{r.dept}</td>
                    {selectedCompany === 'all' && (
                      <td className="px-3 py-3.5 text-gray-500 text-xs">{r.company}</td>
                    )}
                    {DIMS.map((d) => {
                      const val = r[d.key as keyof DeptRow] as number
                      return (
                        <td key={d.key} className="px-3 py-3.5 text-center">
                          <span className={`inline-block px-2 py-0.5 rounded-md text-xs font-semibold tabular-nums ${scoreColor(val)}`}>
                            {val.toFixed(1)}
                          </span>
                        </td>
                      )
                    })}
                    <td className="px-3 py-3.5 text-center">
                      <div className="flex items-center gap-2">
                        <div className="flex-1 h-1.5 rounded-full bg-gray-100 overflow-hidden min-w-[48px]">
                          <div
                            className={`h-full rounded-full ${scoreBar(r.avgScore)} transition-all duration-500`}
                            style={{ width: `${(r.avgScore / 5) * 100}%` }}
                          />
                        </div>
                        <span className="text-xs font-bold tabular-nums text-gray-700 w-8 text-right">
                          {r.avgScore.toFixed(1)}
                        </span>
                      </div>
                    </td>
                    <td className="px-5 py-3.5 text-right text-xs text-gray-500 tabular-nums">{r.checkinCount}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {!loading && rows.length > 0 && (
          <Pagination
            page={page}
            pageSize={pageSize}
            total={rows.length}
            onPageChange={setPage}
            onPageSizeChange={(s) => { setPageSize(s); setPage(0) }}
            onExport={() => exportToXlsx(
              rows.map((r) => ({
                Departman: r.dept,
                Şirket: r.company,
                'Ruh Hali': r.overallMood.toFixed(2),
                Stres: r.workStress.toFixed(2),
                Takım: r.teamHarmony.toFixed(2),
                Gelişim: r.personalGrowth.toFixed(2),
                Denge: r.workLifeBalance.toFixed(2),
                'Ort. Skor': r.avgScore.toFixed(2),
                'Check-in': r.checkinCount,
              })),
              'pom-departmanlar',
            )}
          />
        )}
      </div>

      {/* Legend */}
      <div className="flex flex-wrap items-center gap-4 text-xs text-gray-500">
        <span className="font-medium">Renk skalası:</span>
        {[
          { label: '≥ 4.2 Çok İyi', cls: 'bg-emerald-100 text-emerald-800' },
          { label: '≥ 3.5 İyi', cls: 'bg-green-50 text-green-700' },
          { label: '≥ 2.8 Orta', cls: 'bg-amber-50 text-amber-700' },
          { label: '< 2.8 Düşük', cls: 'bg-red-50 text-red-700' },
        ].map(({ label, cls }) => (
          <span key={label} className={`px-2 py-0.5 rounded-md font-semibold ${cls}`}>{label}</span>
        ))}
      </div>
    </div>
  )
}
