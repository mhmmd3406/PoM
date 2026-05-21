import { useMemo, useState } from 'react'
import {
  RadarChart, Radar, PolarGrid, PolarAngleAxis,
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, Cell,
  ResponsiveContainer,
} from 'recharts'
import { useCollection, Timestamp } from '../hooks/useFirestore'
import { Pagination } from '../components/Pagination'
import { exportToXlsx } from '../utils/exportXlsx'

// ── Types ────────────────────────────────────────────────────────────────────

interface CheckinDoc {
  id: string
  companyId?: string
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
  industry?: string
  plan?: string
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function avg(nums: number[]): number {
  if (!nums.length) return 0
  return nums.reduce((a, b) => a + b, 0) / nums.length
}

function toScore100(v: number): number {
  return Math.round(((v - 1) / 4) * 100)
}

const COMPANY_COLORS = ['#4F7CC4', '#6DAE7E', '#E8A03C', '#D67A6A', '#8B72BE']

const DIMS = [
  { key: 'overallMood',     label: 'Ruh Hali' },
  { key: 'workStress',      label: 'Stres' },
  { key: 'teamHarmony',     label: 'Takım' },
  { key: 'personalGrowth',  label: 'Gelişim' },
  { key: 'workLifeBalance', label: 'Denge' },
] as const

const PLAN_BADGE: Record<string, string> = {
  free:       'bg-gray-100 text-gray-600',
  pro:        'bg-green-100 text-green-700',
  enterprise: 'bg-blue-100 text-blue-700',
  daas:       'bg-violet-100 text-violet-700',
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function BenchmarkPage() {
  const [focusCompany, setFocusCompany] = useState<string | null>(null)
  const [page, setPage] = useState(0)
  const [pageSize, setPageSize] = useState(10)

  const thirtyDaysAgo = useMemo(
    () => Timestamp.fromDate(new Date(Date.now() - 30 * 86400_000)),
    [],
  )

  const { data: checkins, isLoading } = useCollection<CheckinDoc>(
    'checkins',
    [],
    ['checkins', 'benchmark'],
  )

  const { data: companies } = useCollection<CompanyDoc>(
    'companies',
    [],
    ['companies', 'benchmark'],
  )

  // ── Derived ──────────────────────────────────────────────────────────────────

  const recent = useMemo(() => {
    if (!checkins) return []
    const threshold = thirtyDaysAgo.toDate()
    return checkins.filter((c) => {
      const raw = c.created_at as { seconds?: number; toDate?: () => Date } | undefined
      const d = raw?.toDate ? raw.toDate() : raw?.seconds ? new Date(raw.seconds * 1000) : null
      return d && d >= threshold
    })
  }, [checkins, thirtyDaysAgo])

  type CompanyStats = {
    id: string
    name: string
    plan: string
    industry: string
    checkinCount: number
    overallMood: number
    workStress: number
    teamHarmony: number
    personalGrowth: number
    workLifeBalance: number
    avgScore: number
    score100: number
    rank: number
  }

  const companyStats: CompanyStats[] = useMemo(() => {
    if (!recent.length || !companies) return []

    const grouped: Record<string, CheckinDoc[]> = {}
    for (const c of recent) {
      if (!c.companyId) continue
      grouped[c.companyId] = grouped[c.companyId] ?? []
      grouped[c.companyId].push(c)
    }

    const stats = (companies ?? [])
      .filter((co) => grouped[co.id]?.length)
      .map((co) => {
        const cs = grouped[co.id]
        const mood    = avg(cs.map((x) => x.overallMood     ?? 0).filter(Boolean))
        const stress  = avg(cs.map((x) => x.workStress      ?? 0).filter(Boolean))
        const team    = avg(cs.map((x) => x.teamHarmony     ?? 0).filter(Boolean))
        const growth  = avg(cs.map((x) => x.personalGrowth  ?? 0).filter(Boolean))
        const balance = avg(cs.map((x) => x.workLifeBalance ?? 0).filter(Boolean))
        const a = avg([mood, stress, team, growth, balance])
        return {
          id: co.id,
          name: co.name ?? co.id,
          plan: co.plan ?? 'free',
          industry: co.industry ?? '—',
          checkinCount: cs.length,
          overallMood: mood,
          workStress: stress,
          teamHarmony: team,
          personalGrowth: growth,
          workLifeBalance: balance,
          avgScore: a,
          score100: toScore100(a),
          rank: 0,
        }
      })
      .sort((a, b) => b.avgScore - a.avgScore)
      .map((s, i) => ({ ...s, rank: i + 1 }))

    return stats
  }, [recent, companies])

  const platformAvg = useMemo(() => {
    if (!companyStats.length) return null
    return {
      overallMood:     avg(companyStats.map((s) => s.overallMood)),
      workStress:      avg(companyStats.map((s) => s.workStress)),
      teamHarmony:     avg(companyStats.map((s) => s.teamHarmony)),
      personalGrowth:  avg(companyStats.map((s) => s.personalGrowth)),
      workLifeBalance: avg(companyStats.map((s) => s.workLifeBalance)),
      avgScore:        avg(companyStats.map((s) => s.avgScore)),
      score100:        Math.round(avg(companyStats.map((s) => s.score100))),
    }
  }, [companyStats])

  const focused = focusCompany
    ? companyStats.find((s) => s.id === focusCompany) ?? null
    : null

  // Radar data: focused company vs platform average
  const radarData = useMemo(() => {
    if (!platformAvg) return []
    return DIMS.map((d) => ({
      dim: d.label,
      Platform: platformAvg[d.key as keyof typeof platformAvg] as number,
      ...(focused ? { [focused.name]: focused[d.key as keyof CompanyStats] as number } : {}),
    }))
  }, [platformAvg, focused])

  const pagedStats = useMemo(
    () => companyStats.slice(page * pageSize, (page + 1) * pageSize),
    [companyStats, page, pageSize],
  )

  // Bar chart: score per company
  const barData = useMemo(() =>
    companyStats.map((s, i) => ({ name: s.name, score: s.score100, fill: COMPANY_COLORS[i % COMPANY_COLORS.length] })),
    [companyStats],
  )

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-gray-900">Benchmark Analizi</h1>
        <p className="text-sm text-gray-500 mt-0.5">Şirketlerin son 30 günlük refah skorları ve platform ortalamasıyla karşılaştırma</p>
      </div>

      {/* Platform summary cards */}
      <div className="grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-5 gap-4">
        {DIMS.map((d) => {
          const val = platformAvg?.[d.key as keyof typeof platformAvg] as number | undefined
          return (
            <div key={d.key} className="card p-4">
              <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">{d.label}</p>
              <p className="text-2xl font-bold text-gray-900 mt-1 tabular-nums">
                {isLoading || val == null ? '—' : val.toFixed(2)}
              </p>
              <p className="text-xs text-gray-400 mt-0.5">platform ort. / 5</p>
            </div>
          )
        })}
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        {/* Scores bar chart */}
        <div className="card p-5">
          <h2 className="text-sm font-semibold text-gray-700 mb-4">Şirket Skor Sıralaması (0–100)</h2>
          {isLoading ? (
            <div className="h-48 bg-gray-100 rounded animate-pulse" />
          ) : (
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={barData} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="name" tick={{ fontSize: 11, fill: '#6b7280' }} tickLine={false} />
                <YAxis domain={[0, 100]} tick={{ fontSize: 10, fill: '#9ca3af' }} tickLine={false} axisLine={false} />
                <Tooltip
                  formatter={(v: number) => [`${v}`, 'Skor']}
                  contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e5e7eb' }}
                />
                <Bar dataKey="score" radius={[4, 4, 0, 0]}>
                  {barData.map((entry, i) => (
                    <Cell key={i} fill={entry.fill} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Radar: select company vs platform */}
        <div className="card p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-gray-700">Boyut Karşılaştırması</h2>
            <select
              value={focusCompany ?? ''}
              onChange={(e) => setFocusCompany(e.target.value || null)}
              className="text-xs border border-gray-200 rounded-lg px-2.5 py-1.5 bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-brand-500"
            >
              <option value="">Platform ortalaması</option>
              {companyStats.map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
          </div>
          {isLoading ? (
            <div className="h-48 bg-gray-100 rounded animate-pulse" />
          ) : (
            <ResponsiveContainer width="100%" height={220}>
              <RadarChart data={radarData} margin={{ top: 8, right: 24, bottom: 8, left: 24 }}>
                <PolarGrid stroke="#e5e7eb" />
                <PolarAngleAxis dataKey="dim" tick={{ fontSize: 11, fill: '#6b7280' }} />
                <Radar
                  name="Platform"
                  dataKey="Platform"
                  stroke="#94a3b8"
                  fill="#94a3b8"
                  fillOpacity={0.15}
                  strokeWidth={1.5}
                />
                {focused && (
                  <Radar
                    name={focused.name}
                    dataKey={focused.name}
                    stroke="#4F7CC4"
                    fill="#4F7CC4"
                    fillOpacity={0.25}
                    strokeWidth={2}
                  />
                )}
                <Legend iconSize={10} iconType="circle" wrapperStyle={{ fontSize: 11 }} />
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e5e7eb' }}
                  formatter={(v: number) => [v.toFixed(2), '']}
                />
              </RadarChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {/* Rankings table */}
      <div className="card overflow-hidden">
        <div className="px-5 py-4 border-b border-gray-100">
          <h2 className="text-sm font-semibold text-gray-700">Şirket Sıralama Tablosu</h2>
        </div>

        {isLoading ? (
          <div className="p-6 space-y-3">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="h-10 bg-gray-100 rounded animate-pulse" />
            ))}
          </div>
        ) : companyStats.length === 0 ? (
          <div className="p-10 text-center text-sm text-gray-400">Veri bulunamadı.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50">
                  <th className="text-left px-5 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide w-10">#</th>
                  <th className="text-left px-3 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Şirket</th>
                  <th className="text-left px-3 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Plan</th>
                  <th className="text-left px-3 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Sektör</th>
                  {DIMS.map((d) => (
                    <th key={d.key} className="text-center px-2 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">{d.label}</th>
                  ))}
                  <th className="text-center px-3 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Skor</th>
                  <th className="text-right px-5 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Check-in</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {/* Platform avg row */}
                {platformAvg && (
                  <tr className="bg-blue-50/60">
                    <td className="px-5 py-3 text-xs font-bold text-blue-400">~</td>
                    <td className="px-3 py-3 font-semibold text-blue-700 text-xs">Platform Ortalaması</td>
                    <td className="px-3 py-3" />
                    <td className="px-3 py-3" />
                    {DIMS.map((d) => (
                      <td key={d.key} className="px-2 py-3 text-center text-xs font-semibold tabular-nums text-blue-600">
                        {(platformAvg[d.key as keyof typeof platformAvg] as number).toFixed(2)}
                      </td>
                    ))}
                    <td className="px-3 py-3 text-center">
                      <span className="text-sm font-bold tabular-nums text-blue-700">{platformAvg.score100}</span>
                    </td>
                    <td className="px-5 py-3" />
                  </tr>
                )}

                {pagedStats.map((s, i) => (
                  <tr
                    key={s.id}
                    className={`hover:bg-gray-50 transition-colors cursor-pointer ${focusCompany === s.id ? 'bg-brand-50/40' : ''}`}
                    onClick={() => setFocusCompany(focusCompany === s.id ? null : s.id)}
                  >
                    <td className="px-5 py-3.5">
                      <span
                        className={`text-sm font-bold tabular-nums ${
                          s.rank === 1 ? 'text-amber-500' : s.rank === 2 ? 'text-gray-400' : s.rank === 3 ? 'text-orange-400' : 'text-gray-400'
                        }`}
                      >
                        {s.rank}
                      </span>
                    </td>
                    <td className="px-3 py-3.5">
                      <div className="flex items-center gap-2">
                        <div
                          className="w-2.5 h-2.5 rounded-full flex-shrink-0"
                          style={{ backgroundColor: COMPANY_COLORS[i % COMPANY_COLORS.length] }}
                        />
                        <span className="font-medium text-gray-900">{s.name}</span>
                      </div>
                    </td>
                    <td className="px-3 py-3.5">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${PLAN_BADGE[s.plan] ?? 'bg-gray-100 text-gray-600'}`}>
                        {s.plan}
                      </span>
                    </td>
                    <td className="px-3 py-3.5 text-xs text-gray-500">{s.industry}</td>
                    {DIMS.map((d) => {
                      const val = s[d.key as keyof CompanyStats] as number
                      const platVal = platformAvg?.[d.key as keyof typeof platformAvg] as number | undefined
                      const diff = platVal != null ? val - platVal : 0
                      return (
                        <td key={d.key} className="px-2 py-3.5 text-center">
                          <div className="flex flex-col items-center gap-0.5">
                            <span className="text-xs font-semibold tabular-nums text-gray-700">{val.toFixed(1)}</span>
                            {platVal != null && (
                              <span className={`text-[10px] font-medium ${diff >= 0 ? 'text-emerald-600' : 'text-red-500'}`}>
                                {diff >= 0 ? '+' : ''}{diff.toFixed(1)}
                              </span>
                            )}
                          </div>
                        </td>
                      )
                    })}
                    <td className="px-3 py-3.5 text-center">
                      <div className="flex items-center justify-center gap-1.5">
                        <div className="w-12 h-1.5 rounded-full bg-gray-100 overflow-hidden">
                          <div
                            className="h-full rounded-full bg-brand-500 transition-all"
                            style={{ width: `${s.score100}%` }}
                          />
                        </div>
                        <span className="text-xs font-bold tabular-nums text-gray-700">{s.score100}</span>
                      </div>
                    </td>
                    <td className="px-5 py-3.5 text-right text-xs text-gray-500 tabular-nums">{s.checkinCount}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {!isLoading && companyStats.length > 0 && (
          <Pagination
            page={page}
            pageSize={pageSize}
            total={companyStats.length}
            onPageChange={setPage}
            onPageSizeChange={(s) => { setPageSize(s); setPage(0) }}
            onExport={() => exportToXlsx(
              companyStats.map((s) => ({
                Sıra: s.rank,
                Şirket: s.name,
                Plan: s.plan,
                Sektör: s.industry,
                'Ruh Hali': s.overallMood.toFixed(2),
                Stres: s.workStress.toFixed(2),
                Takım: s.teamHarmony.toFixed(2),
                Gelişim: s.personalGrowth.toFixed(2),
                Denge: s.workLifeBalance.toFixed(2),
                'Skor (0-100)': s.score100,
                'Check-in': s.checkinCount,
              })),
              'pom-benchmark',
            )}
          />
        )}
      </div>
    </div>
  )
}
