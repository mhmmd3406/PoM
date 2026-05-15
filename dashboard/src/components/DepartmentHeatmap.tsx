import type { DepartmentData, Dimensions } from '../api/endpoints'

interface DepartmentHeatmapProps {
  departments: DepartmentData[]
}

const DIMENSIONS: Array<{ key: keyof Dimensions; label: string }> = [
  { key: 'mood',    label: 'Ruh Hali' },
  { key: 'stress',  label: 'Stres'    },
  { key: 'team',    label: 'Takım'    },
  { key: 'growth',  label: 'Gelişim'  },
  { key: 'balance', label: 'Denge'    },
]

function scoreToColor(score: number): string {
  if (score >= 75) return 'bg-emerald-100 text-emerald-800'
  if (score >= 60) return 'bg-lime-100 text-lime-800'
  if (score >= 45) return 'bg-amber-100 text-amber-800'
  return 'bg-red-100 text-red-800'
}

export default function DepartmentHeatmap({ departments }: DepartmentHeatmapProps) {
  const eligible = departments.filter((d) => d.meetsThreshold)

  if (eligible.length === 0) {
    return (
      <p className="text-slate-500 text-sm">
        Isı haritası için yeterli katılımlı departman bulunmamaktadır.
      </p>
    )
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm border-separate border-spacing-1">
        <thead>
          <tr>
            <th className="text-left text-slate-500 font-medium pb-2 pr-4 w-40">Departman</th>
            {DIMENSIONS.map((d) => (
              <th key={d.key} className="text-center text-slate-500 font-medium pb-2 px-1 min-w-[80px]">
                {d.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {eligible.map((dept) => (
            <tr key={dept.departmentId}>
              <td className="pr-4 py-1 font-medium text-slate-700 truncate max-w-[160px]" title={dept.departmentName}>
                {dept.departmentName}
              </td>
              {DIMENSIONS.map((d) => {
                const val = dept.dimensions[d.key]
                return (
                  <td key={d.key} className="text-center py-1">
                    <span className={`inline-block rounded-md px-2 py-1 text-xs font-semibold tabular-nums ${scoreToColor(val)}`}>
                      {val.toFixed(0)}
                    </span>
                  </td>
                )
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
