import { useState, useMemo } from 'react'
import { useCollection, orderBy, Timestamp } from '../hooks/useFirestore'
import { DataTable, Column } from '../components/DataTable'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell,
} from 'recharts'

// ── Types ────────────────────────────────────────────────────────────────────

interface SubscriptionDoc {
  id: string
  userId?: string
  plan?: string
  status?: string
  stripe_customer_id?: string
  stripe_subscription_id?: string
  current_period_end?: Timestamp
  created_at?: Timestamp
  updated_at?: Timestamp
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function tsToString(ts: Timestamp | undefined): string {
  if (!ts) return '—'
  const d = ts.toDate ? ts.toDate() : new Date((ts as { seconds: number }).seconds * 1000)
  return d.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

const STATUS_BADGE: Record<string, string> = {
  active:   'bg-green-50 text-green-700',
  trialing: 'bg-blue-50 text-blue-700',
  past_due: 'bg-amber-50 text-amber-700',
  canceled: 'bg-red-50 text-red-600',
  inactive: 'bg-gray-100 text-gray-500',
}

const PLAN_COLORS: Record<string, string> = {
  free:       '#94a3b8',
  pro:        '#22c55e',
  enterprise: '#3b82f6',
  daas:       '#a855f7',
}

// ── Status badge component ────────────────────────────────────────────────────

function StatusBadge({ status }: { status?: string }) {
  const s = status ?? 'inactive'
  const STATUS_TR: Record<string, string> = {
    active:   'Aktif',
    trialing: 'Deneme',
    past_due: 'Gecikmiş',
    canceled: 'İptal',
    inactive: 'Pasif',
  }
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_BADGE[s] ?? 'bg-gray-100 text-gray-500'}`}>
      {STATUS_TR[s] ?? s}
    </span>
  )
}

function PlanBadge({ plan }: { plan?: string }) {
  const PLAN_BADGE: Record<string, string> = {
    free:       'bg-gray-100 text-gray-600',
    pro:        'bg-green-100 text-green-700',
    enterprise: 'bg-blue-100 text-blue-700',
    daas:       'bg-violet-100 text-violet-700',
  }
  const p = plan ?? 'free'
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${PLAN_BADGE[p] ?? 'bg-gray-100 text-gray-600'}`}>
      {p}
    </span>
  )
}

// ── Main Page ────────────────────────────────────────────────────────────────

export default function SubscriptionsPage() {
  const [search, setSearch] = useState('')
  const [planFilter, setPlanFilter] = useState<string>('all')
  const [statusFilter, setStatusFilter] = useState<string>('all')

  const { data: subscriptions, isLoading } = useCollection<SubscriptionDoc>(
    'subscriptions',
    [orderBy('created_at', 'desc')],
    ['subscriptions', 'table'],
  )

  // ── Derived stats ──────────────────────────────────────────────────────────

  const stats = useMemo(() => {
    const list = subscriptions ?? []
    const planCounts: Record<string, number> = {}
    const statusCounts: Record<string, number> = {}
    let activePaid = 0

    for (const s of list) {
      const plan = s.plan ?? 'free'
      const status = s.status ?? 'inactive'
      planCounts[plan] = (planCounts[plan] ?? 0) + 1
      statusCounts[status] = (statusCounts[status] ?? 0) + 1
      if (status === 'active' && plan !== 'free') activePaid++
    }

    const planChartData = Object.entries(planCounts).map(([plan, count]) => ({ plan, count }))
    return { planCounts, statusCounts, activePaid, planChartData }
  }, [subscriptions])

  const PLAN_KEYS = ['free', 'pro', 'enterprise', 'daas']
  const STATUS_KEYS = ['active', 'trialing', 'past_due', 'canceled', 'inactive']

  const filtered = useMemo(() => {
    let list = subscriptions ?? []
    if (planFilter !== 'all') list = list.filter((s) => s.plan === planFilter)
    if (statusFilter !== 'all') list = list.filter((s) => s.status === statusFilter)
    if (search.trim()) {
      const q = search.trim().toLowerCase()
      list = list.filter(
        (s) =>
          s.id.toLowerCase().includes(q) ||
          s.userId?.toLowerCase().includes(q) ||
          s.stripe_customer_id?.toLowerCase().includes(q) ||
          s.stripe_subscription_id?.toLowerCase().includes(q),
      )
    }
    return list
  }, [subscriptions, planFilter, statusFilter, search])

  const columns: Column<SubscriptionDoc>[] = [
    {
      key: 'userId',
      header: 'Kullanıcı ID',
      render: (s) => (
        <span
          className="font-mono text-xs text-gray-500 cursor-pointer hover:text-gray-800"
          title={s.userId}
          onClick={() => s.userId && navigator.clipboard.writeText(s.userId)}
        >
          {s.userId?.slice(0, 10) ?? '—'}…
        </span>
      ),
    },
    {
      key: 'plan',
      header: 'Plan',
      sortable: true,
      render: (s) => <PlanBadge plan={s.plan} />,
    },
    {
      key: 'status',
      header: 'Durum',
      sortable: true,
      render: (s) => <StatusBadge status={s.status} />,
    },
    {
      key: 'stripe_subscription_id',
      header: 'Stripe Sub ID',
      render: (s) =>
        s.stripe_subscription_id ? (
          <span
            className="font-mono text-xs text-gray-400 cursor-pointer hover:text-gray-600"
            title={s.stripe_subscription_id}
            onClick={() => s.stripe_subscription_id && navigator.clipboard.writeText(s.stripe_subscription_id!)}
          >
            {s.stripe_subscription_id.slice(0, 14)}…
          </span>
        ) : (
          <span className="text-gray-300 text-xs">—</span>
        ),
    },
    {
      key: 'current_period_end',
      header: 'Dönem Sonu',
      sortable: true,
      render: (s) => {
        if (!s.current_period_end) return <span className="text-gray-300 text-xs">—</span>
        const d = s.current_period_end.toDate
          ? s.current_period_end.toDate()
          : new Date((s.current_period_end as { seconds: number }).seconds * 1000)
        const isPast = d < new Date()
        return (
          <span className={`text-xs ${isPast ? 'text-red-500 font-medium' : 'text-gray-600'}`}>
            {tsToString(s.current_period_end)}
          </span>
        )
      },
    },
    {
      key: 'created_at',
      header: 'Oluşturulma',
      sortable: true,
      render: (s) => <span className="text-xs text-gray-500">{tsToString(s.created_at)}</span>,
    },
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-gray-900">Abonelikler</h1>
        <p className="text-sm text-gray-500 mt-0.5">Platform geneli abonelik durumları</p>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {PLAN_KEYS.map((plan) => (
          <div key={plan} className="card p-4">
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide">{plan}</p>
            <p className="mt-1 text-2xl font-bold tabular-nums text-gray-900">
              {isLoading ? '…' : (stats.planCounts[plan] ?? 0).toLocaleString('tr-TR')}
            </p>
          </div>
        ))}
      </div>

      {/* Chart + active stats */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <div className="xl:col-span-2 card p-5">
          <h2 className="text-sm font-semibold text-gray-700 mb-4">Plan Dağılımı</h2>
          <ResponsiveContainer width="100%" height={180}>
            <BarChart data={stats.planChartData} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="plan" tick={{ fontSize: 12, fill: '#9ca3af' }} tickLine={false} />
              <YAxis tick={{ fontSize: 10, fill: '#9ca3af' }} tickLine={false} axisLine={false} />
              <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e5e7eb' }} />
              <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                {stats.planChartData.map((entry, index) => (
                  <Cell key={index} fill={PLAN_COLORS[entry.plan] ?? '#94a3b8'} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="card p-5">
          <h2 className="text-sm font-semibold text-gray-700 mb-4">Durum Özeti</h2>
          <div className="space-y-2">
            {STATUS_KEYS.map((s) => (
              <div key={s} className="flex items-center justify-between">
                <StatusBadge status={s} />
                <span className="text-sm font-semibold tabular-nums text-gray-800">
                  {isLoading ? '…' : (stats.statusCounts[s] ?? 0).toLocaleString('tr-TR')}
                </span>
              </div>
            ))}
          </div>
          <div className="mt-4 pt-4 border-t border-gray-100">
            <p className="text-xs text-gray-500">Ücretli Aktif</p>
            <p className="text-2xl font-bold tabular-nums text-brand-600">
              {isLoading ? '…' : stats.activePaid.toLocaleString('tr-TR')}
            </p>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex items-center gap-1.5 flex-wrap">
          <span className="text-xs text-gray-500 font-medium">Plan:</span>
          {(['all', ...PLAN_KEYS]).map((p) => (
            <button
              key={p}
              onClick={() => setPlanFilter(p)}
              className={`px-2.5 py-1 rounded-lg text-xs font-medium transition-colors ${
                planFilter === p
                  ? 'bg-brand-600 text-white'
                  : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
              }`}
            >
              {p === 'all' ? 'Tümü' : p}
            </button>
          ))}
        </div>
        <div className="flex items-center gap-1.5 flex-wrap">
          <span className="text-xs text-gray-500 font-medium">Durum:</span>
          {(['all', ...STATUS_KEYS]).map((s) => {
            const STATUS_TR: Record<string, string> = {
              all: 'Tümü', active: 'Aktif', trialing: 'Deneme', past_due: 'Gecikmiş', canceled: 'İptal', inactive: 'Pasif',
            }
            return (
              <button
                key={s}
                onClick={() => setStatusFilter(s)}
                className={`px-2.5 py-1 rounded-lg text-xs font-medium transition-colors ${
                  statusFilter === s
                    ? 'bg-brand-600 text-white'
                    : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
                }`}
              >
                {STATUS_TR[s] ?? s}
              </button>
            )
          })}
        </div>
      </div>

      <DataTable
        columns={columns}
        data={filtered}
        keyExtractor={(s) => s.id}
        loading={isLoading}
        emptyMessage="Abonelik bulunamadı."
        searchValue={search}
        onSearchChange={setSearch}
        searchPlaceholder="Kullanıcı ID, Stripe ID ara…"
      />
    </div>
  )
}
