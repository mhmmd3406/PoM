import { useQuery } from '@tanstack/react-query'
import { fetchBenchmark, fetchWellbeing } from '../api/endpoints'
import RadarChartWidget from '../components/RadarChartWidget'
import type { BenchmarkDimension } from '../api/endpoints'

function Skeleton({ className }: { className?: string }) {
  return <div className={`bg-slate-200 rounded-lg animate-pulse ${className ?? ''}`} />
}

function percentileColor(p: number): string {
  if (p >= 75) return 'text-emerald-600 bg-emerald-50 border-emerald-200'
  if (p >= 50) return 'text-brand-600 bg-brand-50 border-brand-200'
  if (p >= 25) return 'text-amber-600 bg-amber-50 border-amber-200'
  return 'text-red-600 bg-red-50 border-red-200'
}

function PercentileBar({ percentile }: { percentile: number }) {
  return (
    <div className="relative h-3 rounded-full bg-slate-100 overflow-hidden">
      {/* Top 25% threshold marker */}
      <div
        className="absolute top-0 bottom-0 w-0.5 bg-emerald-400 z-10"
        style={{ left: '75%' }}
        title="Top 25% eşiği"
      />
      <div
        className="h-full rounded-full bg-brand-500 transition-all duration-700"
        style={{ width: `${Math.min(100, Math.max(0, percentile))}%` }}
      />
    </div>
  )
}

function DimensionRow({ dim }: { dim: BenchmarkDimension }) {
  const LABELS: Record<string, string> = {
    mood: 'Ruh Hali',
    stress: 'Stres',
    team: 'Takım',
    growth: 'Gelişim',
    balance: 'Denge',
  }
  const label = LABELS[dim.dimension] ?? dim.dimension
  const diff = dim.companyScore - dim.industryAverage

  return (
    <div className="py-3 border-b border-slate-50 last:border-0">
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm font-medium text-slate-700">{label}</span>
        <div className="flex items-center gap-3">
          {/* Percentile badge */}
          <span
            className={`text-xs font-semibold px-2 py-0.5 rounded-full border ${percentileColor(dim.percentile)}`}
          >
            P{dim.percentile.toFixed(0)}
          </span>
          {/* vs industry */}
          <span className="text-sm tabular-nums text-slate-600">
            {dim.companyScore.toFixed(1)}
            <span className="text-slate-400 mx-1">vs</span>
            {dim.industryAverage.toFixed(1)}
          </span>
          <span
            className={`text-xs tabular-nums font-semibold ${
              diff >= 0 ? 'text-emerald-600' : 'text-red-500'
            }`}
          >
            {diff >= 0 ? '+' : ''}
            {diff.toFixed(1)}
          </span>
        </div>
      </div>
      <PercentileBar percentile={dim.percentile} />
    </div>
  )
}

export default function BenchmarkPage() {
  const { data: benchmark, isLoading: bmLoading, error: bmError } = useQuery({
    queryKey: ['benchmark'],
    queryFn: fetchBenchmark,
  })

  const { data: wellbeing, isLoading: wbLoading } = useQuery({
    queryKey: ['wellbeing'],
    queryFn: fetchWellbeing,
  })

  const isLoading = bmLoading || wbLoading

  // Build radar data
  const companyDims = wellbeing?.dimensions
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

  if (bmError) {
    return (
      <div className="flex items-center justify-center min-h-96">
        <div className="text-center">
          <div className="text-4xl mb-3">⚠️</div>
          <h2 className="text-lg font-semibold text-slate-700 mb-1">
            Kıyaslama verisi yüklenemedi
          </h2>
          <p className="text-slate-500 text-sm">Lütfen sayfayı yenileyin.</p>
        </div>
      </div>
    )
  }

  const isTopQuartile =
    benchmark && benchmark.overallPercentile >= benchmark.topQuartileThreshold

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Sektör Kıyaslaması</h1>
        {!isLoading && benchmark && (
          <p className="text-slate-500 text-sm mt-0.5">
            {wellbeing?.companyName ?? 'Şirketiniz'} vs{' '}
            <span className="font-medium">{benchmark.industryName}</span> sektörü
          </p>
        )}
      </div>

      {/* Overall percentile + top-quartile banner */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="card text-center">
          <p className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1">
            Genel Yüzdelik
          </p>
          {isLoading ? (
            <Skeleton className="h-16 mt-2" />
          ) : (
            <div className="flex flex-col items-center py-2">
              <span className="text-5xl font-bold text-brand-600 tabular-nums">
                P{benchmark!.overallPercentile.toFixed(0)}
              </span>
              <span className="text-slate-400 text-xs mt-1">sektörde konum</span>
            </div>
          )}
        </div>

        <div className="card text-center">
          <p className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1">
            Top 25% Eşiği
          </p>
          {isLoading ? (
            <Skeleton className="h-16 mt-2" />
          ) : (
            <div className="flex flex-col items-center py-2">
              <span className="text-3xl font-bold text-slate-700 tabular-nums">
                P{benchmark!.topQuartileThreshold.toFixed(0)}
              </span>
              <span className="text-slate-400 text-xs mt-1">üst çeyrek başlangıcı</span>
            </div>
          )}
        </div>

        <div
          className={`card text-center flex flex-col items-center justify-center ${
            isTopQuartile
              ? 'bg-emerald-50 border-emerald-200'
              : 'bg-amber-50 border-amber-200'
          }`}
        >
          {isLoading ? (
            <Skeleton className="h-16 w-full" />
          ) : (
            <>
              <span className="text-3xl mb-1">
                {isTopQuartile ? '🏆' : '📈'}
              </span>
              <p
                className={`text-sm font-semibold ${
                  isTopQuartile ? 'text-emerald-700' : 'text-amber-700'
                }`}
              >
                {isTopQuartile
                  ? 'Top 25% şirketler arasındasınız!'
                  : 'Top 25% için gelişim fırsatı var'}
              </p>
              {!isTopQuartile && benchmark && (
                <p className="text-xs text-amber-600 mt-0.5">
                  {(benchmark.topQuartileThreshold - benchmark.overallPercentile).toFixed(0)} puan fark
                </p>
              )}
            </>
          )}
        </div>
      </div>

      {/* Radar comparison */}
      <div className="card">
        <h2 className="text-base font-semibold text-slate-800 mb-2">
          Radar Karşılaştırması
        </h2>
        <p className="text-xs text-slate-400 mb-4">
          Mavi: Şirketiniz &nbsp;|&nbsp; Sarı kesikli: Sektör ortalaması
        </p>
        {isLoading || !companyDims ? (
          <Skeleton className="h-72" />
        ) : (
          <RadarChartWidget
            company={companyDims}
            benchmark={benchmarkDims}
            companyName={wellbeing?.companyName ?? 'Şirketiniz'}
          />
        )}
      </div>

      {/* Dimension breakdown */}
      <div className="card">
        <h2 className="text-base font-semibold text-slate-800 mb-1">
          Boyut Bazında Kıyaslama
        </h2>
        <p className="text-xs text-slate-400 mb-4">
          Yüzdelik sıralama · Sektör içindeki konumunuz (P75 = Top 25%)
        </p>

        {isLoading ? (
          <div className="space-y-4">
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : (
          <div>
            {benchmark?.dimensions.map((dim) => (
              <DimensionRow key={dim.dimension} dim={dim} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
