import { useQuery } from '@tanstack/react-query'
import { fetchWellbeing, fetchBenchmark } from '../api/endpoints'
import RadarChartWidget from '../components/RadarChartWidget'
import RetentionRiskBadge from '../components/RetentionRiskBadge'

function ScoreGauge({ score }: { score: number }) {
  const color =
    score >= 75
      ? 'text-emerald-600'
      : score >= 55
        ? 'text-amber-500'
        : 'text-red-500'

  return (
    <div className="flex flex-col items-center justify-center py-4">
      <span className={`text-7xl font-bold tabular-nums ${color}`}>
        {score.toFixed(0)}
      </span>
      <span className="text-slate-500 text-sm mt-1">/ 100</span>
    </div>
  )
}

function DimensionBar({
  label,
  value,
}: {
  label: string
  value: number
}) {
  const pct = Math.min(100, Math.max(0, value))
  const barColor =
    pct >= 75
      ? 'bg-emerald-500'
      : pct >= 55
        ? 'bg-amber-400'
        : 'bg-red-400'

  return (
    <div className="space-y-1">
      <div className="flex justify-between text-sm">
        <span className="font-medium text-slate-700">{label}</span>
        <span className="tabular-nums text-slate-500">{value.toFixed(1)}</span>
      </div>
      <div className="h-2 rounded-full bg-slate-100 overflow-hidden">
        <div
          className={`h-full rounded-full ${barColor} transition-all duration-700`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  )
}

const DIMENSION_LABELS: Record<string, string> = {
  mood: 'Ruh Hali',
  stress: 'Stres',
  team: 'Takım',
  growth: 'Gelişim',
  balance: 'Denge',
}

function Skeleton({ className }: { className?: string }) {
  return (
    <div
      className={`bg-slate-200 rounded-lg animate-pulse ${className ?? ''}`}
    />
  )
}

export default function OverviewPage() {
  const {
    data: wellbeing,
    isLoading: wellbeingLoading,
    error: wellbeingError,
  } = useQuery({
    queryKey: ['wellbeing'],
    queryFn: fetchWellbeing,
  })

  const {
    data: benchmark,
    isLoading: benchmarkLoading,
  } = useQuery({
    queryKey: ['benchmark'],
    queryFn: fetchBenchmark,
  })

  if (wellbeingError) {
    const status = (wellbeingError as { response?: { status?: number } })?.response
      ?.status
    return (
      <div className="flex items-center justify-center min-h-96">
        <div className="text-center">
          <div className="text-4xl mb-3">⚠️</div>
          <h2 className="text-lg font-semibold text-slate-700 mb-1">
            Veri yüklenemedi
          </h2>
          <p className="text-slate-500 text-sm">
            {status === 403
              ? 'Bu verilere erişim izniniz bulunmamaktadır.'
              : status === 451
                ? 'Gizlilik eşiği sağlanmamış — minimum katılım sayısına ulaşılmamış.'
                : 'Sunucuya bağlanırken bir hata oluştu. Lütfen tekrar deneyin.'}
          </p>
        </div>
      </div>
    )
  }

  const isLoading = wellbeingLoading

  // Build benchmark dimensions for radar if available
  const benchmarkDims = benchmark
    ? {
        mood:
          benchmark.dimensions.find((d) => d.dimension === 'mood')
            ?.industryAverage ?? 0,
        stress:
          benchmark.dimensions.find((d) => d.dimension === 'stress')
            ?.industryAverage ?? 0,
        team:
          benchmark.dimensions.find((d) => d.dimension === 'team')
            ?.industryAverage ?? 0,
        growth:
          benchmark.dimensions.find((d) => d.dimension === 'growth')
            ?.industryAverage ?? 0,
        balance:
          benchmark.dimensions.find((d) => d.dimension === 'balance')
            ?.industryAverage ?? 0,
      }
    : undefined

  return (
    <div className="space-y-6">
      {/* Page title */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Genel Bakış</h1>
        {wellbeing && (
          <p className="text-slate-500 text-sm mt-0.5">
            {wellbeing.companyName} — son güncelleme:{' '}
            {new Date(wellbeing.generatedAt).toLocaleString('tr-TR')}
          </p>
        )}
      </div>

      {/* Top metrics row */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Overall score */}
        <div className="card flex flex-col items-center text-center">
          <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1">
            Refah Skoru
          </span>
          {isLoading ? (
            <Skeleton className="h-20 w-28 mt-2" />
          ) : (
            <ScoreGauge score={wellbeing!.score} />
          )}
        </div>

        {/* Participation rate */}
        <div className="card flex flex-col items-center text-center">
          <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1">
            Katılım Oranı
          </span>
          {isLoading ? (
            <Skeleton className="h-20 w-28 mt-2" />
          ) : (
            <div className="flex flex-col items-center py-4">
              <span className="text-5xl font-bold text-brand-600 tabular-nums">
                {(wellbeing!.participationRate * 100).toFixed(0)}%
              </span>
              <span className="text-slate-500 text-sm mt-2">
                {wellbeing!.checkinCount} / {wellbeing!.employeeCount} çalışan
              </span>
            </div>
          )}
        </div>

        {/* Retention risk */}
        <div className="card flex flex-col items-center text-center">
          <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1">
            İşten Ayrılma Riski
          </span>
          {isLoading ? (
            <Skeleton className="h-20 w-36 mt-2" />
          ) : (
            <div className="flex flex-col items-center justify-center flex-1 py-4">
              <RetentionRiskBadge risk={wellbeing!.retentionRisk} size="lg" />
            </div>
          )}
        </div>
      </div>

      {/* Dimensions + Radar row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Dimension bars */}
        <div className="card">
          <h2 className="text-base font-semibold text-slate-800 mb-4">
            Boyut Detayları
          </h2>
          {isLoading ? (
            <div className="space-y-4">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-8" />
              ))}
            </div>
          ) : (
            <div className="space-y-4">
              {(
                Object.entries(wellbeing!.dimensions) as [string, number][]
              ).map(([key, value]) => (
                <DimensionBar
                  key={key}
                  label={DIMENSION_LABELS[key] ?? key}
                  value={value}
                />
              ))}
            </div>
          )}
        </div>

        {/* Radar chart */}
        <div className="card">
          <h2 className="text-base font-semibold text-slate-800 mb-2">
            Radar Grafiği
            {!benchmarkLoading && benchmark && (
              <span className="ml-2 text-xs font-normal text-slate-400">
                vs. {benchmark.industryName} ortalaması
              </span>
            )}
          </h2>
          {isLoading ? (
            <Skeleton className="h-72" />
          ) : (
            <RadarChartWidget
              company={wellbeing!.dimensions}
              benchmark={benchmarkDims}
              companyName={wellbeing!.companyName}
            />
          )}
        </div>
      </div>
    </div>
  )
}
