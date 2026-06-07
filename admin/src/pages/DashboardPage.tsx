import { useMemo, useState } from 'react'
import {
  LineChart, Line, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts'
import { useCollection, where, orderBy, limit, Timestamp } from '../hooks/useFirestore'
import { MetricCard } from '../components/MetricCard'
import { Pagination } from '../components/Pagination'
import { exportToXlsx } from '../utils/exportXlsx'

// ── Types ────────────────────────────────────────────────────────────────────

interface UserDoc {
  id: string
  role?: string
  companyId?: string
  created_at?: Timestamp
}

interface CheckinDoc {
  id: string
  userId?: string
  companyId?: string
  created_at?: Timestamp
  scores?: Record<string, number>
}

interface CompanyDoc {
  id: string
  name?: string
  plan?: string
}

// ── Palette ──────────────────────────────────────────────────────────────────

const ROLE_COLORS: Record<string, string> = {
  free: '#94a3b8',
  pro: '#22c55e',
  enterprise: '#3b82f6',
  daas: '#a855f7',
}

const PIE_COLORS = ['#16a34a', '#22c55e', '#4ade80', '#86efac', '#bbf7d0']

// ── Helpers ──────────────────────────────────────────────────────────────────

function tsToDate(ts: Timestamp | undefined): Date | null {
  if (!ts) return null
  return ts.toDate ? ts.toDate() : new Date((ts as { seconds: number }).seconds * 1000)
}

function formatDate(d: Date): string {
  return d.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit' })
}

function subtractDays(n: number): Date {
  const d = new Date()
  d.setDate(d.getDate() - n)
  d.setHours(0, 0, 0, 0)
  return d
}

// ── Component ────────────────────────────────────────────────────────────────

export default function DashboardPage() {
  const [activityPage, setActivityPage] = useState(0)
  const [activityPageSize, setActivityPageSize] = useState(10)

  // Data fetching
  const thirtyDaysAgo = useMemo(() => Timestamp.fromDate(subtractDays(30)), [])
  const sevenDaysAgo = useMemo(() => Timestamp.fromDate(subtractDays(7)), [])
  const todayStart = useMemo(() => Timestamp.fromDate(subtractDays(0)), [])

  const { data: allUsers, isLoading: usersLoading } = useCollection<UserDoc>(
    'users',
    [where('deleted', '==', false)],
    ['users', 'dashboard'],
  )

  const { data: recentCheckins, isLoading: checkinsLoading } = useCollection<CheckinDoc>(
    'checkins',
    [orderBy('created_at', 'desc'), limit(500)],
    ['checkins', 'dashboard'],
  )

  const { data: companies } = useCollection<CompanyDoc>(
    'companies',
    [],
    ['companies', 'dashboard'],
  )

  // ── Derived metrics ────────────────────────────────────────────────────────

  const totalUsers = allUsers?.length ?? 0

  const activeThisWeek = useMemo(() => {
    if (!recentCheckins) return 0
    const threshold = sevenDaysAgo.toDate()
    const uids = new Set<string>()
    for (const c of recentCheckins) {
      const d = tsToDate(c.created_at)
      if (d && d >= threshold && c.userId) uids.add(c.userId)
    }
    return uids.size
  }, [recentCheckins, sevenDaysAgo])

  const checkinsToday = useMemo(() => {
    if (!recentCheckins) return 0
    const threshold = todayStart.toDate()
    return recentCheckins.filter((c) => {
      const d = tsToDate(c.created_at)
      return d && d >= threshold
    }).length
  }, [recentCheckins, todayStart])

  // Daily check-ins over 30 days
  const dailyCheckinsData = useMemo(() => {
    const map: Record<string, number> = {}
    const days: string[] = []
    for (let i = 29; i >= 0; i--) {
      const d = subtractDays(i)
      const key = formatDate(d)
      map[key] = 0
      days.push(key)
    }

    if (recentCheckins) {
      const threshold = thirtyDaysAgo.toDate()
      for (const c of recentCheckins) {
        const d = tsToDate(c.created_at)
        if (d && d >= threshold) {
          const key = formatDate(d)
          if (key in map) map[key]++
        }
      }
    }

    return days.map((day) => ({ day, 'Check-in': map[day] }))
  }, [recentCheckins, thirtyDaysAgo])

  // Role distribution
  const roleData = useMemo(() => {
    const counts: Record<string, number> = {}
    for (const u of allUsers ?? []) {
      const r = u.role ?? 'free'
      counts[r] = (counts[r] ?? 0) + 1
    }
    return Object.entries(counts).map(([role, count]) => ({ role, count }))
  }, [allUsers])

  // Top companies by user count
  const companyPieData = useMemo(() => {
    const counts: Record<string, number> = {}
    for (const u of allUsers ?? []) {
      if (u.companyId) counts[u.companyId] = (counts[u.companyId] ?? 0) + 1
    }
    const companyMap: Record<string, string> = {}
    for (const c of companies ?? []) companyMap[c.id] = c.name ?? c.id

    return Object.entries(counts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([id, value]) => ({ name: companyMap[id] ?? id, value }))
  }, [allUsers, companies])

  const allActivity = useMemo(() => recentCheckins ?? [], [recentCheckins])
  const recentActivity = useMemo(
    () => allActivity.slice(activityPage * activityPageSize, (activityPage + 1) * activityPageSize),
    [allActivity, activityPage, activityPageSize],
  )

  const loading = usersLoading || checkinsLoading

  return (
    <div className="space-y-6">
      {/* Page header */}
      <div>
        <h1 className="text-xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-sm text-gray-500 mt-0.5">Platform geneli özet metrikleri</p>
      </div>

      {/* KPI cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <MetricCard
          title="Toplam Kullanıcı"
          value={totalUsers.toLocaleString('tr-TR')}
          icon={<UsersIcon className="w-5 h-5" />}
          loading={usersLoading}
          colorClass="bg-brand-50 text-brand-600"
        />
        <MetricCard
          title="Bu Hafta Aktif"
          value={activeThisWeek.toLocaleString('tr-TR')}
          subtitle="Son 7 gün"
          icon={<ActivityIcon className="w-5 h-5" />}
          loading={loading}
          colorClass="bg-blue-50 text-blue-600"
        />
        <MetricCard
          title="Bugünkü Check-in"
          value={checkinsToday.toLocaleString('tr-TR')}
          subtitle="Bugün"
          icon={<CheckInIcon className="w-5 h-5" />}
          loading={checkinsLoading}
          colorClass="bg-violet-50 text-violet-600"
        />
        <MetricCard
          title="Şirket Sayısı"
          value={(companies?.length ?? 0).toLocaleString('tr-TR')}
          icon={<BuildingIcon className="w-5 h-5" />}
          loading={!companies}
          colorClass="bg-amber-50 text-amber-600"
        />
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Daily check-ins line chart */}
        <div className="xl:col-span-2 card p-5">
          <h2 className="text-sm font-semibold text-gray-700 mb-4">Günlük Check-in (Son 30 Gün)</h2>
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={dailyCheckinsData} margin={{ top: 4, right: 16, bottom: 0, left: -10 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis
                dataKey="day"
                tick={{ fontSize: 10, fill: '#9ca3af' }}
                tickLine={false}
                interval={4}
              />
              <YAxis tick={{ fontSize: 10, fill: '#9ca3af' }} tickLine={false} axisLine={false} />
              <Tooltip
                contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e5e7eb' }}
                labelStyle={{ fontWeight: 600 }}
              />
              <Line
                type="monotone"
                dataKey="Check-in"
                stroke="#16a34a"
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Role distribution bar chart */}
        <div className="card p-5">
          <h2 className="text-sm font-semibold text-gray-700 mb-4">Rol Dağılımı</h2>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={roleData} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="role" tick={{ fontSize: 11, fill: '#9ca3af' }} tickLine={false} />
              <YAxis tick={{ fontSize: 10, fill: '#9ca3af' }} tickLine={false} axisLine={false} />
              <Tooltip
                contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e5e7eb' }}
              />
              <Bar dataKey="count" radius={[4, 4, 0, 0]} isAnimationActive={false}>
                {roleData.map((entry, index) => (
                  <Cell key={index} fill={ROLE_COLORS[entry.role] ?? '#94a3b8'} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Bottom row */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Company pie chart */}
        <div className="card p-5">
          <h2 className="text-sm font-semibold text-gray-700 mb-4">En Kalabalık Şirketler</h2>
          {companyPieData.length === 0 ? (
            <div className="flex items-center justify-center h-48 text-sm text-gray-400">
              Veri yok
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={companyPieData}
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={80}
                  paddingAngle={3}
                  dataKey="value"
                >
                  {companyPieData.map((_, index) => (
                    <Cell key={index} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e5e7eb' }}
                />
                <Legend
                  iconType="circle"
                  iconSize={8}
                  formatter={(v) => <span style={{ fontSize: 11, color: '#6b7280' }}>{v}</span>}
                />
              </PieChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Recent activity feed */}
        <div className="xl:col-span-2 card overflow-hidden">
          <div className="px-5 py-4 border-b border-gray-100">
            <h2 className="text-sm font-semibold text-gray-700">Son Aktiviteler</h2>
          </div>
          {checkinsLoading ? (
            <div className="p-5 space-y-3">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-gray-100 animate-pulse flex-shrink-0" />
                  <div className="flex-1 space-y-1">
                    <div className="h-3 bg-gray-100 rounded animate-pulse w-3/4" />
                    <div className="h-2.5 bg-gray-100 rounded animate-pulse w-1/2" />
                  </div>
                </div>
              ))}
            </div>
          ) : recentActivity.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">Henüz aktivite yok.</p>
          ) : (
            <div className="divide-y divide-gray-50 px-5">
              {recentActivity.map((c) => {
                const date = tsToDate(c.created_at)
                const scoreAvg = c.scores
                  ? Object.values(c.scores).reduce((s, v) => s + v, 0) / Object.values(c.scores).length
                  : null
                return (
                  <div key={c.id} className="flex items-center gap-3 py-2.5">
                    <div className="w-8 h-8 rounded-full bg-brand-100 flex items-center justify-center flex-shrink-0">
                      <CheckInIcon className="w-4 h-4 text-brand-600" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-gray-800 truncate">
                        <span className="font-mono text-xs text-gray-500">
                          {c.userId?.slice(0, 8) ?? '—'}…
                        </span>{' '}
                        check-in yaptı
                        {scoreAvg !== null && (
                          <span className="ml-1 text-xs text-gray-400">
                            (skor: {scoreAvg.toFixed(1)})
                          </span>
                        )}
                      </p>
                      <p className="text-xs text-gray-400">
                        {date ? date.toLocaleString('tr-TR') : '—'}
                        {c.companyId && (
                          <span className="ml-2 font-mono text-[10px]">{c.companyId.slice(0, 6)}…</span>
                        )}
                      </p>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
          {!checkinsLoading && (
            <Pagination
              page={activityPage}
              pageSize={activityPageSize}
              total={allActivity.length}
              onPageChange={setActivityPage}
              onPageSizeChange={(s) => { setActivityPageSize(s); setActivityPage(0) }}
              onExport={() => exportToXlsx(
                allActivity.map((c) => ({
                  'Kullanıcı ID': c.userId ?? '',
                  'Şirket ID': c.companyId ?? '',
                  'Skor Ort.': c.scores
                    ? (Object.values(c.scores).reduce((a, b) => a + b, 0) / Object.values(c.scores).length).toFixed(2)
                    : '',
                  'Tarih': tsToDate(c.created_at)?.toLocaleString('tr-TR') ?? '',
                })),
                'pom-aktiviteler',
              )}
            />
          )}
        </div>
      </div>
    </div>
  )
}

// ── Inline icons ─────────────────────────────────────────────────────────────

function UsersIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z" />
    </svg>
  )
}

function ActivityIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z" />
    </svg>
  )
}

function CheckInIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
    </svg>
  )
}

function BuildingIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />
    </svg>
  )
}
