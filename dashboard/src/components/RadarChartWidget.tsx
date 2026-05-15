import {
  Radar,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  ResponsiveContainer,
  Legend,
  Tooltip,
} from 'recharts'
import type { Dimensions } from '../api/endpoints'

interface RadarChartWidgetProps {
  company: Dimensions
  benchmark?: Dimensions
  companyName?: string
}

const DIMENSION_LABELS: Record<keyof Dimensions, string> = {
  mood:    'Ruh Hali',
  stress:  'Stres',
  team:    'Takım',
  growth:  'Gelişim',
  balance: 'Denge',
}

function dimensionsToRadarData(
  company: Dimensions,
  benchmark?: Dimensions,
) {
  return (Object.keys(DIMENSION_LABELS) as Array<keyof Dimensions>).map((key) => ({
    dimension: DIMENSION_LABELS[key],
    Şirket: Math.round(company[key] * 10) / 10,
    ...(benchmark ? { Sektör: Math.round(benchmark[key] * 10) / 10 } : {}),
  }))
}

export default function RadarChartWidget({
  company,
  benchmark,
  companyName = 'Şirketiniz',
}: RadarChartWidgetProps) {
  const data = dimensionsToRadarData(company, benchmark)

  return (
    <ResponsiveContainer width="100%" height={320}>
      <RadarChart data={data} margin={{ top: 10, right: 30, bottom: 10, left: 30 }}>
        <PolarGrid stroke="#e2e8f0" />
        <PolarAngleAxis
          dataKey="dimension"
          tick={{ fill: '#64748b', fontSize: 13, fontWeight: 500 }}
        />
        <PolarRadiusAxis
          angle={90}
          domain={[0, 100]}
          tick={{ fill: '#94a3b8', fontSize: 11 }}
          tickCount={6}
        />
        <Tooltip
          formatter={(value: number) => [`${value}`, '']}
          contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0' }}
        />
        <Radar
          name={companyName}
          dataKey="Şirket"
          stroke="#0284c7"
          fill="#0284c7"
          fillOpacity={0.25}
          strokeWidth={2}
        />
        {benchmark && (
          <Radar
            name="Sektör Ort."
            dataKey="Sektör"
            stroke="#f59e0b"
            fill="#f59e0b"
            fillOpacity={0.15}
            strokeWidth={2}
            strokeDasharray="5 4"
          />
        )}
        <Legend
          wrapperStyle={{ fontSize: 13, paddingTop: 8 }}
        />
      </RadarChart>
    </ResponsiveContainer>
  )
}
