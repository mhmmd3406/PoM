import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { fetchTrends, buildTrendsCsv, type TrendResponse } from '../api/endpoints'
import TrendLineChart from '../components/TrendLineChart'

type DimensionKey = 'all' | 'mood' | 'stress' | 'team' | 'growth' | 'balance'

const DIMENSION_OPTIONS: Array<{ value: DimensionKey; label: string }> = [
  { value: 'all',     label: 'Tümü' },
  { value: 'mood',    label: 'Ruh Hali' },
  { value: 'stress',  label: 'Stres' },
  { value: 'team',    label: 'Takım' },
  { value: 'growth',  label: 'Gelişim' },
  { value: 'balance', label: 'Denge' },
]

const PERIOD_OPTIONS: Array<{ value: number; label: string }> = [
  { value: 30,  label: '1 Ay' },
  { value: 60,  label: '2 Ay' },
  { value: 90,  label: '3 Ay' },
]

function downloadCsv(trend: TrendResponse) {
  const csv = buildTrendsCsv(trend)
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `pom-trends-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function SummaryCard({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="card text-center">
      <p className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1">{label}</p>
      <p className="text-2xl font-bold text-slate-800 tabular-nums">{value}</p>
      {sub && <p className="text-xs text-slate-500 mt-0.5">{sub}</p>}
    </div>
  )
}

function Skeleton({ className }: { className?: string }) {
  return <div className={`bg-slate-200 rounded-lg animate-pulse ${className ?? ''}`} />
}

export default function TrendsPage() {
  const [selectedDimension, setSelectedDimension] = useState<DimensionKey>('all')
  const [days, setDays] = useState(90)

  const { data: trend, isLoading, error } = useQuery({
    queryKey: ['trends', days],
    queryFn: () => fetchTrends(days),
  })

  // Summary stats
  const firstScore = trend?.points[0]?.score
  const lastScore = trend?.points[trend.points.length - 1]?.score
  const deltaScore =
    firstScore !== undefined && lastScore !== undefined
      ? lastScore - firstScore
      : null

  const avgParticipants =
    trend && trend.points.length > 0
      ? Math.round(
          trend.points.reduce((s, p) => s + p.participantCount, 0) /
            trend.points.length,
        )
      : null

  return (
    <div className="space-y-6">
      {/* Header row */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Trendler</h1>
          <p className="text-slate-500 text-sm mt-0.5">Haftalık refah skorları zaman serisi</p>
        </div>
        <button
          onClick={() => trend && downloadCsv(trend)}
          disabled={!trend || isLoading}
          className="btn-secondary flex items-center gap-2 self-start sm:self-auto"
        >
          <span>⬇</span>
          CSV İndir
        </button>
      </div>

      {/* Controls */}
      <div className="flex flex-wrap gap-3 items-center">
        {/* Period selector */}
        <div className="flex rounded-lg border border-slate-200 overflow-hidden">
          {PERIOD_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              onClick={() => setDays(opt.value)}
              className={`px-4 py-1.5 text-sm font-medium transition-colors ${
                days === opt.value
                  ? 'bg-brand-600 text-white'
                  : 'bg-white text-slate-600 hover:bg-slate-50'
              }`}
            >
              {opt.label}
            </button>
          ))}
        </div>

        {/* Dimension selector */}
        <div className="flex flex-wrap gap-1.5">
          {DIMENSION_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              onClick={() => setSelectedDimension(opt.value)}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                selectedDimension === opt.value
                  ? 'bg-brand-100 text-brand-700 border border-brand-300'
                  : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
              }`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      {error ? (
        <div className="card flex items-center justify-center h-64">
          <div className="text-center">
            <div className="text-3xl mb-2">⚠️</div>
            <p className="text-slate-600 font-medium">Trend verisi yüklenemedi.</p>
            <p className="text-slate-400 text-sm mt-1">Lütfen sayfayı yenileyin.</p>
          </div>
        </div>
      ) : (
        <>
          {/* Summary stats */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <SummaryCard
              label="Hafta Sayısı"
              value={isLoading ? '—' : String(trend?.points.length ?? 0)}
            />
            <SummaryCard
              label="Son Skor"
              value={isLoading ? '—' : lastScore?.toFixed(1) ?? '—'}
            />
            <SummaryCard
              label="Değişim"
              value={
                isLoading || deltaScore === null
                  ? '—'
                  : `${deltaScore >= 0 ? '+' : ''}${deltaScore.toFixed(1)}`
              }
              sub={
                deltaScore !== null
                  ? deltaScore >= 0
                    ? 'Dönem içinde artış'
                    : 'Dönem içinde düşüş'
                  : undefined
              }
            />
            <SummaryCard
              label="Ort. Katılımcı"
              value={isLoading || avgParticipants === null ? '—' : String(avgParticipants)}
              sub="haftalık ortalama"
            />
          </div>

          {/* Chart */}
          <div className="card">
            <h2 className="text-base font-semibold text-slate-800 mb-4">
              Haftalık Ortalama Skorlar
            </h2>
            {isLoading ? (
              <Skeleton className="h-80" />
            ) : trend && trend.points.length > 0 ? (
              <TrendLineChart
                points={trend.points}
                selectedDimension={selectedDimension}
              />
            ) : (
              <div className="flex items-center justify-center h-64 text-slate-400 text-sm">
                Bu dönem için veri bulunmamaktadır.
              </div>
            )}
          </div>

          {/* Data table */}
          {!isLoading && trend && trend.points.length > 0 && (
            <div className="card overflow-x-auto">
              <h2 className="text-base font-semibold text-slate-800 mb-4">Haftalık Tablo</h2>
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-100">
                    <th className="text-left py-2 pr-4 font-semibold text-slate-500">Hafta</th>
                    <th className="text-right py-2 px-2 font-semibold text-slate-500">Genel</th>
                    <th className="text-right py-2 px-2 font-semibold text-slate-500">Ruh Hali</th>
                    <th className="text-right py-2 px-2 font-semibold text-slate-500">Stres</th>
                    <th className="text-right py-2 px-2 font-semibold text-slate-500">Takım</th>
                    <th className="text-right py-2 px-2 font-semibold text-slate-500">Gelişim</th>
                    <th className="text-right py-2 px-2 font-semibold text-slate-500">Denge</th>
                    <th className="text-right py-2 pl-2 font-semibold text-slate-500">Katılımcı</th>
                  </tr>
                </thead>
                <tbody>
                  {[...trend.points].reverse().map((p) => (
                    <tr
                      key={p.weekStart}
                      className="border-b border-slate-50 hover:bg-slate-50 transition-colors"
                    >
                      <td className="py-2 pr-4 text-slate-600">
                        {new Date(p.weekStart).toLocaleDateString('tr-TR', {
                          day: '2-digit',
                          month: 'short',
                        })}
                      </td>
                      <td className="py-2 px-2 text-right font-semibold tabular-nums text-slate-800">
                        {p.score.toFixed(1)}
                      </td>
                      <td className="py-2 px-2 text-right tabular-nums text-slate-600">{p.dimensions.mood.toFixed(1)}</td>
                      <td className="py-2 px-2 text-right tabular-nums text-slate-600">{p.dimensions.stress.toFixed(1)}</td>
                      <td className="py-2 px-2 text-right tabular-nums text-slate-600">{p.dimensions.team.toFixed(1)}</td>
                      <td className="py-2 px-2 text-right tabular-nums text-slate-600">{p.dimensions.growth.toFixed(1)}</td>
                      <td className="py-2 px-2 text-right tabular-nums text-slate-600">{p.dimensions.balance.toFixed(1)}</td>
                      <td className="py-2 pl-2 text-right tabular-nums text-slate-500">{p.participantCount}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
    </div>
  )
}
