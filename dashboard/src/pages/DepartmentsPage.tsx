import { useQuery } from '@tanstack/react-query'
import { fetchDepartments, type DepartmentData } from '../api/endpoints'
import DepartmentHeatmap from '../components/DepartmentHeatmap'
import RetentionRiskBadge from '../components/RetentionRiskBadge'
import type { RetentionRisk } from '../api/endpoints'

function Skeleton({ className }: { className?: string }) {
  return <div className={`bg-slate-200 rounded-lg animate-pulse ${className ?? ''}`} />
}

function scoreToRisk(score: number): RetentionRisk {
  if (score >= 70) return 'low'
  if (score >= 50) return 'medium'
  return 'high'
}

function scoreColor(score: number): string {
  if (score >= 75) return 'text-emerald-600'
  if (score >= 55) return 'text-amber-500'
  return 'text-red-500'
}

function DepartmentCard({ dept }: { dept: DepartmentData }) {
  const participation =
    dept.employeeCount > 0 ? dept.checkinCount / dept.employeeCount : 0

  return (
    <div className="card">
      <div className="flex items-start justify-between mb-3">
        <div>
          <h3 className="font-semibold text-slate-800 text-base leading-tight">
            {dept.departmentName}
          </h3>
          <p className="text-xs text-slate-400 mt-0.5">
            {dept.checkinCount} / {dept.employeeCount} çalışan
          </p>
        </div>
        <RetentionRiskBadge
          risk={scoreToRisk(dept.score)}
          showLabel={false}
          size="sm"
        />
      </div>

      <div className="flex items-end gap-2 mb-4">
        <span className={`text-4xl font-bold tabular-nums ${scoreColor(dept.score)}`}>
          {dept.score.toFixed(0)}
        </span>
        <span className="text-slate-400 text-sm mb-1">/ 100</span>
      </div>

      {/* Mini dimension bars */}
      <div className="space-y-2">
        {(
          [
            ['mood', 'Ruh Hali'],
            ['stress', 'Stres'],
            ['team', 'Takım'],
            ['growth', 'Gelişim'],
            ['balance', 'Denge'],
          ] as [keyof DepartmentData['dimensions'], string][]
        ).map(([key, label]) => {
          const val = dept.dimensions[key]
          const pct = Math.min(100, Math.max(0, val))
          return (
            <div key={key} className="flex items-center gap-2 text-xs">
              <span className="w-16 text-slate-500 shrink-0">{label}</span>
              <div className="flex-1 h-1.5 rounded-full bg-slate-100 overflow-hidden">
                <div
                  className="h-full rounded-full bg-brand-500 transition-all duration-700"
                  style={{ width: `${pct}%` }}
                />
              </div>
              <span className="w-8 text-right tabular-nums text-slate-600">
                {val.toFixed(0)}
              </span>
            </div>
          )
        })}
      </div>

      {/* Participation bar */}
      <div className="mt-3 pt-3 border-t border-slate-100">
        <div className="flex justify-between text-xs text-slate-400 mb-1">
          <span>Katılım</span>
          <span>{(participation * 100).toFixed(0)}%</span>
        </div>
        <div className="h-1.5 rounded-full bg-slate-100 overflow-hidden">
          <div
            className="h-full rounded-full bg-slate-400 transition-all duration-700"
            style={{ width: `${participation * 100}%` }}
          />
        </div>
      </div>
    </div>
  )
}

function InsufficientCard({ dept }: { dept: DepartmentData }) {
  return (
    <div className="card border-dashed opacity-60 flex flex-col justify-between">
      <div>
        <h3 className="font-semibold text-slate-700 text-base">{dept.departmentName}</h3>
        <p className="text-xs text-slate-400 mt-0.5">
          {dept.checkinCount} / {dept.employeeCount} çalışan
        </p>
      </div>
      <p className="text-xs text-amber-600 bg-amber-50 border border-amber-100 rounded-md px-3 py-2 mt-4">
        Yetersiz katılım (min. 10 çalışan)
      </p>
    </div>
  )
}

export default function DepartmentsPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['departments'],
    queryFn: fetchDepartments,
  })

  const eligible = data?.departments.filter((d) => d.meetsThreshold) ?? []
  const ineligible = data?.departments.filter((d) => !d.meetsThreshold) ?? []

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-96">
        <div className="text-center">
          <div className="text-4xl mb-3">⚠️</div>
          <h2 className="text-lg font-semibold text-slate-700 mb-1">
            Departman verisi yüklenemedi
          </h2>
          <p className="text-slate-500 text-sm">Lütfen sayfayı yenileyin.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Departmanlar</h1>
        <p className="text-slate-500 text-sm mt-0.5">
          Minimum 10 çalışan katılımı olan departmanlar gösterilmektedir.
        </p>
      </div>

      {/* Eligible departments */}
      <section>
        <h2 className="text-base font-semibold text-slate-700 mb-4">
          Aktif Departmanlar{' '}
          {!isLoading && (
            <span className="text-slate-400 font-normal">({eligible.length})</span>
          )}
        </h2>

        {isLoading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {Array.from({ length: 3 }).map((_, i) => (
              <Skeleton key={i} className="h-60" />
            ))}
          </div>
        ) : eligible.length === 0 ? (
          <div className="card text-center py-10 text-slate-500">
            Henüz yeterli katılımlı departman bulunmamaktadır.
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {eligible.map((dept) => (
              <DepartmentCard key={dept.departmentId} dept={dept} />
            ))}
          </div>
        )}
      </section>

      {/* Heatmap */}
      {!isLoading && eligible.length > 0 && (
        <section className="card">
          <h2 className="text-base font-semibold text-slate-800 mb-4">
            Boyut Isı Haritası
          </h2>
          <DepartmentHeatmap departments={data!.departments} />
        </section>
      )}

      {/* Ineligible departments */}
      {!isLoading && ineligible.length > 0 && (
        <section>
          <h2 className="text-base font-semibold text-slate-700 mb-4">
            Yetersiz Katılımlı Departmanlar{' '}
            <span className="text-slate-400 font-normal">({ineligible.length})</span>
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {ineligible.map((dept) => (
              <InsufficientCard key={dept.departmentId} dept={dept} />
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
