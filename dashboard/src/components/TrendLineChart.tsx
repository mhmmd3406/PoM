import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import type { TrendPoint, Dimensions } from '../api/endpoints'

type DimensionKey = keyof Dimensions | 'all'

interface TrendLineChartProps {
  points: TrendPoint[]
  selectedDimension: DimensionKey
}

const DIMENSION_META: Array<{
  key: keyof Dimensions
  label: string
  color: string
}> = [
  { key: 'mood',    label: 'Ruh Hali', color: '#6366f1' },
  { key: 'stress',  label: 'Stres',    color: '#f43f5e' },
  { key: 'team',    label: 'Takım',    color: '#10b981' },
  { key: 'growth',  label: 'Gelişim',  color: '#f59e0b' },
  { key: 'balance', label: 'Denge',    color: '#8b5cf6' },
]

function formatWeek(iso: string): string {
  const d = new Date(iso)
  return `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')}`
}

export default function TrendLineChart({ points, selectedDimension }: TrendLineChartProps) {
  const data = points.map((p) => ({
    week: formatWeek(p.weekStart),
    Genel: Math.round(p.score * 10) / 10,
    ...Object.fromEntries(
      DIMENSION_META.map((d) => [d.label, Math.round(p.dimensions[d.key] * 10) / 10]),
    ),
  }))

  return (
    <ResponsiveContainer width="100%" height={320}>
      <LineChart data={data} margin={{ top: 5, right: 20, bottom: 5, left: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
        <XAxis
          dataKey="week"
          tick={{ fill: '#64748b', fontSize: 12 }}
          tickLine={false}
          axisLine={{ stroke: '#e2e8f0' }}
        />
        <YAxis
          domain={[0, 100]}
          tick={{ fill: '#64748b', fontSize: 12 }}
          tickLine={false}
          axisLine={false}
          width={32}
        />
        <Tooltip
          contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 13 }}
          formatter={(value: number) => [`${value}`, '']}
        />
        <Legend wrapperStyle={{ fontSize: 13, paddingTop: 8 }} />

        {selectedDimension === 'all' ? (
          <>
            <Line
              type="monotone"
              dataKey="Genel"
              stroke="#0284c7"
              strokeWidth={3}
              dot={false}
              activeDot={{ r: 5 }}
            />
            {DIMENSION_META.map((d) => (
              <Line
                key={d.key}
                type="monotone"
                dataKey={d.label}
                stroke={d.color}
                strokeWidth={1.5}
                dot={false}
                strokeOpacity={0.7}
              />
            ))}
          </>
        ) : (
          (() => {
            const meta = DIMENSION_META.find((d) => d.key === selectedDimension)
            if (!meta) return null
            return (
              <Line
                type="monotone"
                dataKey={meta.label}
                stroke={meta.color}
                strokeWidth={3}
                dot={false}
                activeDot={{ r: 5 }}
              />
            )
          })()
        )}
      </LineChart>
    </ResponsiveContainer>
  )
}
