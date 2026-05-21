import { useParams, useNavigate } from 'react-router-dom'
import { useDocument, useCollection, where } from '../../hooks/useFirestore'
import { SurveyDoc, SurveyResponseDoc, SurveyQuestion } from './types'
import { StatusBadge } from './PortalDashboardPage'

export default function PortalSurveyResultsPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  const { data: survey, isLoading: surveyLoading } =
    useDocument<SurveyDoc>('surveys', id ?? null)

  const { data: responses = [], isLoading: responsesLoading } =
    useCollection<SurveyResponseDoc>(
      'survey_responses',
      id ? [where('surveyId', '==', id)] : [],
      ['survey_responses', id],
    )

  const isLoading      = surveyLoading || responsesLoading
  const responseCount  = responses.length
  const threshold      = survey?.minNThreshold ?? 5
  const isLocked       = responseCount < threshold

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-brand-600 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!survey) {
    return (
      <div className="text-center py-20">
        <p className="text-gray-500">Anket bulunamadı.</p>
        <button onClick={() => navigate('/portal/surveys')} className="btn-primary mt-4">
          Geri Dön
        </button>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-start gap-3">
        <button
          onClick={() => navigate('/portal/surveys')}
          className="text-gray-400 hover:text-gray-600 text-sm mt-1"
        >
          ← Geri
        </button>
        <div className="flex-1">
          <div className="flex items-center gap-2 flex-wrap">
            <h1 className="text-2xl font-bold text-gray-900">
              {survey.emoji} {survey.title}
            </h1>
            <StatusBadge status={survey.status} />
          </div>
          {survey.description && (
            <p className="text-sm text-gray-500 mt-0.5">{survey.description}</p>
          )}
        </div>
      </div>

      {/* Response count card */}
      <div className="card flex items-center gap-4">
        <div className="w-12 h-12 bg-brand-50 rounded-xl flex items-center justify-center text-2xl">
          📊
        </div>
        <div>
          <p className="text-2xl font-bold text-gray-900">{responseCount}</p>
          <p className="text-sm text-gray-500">
            toplam yanıt · en az {threshold} gerekli
          </p>
        </div>
        {!isLocked && (
          <div className="ml-auto flex items-center gap-1.5 text-green-600 text-sm font-medium">
            <span className="w-2 h-2 rounded-full bg-green-500 inline-block" />
            Sonuçlar görünür
          </div>
        )}
      </div>

      {/* Results or locked state */}
      {isLocked ? (
        <div className="card text-center py-14">
          <p className="text-5xl mb-4">🔒</p>
          <h2 className="text-lg font-semibold text-gray-900 mb-2">
            Sonuçlar Henüz Görüntülenemiyor
          </h2>
          <p className="text-sm text-gray-500 max-w-sm mx-auto leading-relaxed">
            Çalışan gizliliğini korumak için sonuçlar en az{' '}
            <strong>{threshold}</strong> yanıt olduğunda görüntülenir.
            Şu an <strong>{responseCount}</strong> yanıt var;{' '}
            <strong>{threshold - responseCount}</strong> yanıt daha bekleniyor.
          </p>

          {/* Progress bar */}
          <div className="mt-6 max-w-xs mx-auto">
            <div className="bg-gray-100 rounded-full h-2.5">
              <div
                className="bg-brand-500 h-2.5 rounded-full transition-all"
                style={{ width: `${Math.min((responseCount / threshold) * 100, 100)}%` }}
              />
            </div>
            <p className="text-xs text-gray-400 mt-2">
              {responseCount} / {threshold}
            </p>
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          {survey.questions.map((q, idx) => {
            const answers = responses
              .map((r) => r.answers[q.id])
              .filter((a) => a !== undefined && a !== null)
            return (
              <div key={q.id} className="card">
                <p className="text-xs text-gray-400 mb-1 font-medium uppercase tracking-wide">
                  Soru {idx + 1}
                </p>
                <p className="font-semibold text-gray-900 mb-1">{q.text}</p>
                {q.hint && (
                  <p className="text-xs text-gray-400 mb-4">{q.hint}</p>
                )}
                <QuestionResult
                  question={q}
                  answers={answers}
                  responseCount={responseCount}
                />
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

// ── Question result renderers ─────────────────────────────────────────────────

function QuestionResult({
  question,
  answers,
  responseCount,
}: {
  question: SurveyQuestion
  answers: unknown[]
  responseCount: number
}) {
  if (answers.length === 0) {
    return <p className="text-sm text-gray-400 italic">Bu soru için yanıt yok.</p>
  }

  const { type } = question

  if (type === 'emoji5' || type === 'scale10' || type === 'scale5') {
    const max = type === 'scale10' ? 10 : 5
    return <NumericResult answers={answers} max={max} isEmoji={type === 'emoji5'} />
  }
  if (type === 'yesno') {
    return <YesNoResult answers={answers} trueLabel="Evet" falseLabel="Hayır" />
  }
  if (type === 'trueFalse') {
    return <YesNoResult answers={answers} trueLabel="Doğru" falseLabel="Yanlış" />
  }
  if (type === 'text') {
    return <TextResult answers={answers} responseCount={responseCount} />
  }

  return <p className="text-sm text-gray-400">Bu soru tipi desteklenmiyor.</p>
}

const _kEmojis = ['😞', '😕', '😐', '🙂', '😄']

function NumericResult({ answers, max, isEmoji = false }: { answers: unknown[]; max: number; isEmoji?: boolean }) {
  const nums = answers.filter((a) => typeof a === 'number') as number[]
  if (nums.length === 0) return <p className="text-sm text-gray-400 italic">Sayısal yanıt yok.</p>

  const avg = nums.reduce((s, n) => s + n, 0) / nums.length

  const dist: Record<number, number> = {}
  for (let i = 1; i <= max; i++) dist[i] = 0
  nums.forEach((n) => { dist[Math.round(n)] = (dist[Math.round(n)] ?? 0) + 1 })
  const maxCount = Math.max(...Object.values(dist), 1)

  return (
    <div>
      <div className="flex items-baseline gap-2 mb-5">
        <span className="text-3xl font-bold text-gray-900">{avg.toFixed(1)}</span>
        <span className="text-sm text-gray-400">/ {max} ortalama</span>
        <span className="text-sm text-gray-400 ml-auto">{nums.length} yanıt</span>
      </div>
      <div className="space-y-2">
        {Object.entries(dist).map(([val, count]) => (
          <div key={val} className="flex items-center gap-2.5">
            <span className="text-xs text-gray-500 w-8 text-right font-medium">
              {isEmoji ? (_kEmojis[parseInt(val) - 1] ?? val) : val}
            </span>
            <div className="flex-1 bg-gray-100 rounded-full h-2.5 overflow-hidden">
              <div
                className="bg-brand-500 h-2.5 rounded-full transition-all"
                style={{ width: `${(count / maxCount) * 100}%` }}
              />
            </div>
            <span className="text-xs text-gray-400 w-8 text-right">
              {count > 0 ? count : '—'}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}

function YesNoResult({
  answers,
  trueLabel,
  falseLabel,
}: {
  answers: unknown[]
  trueLabel: string
  falseLabel: string
}) {
  const bools = answers.filter((a) => typeof a === 'boolean') as boolean[]
  if (bools.length === 0) return <p className="text-sm text-gray-400 italic">Yanıt yok.</p>

  const yes    = bools.filter(Boolean).length
  const no     = bools.length - yes
  const yesPct = Math.round((yes / bools.length) * 100)
  const noPct  = 100 - yesPct

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-3">
        <span className="text-sm font-semibold text-gray-700 w-16">{trueLabel}</span>
        <div className="flex-1 bg-gray-100 rounded-full h-3 overflow-hidden">
          <div className="bg-green-500 h-3 rounded-full" style={{ width: `${yesPct}%` }} />
        </div>
        <span className="text-sm text-gray-600 w-24 text-right">
          {yes} yanıt (%{yesPct})
        </span>
      </div>
      <div className="flex items-center gap-3">
        <span className="text-sm font-semibold text-gray-700 w-16">{falseLabel}</span>
        <div className="flex-1 bg-gray-100 rounded-full h-3 overflow-hidden">
          <div className="bg-red-400 h-3 rounded-full" style={{ width: `${noPct}%` }} />
        </div>
        <span className="text-sm text-gray-600 w-24 text-right">
          {no} yanıt (%{noPct})
        </span>
      </div>
    </div>
  )
}

function TextResult({
  answers,
  responseCount,
}: {
  answers: unknown[]
  responseCount: number
}) {
  const texts = answers.filter(
    (a) => typeof a === 'string' && (a as string).trim().length > 0,
  ) as string[]

  return (
    <div>
      <p className="text-xs text-gray-400 mb-3">{texts.length} metin yanıtı</p>
      <div className="space-y-2 max-h-72 overflow-y-auto pr-1">
        {texts.map((t, i) => (
          <div key={i} className="bg-gray-50 rounded-lg px-3 py-2.5 text-sm text-gray-700 border border-gray-100">
            {t}
          </div>
        ))}
        {texts.length === 0 && responseCount > 0 && (
          <p className="text-sm text-gray-400 italic">
            Çalışanlar bu soruya metin yanıtı vermedi.
          </p>
        )}
      </div>
    </div>
  )
}
