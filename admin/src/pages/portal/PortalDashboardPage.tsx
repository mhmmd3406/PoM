import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../hooks/useAuth'
import { useCollection, where, orderBy } from '../../hooks/useFirestore'
import { SurveyDoc, SurveyStatus } from './types'

// ── Status badge ─────────────────────────────────────────────────────────────

export function StatusBadge({ status }: { status: SurveyStatus | string }) {
  const map: Record<string, { label: string; cls: string }> = {
    draft:  { label: 'Taslak', cls: 'bg-gray-100 text-gray-600' },
    active: { label: 'Aktif',  cls: 'bg-green-100 text-green-700' },
    closed: { label: 'Kapalı', cls: 'bg-slate-100 text-slate-600' },
  }
  const { label, cls } = map[status] ?? map.draft
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {label}
    </span>
  )
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function PortalDashboardPage() {
  const { authState } = useAuth()
  const navigate = useNavigate()
  const companyId = authState.status === 'authenticated' ? authState.companyId : undefined

  const { data: surveys = [], isLoading } = useCollection<SurveyDoc>(
    'surveys',
    companyId
      ? [where('companyId', '==', companyId), orderBy('created_at', 'desc')]
      : [],
    ['surveys', companyId],
  )

  const activeSurveys  = surveys.filter((s) => s.status === 'active').length
  const draftSurveys   = surveys.filter((s) => s.status === 'draft').length
  const totalResponses = surveys.reduce((sum, s) => sum + (s.responseCount ?? 0), 0)
  const recentSurveys  = surveys.slice(0, 5)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-sm text-gray-500 mt-0.5">Şirketinizin anket durumu</p>
        </div>
        <button onClick={() => navigate('/portal/surveys/new')} className="btn-primary">
          + Yeni Anket
        </button>
      </div>

      {/* Metric cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <MetricCard label="Aktif Anket"   value={activeSurveys}  icon="📊" color="green" loading={isLoading} />
        <MetricCard label="Toplam Yanıt"  value={totalResponses} icon="✅" color="blue"  loading={isLoading} />
        <MetricCard label="Taslak"        value={draftSurveys}   icon="📝" color="gray"  loading={isLoading} />
      </div>

      {/* Recent surveys */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <h2 className="font-semibold text-gray-900">Son Anketler</h2>
          <button
            onClick={() => navigate('/portal/surveys')}
            className="text-sm text-brand-600 hover:underline"
          >
            Tümünü gör →
          </button>
        </div>

        {isLoading ? (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-12 bg-gray-100 rounded-lg animate-pulse" />
            ))}
          </div>
        ) : recentSurveys.length === 0 ? (
          <div className="text-center py-10">
            <p className="text-4xl mb-3">📭</p>
            <p className="text-gray-600 font-medium">Henüz anket oluşturulmadı</p>
            <p className="text-sm text-gray-400 mt-1">
              İlk anketinizi oluşturmak için "Yeni Anket" butonuna tıklayın.
            </p>
            <button
              onClick={() => navigate('/portal/surveys/new')}
              className="btn-primary mt-4 text-sm"
            >
              İlk Anketi Oluştur
            </button>
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {recentSurveys.map((survey) => (
              <div key={survey.id} className="flex items-center gap-3 py-3">
                <span className="text-2xl">{survey.emoji || '📊'}</span>
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-gray-900 truncate">{survey.title}</p>
                  <p className="text-xs text-gray-400">{survey.responseCount ?? 0} yanıt</p>
                </div>
                <StatusBadge status={survey.status} />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

// ── Metric card ───────────────────────────────────────────────────────────────

function MetricCard({
  label, value, icon, color, loading,
}: {
  label: string; value: number; icon: string; color: 'green' | 'blue' | 'gray'; loading: boolean
}) {
  const colorMap = {
    green: 'bg-green-50 text-green-700',
    blue:  'bg-blue-50 text-blue-700',
    gray:  'bg-gray-50 text-gray-600',
  }
  return (
    <div className="card flex items-center gap-4">
      <div className={`w-10 h-10 rounded-xl flex items-center justify-center text-xl ${colorMap[color]}`}>
        {icon}
      </div>
      <div>
        <p className="text-sm text-gray-500">{label}</p>
        {loading ? (
          <div className="h-7 w-10 bg-gray-200 rounded animate-pulse mt-0.5" />
        ) : (
          <p className="text-2xl font-bold text-gray-900">{value}</p>
        )}
      </div>
    </div>
  )
}
