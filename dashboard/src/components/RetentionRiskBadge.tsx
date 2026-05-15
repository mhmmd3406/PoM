import type { RetentionRisk } from '../api/endpoints'

interface RetentionRiskBadgeProps {
  risk: RetentionRisk
  showLabel?: boolean
  size?: 'sm' | 'md' | 'lg'
}

const RISK_CONFIG: Record<
  RetentionRisk,
  { label: string; description: string; classes: string; icon: string }
> = {
  low: {
    label: 'Düşük Risk',
    description: 'İşten ayrılma riski düşük seviyelerde.',
    classes: 'bg-emerald-100 text-emerald-800 border-emerald-200',
    icon: '✓',
  },
  medium: {
    label: 'Orta Risk',
    description: 'İşten ayrılma riski orta seviyelerde — dikkat önerilir.',
    classes: 'bg-amber-100 text-amber-800 border-amber-200',
    icon: '!',
  },
  high: {
    label: 'Yüksek Risk',
    description: 'İşten ayrılma riski yüksek — acil önlem alınması önerilir.',
    classes: 'bg-red-100 text-red-800 border-red-200',
    icon: '!!',
  },
}

const SIZE_CLASSES = {
  sm: 'text-xs px-2 py-0.5',
  md: 'text-sm px-3 py-1',
  lg: 'text-base px-4 py-1.5',
}

export default function RetentionRiskBadge({
  risk,
  showLabel = true,
  size = 'md',
}: RetentionRiskBadgeProps) {
  const config = RISK_CONFIG[risk]

  return (
    <div className="inline-flex flex-col gap-1">
      <span
        className={`inline-flex items-center gap-1.5 rounded-full border font-semibold ${config.classes} ${SIZE_CLASSES[size]}`}
        title={config.description}
      >
        <span className="font-bold">{config.icon}</span>
        {showLabel && config.label}
      </span>
      {showLabel && (
        <span className="text-xs text-slate-500">{config.description}</span>
      )}
    </div>
  )
}
