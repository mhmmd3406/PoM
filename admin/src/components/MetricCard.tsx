import { ReactNode } from 'react'

interface MetricCardProps {
  title: string
  value: string | number
  subtitle?: string
  icon?: ReactNode
  trend?: { value: number; label: string }
  loading?: boolean
  colorClass?: string
}

export function MetricCard({
  title,
  value,
  subtitle,
  icon,
  trend,
  loading = false,
  colorClass = 'bg-brand-50 text-brand-600',
}: MetricCardProps) {
  return (
    <div className="card p-5">
      <div className="flex items-start justify-between">
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-gray-500 truncate">{title}</p>
          {loading ? (
            <div className="mt-2 h-8 w-24 bg-gray-200 rounded animate-pulse" />
          ) : (
            <p className="mt-1 text-2xl font-bold text-gray-900 tabular-nums">
              {value}
            </p>
          )}
          {subtitle && (
            <p className="mt-1 text-xs text-gray-400">{subtitle}</p>
          )}
          {trend && !loading && (
            <p
              className={`mt-1 text-xs font-medium ${
                trend.value >= 0 ? 'text-green-600' : 'text-red-500'
              }`}
            >
              {trend.value >= 0 ? '▲' : '▼'} {Math.abs(trend.value)}% {trend.label}
            </p>
          )}
        </div>
        {icon && (
          <div
            className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ml-3 ${colorClass}`}
          >
            {icon}
          </div>
        )}
      </div>
    </div>
  )
}
