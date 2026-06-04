import { useParams, useNavigate } from 'react-router-dom'
import { useDocument, useCollection, where } from '../../hooks/useFirestore'
import { useAuth } from '../../contexts/AuthContext'
import { SurveyDoc, SurveyResponseDoc, SurveyQuestion } from './types'
import { StatusBadge } from './PortalDashboardPage'

// ─── Scoring helpers ──────────────────────────────────────────────────────────

/** Normalize any answer to a 1–5 scale. Returns null for text / invalid. */
function normalizeAnswer(
  answer: unknown,
  type: SurveyQuestion['type'],
  reverseScore?: boolean,
): number | null {
  if (answer === null || answer === undefined) return null
  switch (type) {
    case 'scale5':
    case 'emoji5': {
      const n = typeof answer === 'number' ? answer : null
      if (n === null || n < 1 || n > 5) return null
      return n
    }
    case 'scale10': {
      const n = typeof answer === 'number' ? answer : null
      if (n === null || n < 0 || n > 10) return null
      // Map 0–10 → 1–5 linearly: score = (n/10)*4 + 1
      return (n / 10) * 4 + 1
    }
    case 'yesno':
    case 'trueFalse': {
      if (typeof answer !== 'boolean') return null
      // reverseScore=true: positively-framed Evet is bad (mobbing, overtime, etc.)
      return answer ? (reverseScore ? 1 : 5) : (reverseScore ? 5 : 1)
    }
    default:
      return null // text questions carry no numeric score
  }
}

interface CategoryResult {
  name: string
  score: number   // 1–5 average
  count: number   // number of questions contributing
}

function calcCategoryScores(
  questions: SurveyQuestion[],
  responses: SurveyResponseDoc[],
): CategoryResult[] {
  // per-category → per-question → per-response averages
  const catMap = new Map<string, number[]>()

  for (const q of questions) {
    const cat = q.category?.trim()
    if (!cat || q.type === 'text') continue

    const scores: number[] = []
    for (const r of responses) {
      const norm = normalizeAnswer(r.answers[q.id], q.type, q.reverseScore)
      if (norm !== null) scores.push(norm)
    }
    if (scores.length === 0) continue

    const qAvg = scores.reduce((a, b) => a + b, 0) / scores.length
    if (!catMap.has(cat)) catMap.set(cat, [])
    catMap.get(cat)!.push(qAvg)
  }

  return Array.from(catMap.entries()).map(([name, avgs]) => ({
    name,
    score: avgs.reduce((a, b) => a + b, 0) / avgs.length,
    count: avgs.length,
  }))
}

interface EnpsResult {
  promoters: number
  passives: number
  detractors: number
  total: number
  enps: number // –100 to +100
}

function calcEnps(
  question: SurveyQuestion,
  responses: SurveyResponseDoc[],
): EnpsResult | null {
  const scores = responses
    .map(r => r.answers[question.id])
    .filter((a): a is number => typeof a === 'number' && a >= 0 && a <= 10)

  if (scores.length === 0) return null

  const promoters  = scores.filter(s => s >= 9).length
  const passives   = scores.filter(s => s >= 7 && s <= 8).length
  const detractors = scores.filter(s => s <= 6).length
  const total      = scores.length
  const enps = Math.round(
    (promoters / total) * 100 - (detractors / total) * 100,
  )
  return { promoters, passives, detractors, total, enps }
}

// ─── Band helpers ─────────────────────────────────────────────────────────────

interface Band {
  label: string
  textCls: string
  bgCls: string
  borderCls: string
  barCls: string
}

function scoreBand(score: number): Band {
  if (score >= 4.21) return { label: 'Çok Yüksek', textCls: 'text-green-700',   bgCls: 'bg-green-50',   borderCls: 'border-green-200',  barCls: 'bg-green-500'  }
  if (score >= 3.41) return { label: 'Yüksek',     textCls: 'text-emerald-700', bgCls: 'bg-emerald-50', borderCls: 'border-emerald-200', barCls: 'bg-emerald-500'}
  if (score >= 2.61) return { label: 'Orta',       textCls: 'text-yellow-700',  bgCls: 'bg-yellow-50',  borderCls: 'border-yellow-200',  barCls: 'bg-yellow-400' }
  if (score >= 1.81) return { label: 'Düşük',      textCls: 'text-orange-700',  bgCls: 'bg-orange-50',  borderCls: 'border-orange-200',  barCls: 'bg-orange-500' }
  return               { label: 'Çok Düşük',   textCls: 'text-red-700',    bgCls: 'bg-red-50',     borderCls: 'border-red-200',     barCls: 'bg-red-500'    }
}

interface RiskLevel {
  label: string
  dotCls: string
  textCls: string
}

function riskLevel(score: number): RiskLevel {
  if (score >= 4.2) return { label: 'Düşük Risk',      dotCls: 'bg-green-500',   textCls: 'text-green-700'   }
  if (score >= 3.5) return { label: 'İzleme Gerekli',  dotCls: 'bg-emerald-500', textCls: 'text-emerald-700' }
  if (score >= 2.8) return { label: 'Orta Risk',       dotCls: 'bg-yellow-400',  textCls: 'text-yellow-700'  }
  if (score >= 2.0) return { label: 'Yüksek Risk',     dotCls: 'bg-orange-500',  textCls: 'text-orange-700'  }
  return               { label: 'Kritik Risk',      dotCls: 'bg-red-500',     textCls: 'text-red-700'     }
}

// ─── Subcomponents ────────────────────────────────────────────────────────────

function OverallSummary({
  overall,
  top3,
  bottom3,
}: {
  overall: number
  top3: CategoryResult[]
  bottom3: CategoryResult[]
}) {
  const band = scoreBand(overall)
  return (
    <div className="card space-y-5">
      <h2 className="text-base font-bold text-gray-900">Yönetim Özeti</h2>

      {/* Overall score */}
      <div className={`flex items-center gap-4 p-4 rounded-xl border ${band.bgCls} ${band.borderCls}`}>
        <div className="w-14 h-14 rounded-2xl bg-white/70 flex flex-col items-center justify-center shadow-sm">
          <span className={`text-xl font-bold ${band.textCls}`}>{overall.toFixed(1)}</span>
          <span className="text-xs text-gray-400">/ 5</span>
        </div>
        <div>
          <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">Genel Memnuniyet</p>
          <p className={`text-lg font-bold ${band.textCls}`}>{band.label}</p>
          <p className="text-xs text-gray-400 mt-0.5">Tüm kategorilerin ağırlıksız ortalaması</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        {/* Top 3 strongest */}
        <div>
          <p className="text-xs font-bold text-green-600 uppercase tracking-wide mb-2">En Güçlü 3 Alan</p>
          <div className="space-y-1.5">
            {top3.length === 0 && <p className="text-xs text-gray-400 italic">Kategori verisi yok</p>}
            {top3.map(c => (
              <div key={c.name} className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-green-500 flex-shrink-0" />
                <span className="text-xs text-gray-700 truncate flex-1">{c.name}</span>
                <span className="text-xs font-bold text-green-700 flex-shrink-0">{c.score.toFixed(1)}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Bottom 3 riskiest */}
        <div>
          <p className="text-xs font-bold text-red-600 uppercase tracking-wide mb-2">En Riskli 3 Alan</p>
          <div className="space-y-1.5">
            {bottom3.length === 0 && <p className="text-xs text-gray-400 italic">Kategori verisi yok</p>}
            {bottom3.map(c => (
              <div key={c.name} className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-red-500 flex-shrink-0" />
                <span className="text-xs text-gray-700 truncate flex-1">{c.name}</span>
                <span className="text-xs font-bold text-red-700 flex-shrink-0">{c.score.toFixed(1)}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}

function EnpsCard({ result, questionText }: { result: EnpsResult; questionText: string }) {
  const promoterPct  = Math.round((result.promoters  / result.total) * 100)
  const passivePct   = Math.round((result.passives   / result.total) * 100)
  const detractorPct = Math.round((result.detractors / result.total) * 100)
  const enpsColor    = result.enps >= 30 ? 'text-green-600' : result.enps >= 0 ? 'text-emerald-600' : 'text-red-600'
  const enpsLabel    = result.enps >= 50 ? 'Olağanüstü' : result.enps >= 30 ? 'Çok İyi' : result.enps >= 10 ? 'İyi' : result.enps >= 0 ? 'Gelişim Gerekli' : 'Kritik'

  return (
    <div className="card space-y-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="text-base font-bold text-gray-900">eNPS</h2>
          <p className="text-xs text-gray-400 mt-0.5 max-w-xs leading-snug">{questionText}</p>
        </div>
        <div className="text-right flex-shrink-0">
          <p className={`text-4xl font-bold tabular-nums ${enpsColor}`}>
            {result.enps >= 0 ? '+' : ''}{result.enps}
          </p>
          <p className={`text-xs font-semibold ${enpsColor}`}>{enpsLabel}</p>
        </div>
      </div>

      {/* Promoters / Passives / Detractors bars */}
      <div className="space-y-2.5">
        <GroupBar label="Destekleyenler" sublabel="9–10" count={result.promoters}  pct={promoterPct}  barCls="bg-green-500" textCls="text-green-700" />
        <GroupBar label="Pasifler"       sublabel="7–8"  count={result.passives}   pct={passivePct}   barCls="bg-gray-300"  textCls="text-gray-500" />
        <GroupBar label="Eleştirenler"   sublabel="0–6"  count={result.detractors} pct={detractorPct} barCls="bg-red-400"   textCls="text-red-700" />
      </div>

      <p className="text-xs text-gray-400">
        Formül: % Destekleyenler − % Eleştirenler = {promoterPct}% − {detractorPct}% = {result.enps >= 0 ? '+' : ''}{result.enps}
      </p>
    </div>
  )
}

function GroupBar({
  label, sublabel, count, pct, barCls, textCls,
}: {
  label: string; sublabel: string; count: number; pct: number
  barCls: string; textCls: string
}) {
  return (
    <div className="flex items-center gap-3">
      <div className="w-28 flex-shrink-0">
        <span className="text-sm font-medium text-gray-700">{label}</span>
        <span className="ml-1.5 text-xs text-gray-400">{sublabel}</span>
      </div>
      <div className="flex-1 bg-gray-100 rounded-full h-3 overflow-hidden">
        <div className={`${barCls} h-3 rounded-full transition-all`} style={{ width: `${pct}%` }} />
      </div>
      <span className={`text-xs font-bold w-20 text-right ${textCls}`}>
        {count} kişi (%{pct})
      </span>
    </div>
  )
}

function CategoryHeatmap({ categories }: { categories: CategoryResult[] }) {
  const sorted = [...categories].sort((a, b) => b.score - a.score)

  return (
    <div className="card space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-base font-bold text-gray-900">Kategori Skorları</h2>
        <div className="flex items-center gap-3 text-xs text-gray-400">
          <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-green-500 inline-block" />Düşük Risk ≥4.2</span>
          <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-yellow-400 inline-block" />Orta ≥2.8</span>
          <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-red-500 inline-block" />Kritik &lt;2.0</span>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {sorted.map(cat => {
          const band = scoreBand(cat.score)
          const risk = riskLevel(cat.score)
          const barWidth = `${((cat.score - 1) / 4) * 100}%`
          return (
            <div key={cat.name} className={`rounded-xl p-3.5 border ${band.bgCls} ${band.borderCls}`}>
              <p className="text-xs text-gray-600 font-medium mb-1 leading-snug">{cat.name}</p>
              <div className="flex items-baseline gap-1.5 mb-2">
                <span className={`text-2xl font-bold ${band.textCls}`}>{cat.score.toFixed(2)}</span>
                <span className="text-xs text-gray-400">/ 5</span>
              </div>
              {/* Mini bar */}
              <div className="h-1.5 bg-white/60 rounded-full overflow-hidden mb-2">
                <div className={`${band.barCls} h-1.5 rounded-full`} style={{ width: barWidth }} />
              </div>
              <div className="flex items-center gap-1.5">
                <span className={`w-2 h-2 rounded-full ${risk.dotCls} flex-shrink-0`} />
                <span className={`text-xs font-semibold ${risk.textCls}`}>{risk.label}</span>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

function TrendDisclaimer({ measurementCount }: { measurementCount: number }) {
  if (measurementCount >= 2) return null
  return (
    <div className="flex items-start gap-3 rounded-xl bg-blue-50 border border-blue-100 px-4 py-3.5">
      <span className="text-blue-400 text-lg flex-shrink-0">📈</span>
      <div>
        <p className="text-sm font-semibold text-blue-800">Trend analizi için en az 2 ölçüm gerekiyor</p>
        <p className="text-xs text-blue-600 mt-0.5 leading-relaxed">
          Bu ilk ölçümdür. Anket tekrarlandığında değişim trendleri, ani kırılmalar ve
          departman bazlı karşılaştırmalar otomatik olarak hesaplanacaktır.
        </p>
      </div>
    </div>
  )
}

// ─── Per-question result renderers (kept from original) ───────────────────────

const _kEmojis = ['😞', '😕', '😐', '🙂', '😄']

function NumericResult({ answers, max, isEmoji = false }: { answers: unknown[]; max: number; isEmoji?: boolean }) {
  const nums = answers.filter((a) => typeof a === 'number') as number[]
  if (nums.length === 0) return <p className="text-sm text-gray-400 italic">Sayısal yanıt yok.</p>

  const avg = nums.reduce((s, n) => s + n, 0) / nums.length
  const dist: Record<number, number> = {}
  for (let i = 1; i <= max; i++) dist[i] = 0
  if (max === 10) dist[0] = 0
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
            <span className="text-xs text-gray-400 w-8 text-right">{count > 0 ? count : '—'}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function YesNoResult({ answers, trueLabel, falseLabel }: { answers: unknown[]; trueLabel: string; falseLabel: string }) {
  const bools = answers.filter((a) => typeof a === 'boolean') as boolean[]
  if (bools.length === 0) return <p className="text-sm text-gray-400 italic">Yanıt yok.</p>

  const yes = bools.filter(Boolean).length
  const no = bools.length - yes
  const yesPct = Math.round((yes / bools.length) * 100)
  const noPct = 100 - yesPct

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-3">
        <span className="text-sm font-semibold text-gray-700 w-16">{trueLabel}</span>
        <div className="flex-1 bg-gray-100 rounded-full h-3 overflow-hidden">
          <div className="bg-green-500 h-3 rounded-full" style={{ width: `${yesPct}%` }} />
        </div>
        <span className="text-sm text-gray-600 w-24 text-right">{yes} yanıt (%{yesPct})</span>
      </div>
      <div className="flex items-center gap-3">
        <span className="text-sm font-semibold text-gray-700 w-16">{falseLabel}</span>
        <div className="flex-1 bg-gray-100 rounded-full h-3 overflow-hidden">
          <div className="bg-red-400 h-3 rounded-full" style={{ width: `${noPct}%` }} />
        </div>
        <span className="text-sm text-gray-600 w-24 text-right">{no} yanıt (%{noPct})</span>
      </div>
    </div>
  )
}

function TextResult({ answers, responseCount }: { answers: unknown[]; responseCount: number }) {
  const texts = answers.filter(
    (a): a is string => typeof a === 'string' && (a as string).trim().length > 0,
  )
  return (
    <div>
      <p className="text-xs text-gray-400 mb-3">{texts.length} metin yanıtı</p>
      <div className="space-y-2 max-h-72 overflow-y-auto pr-1">
        {texts.map((t, i) => (
          <div key={i} className="bg-gray-50 rounded-lg px-3 py-2.5 text-sm text-gray-700 border border-gray-100">{t}</div>
        ))}
        {texts.length === 0 && responseCount > 0 && (
          <p className="text-sm text-gray-400 italic">Metin yanıtı verilmedi.</p>
        )}
      </div>
    </div>
  )
}

function QuestionResult({ question, answers, responseCount }: { question: SurveyQuestion; answers: unknown[]; responseCount: number }) {
  if (answers.length === 0) return <p className="text-sm text-gray-400 italic">Bu soru için yanıt yok.</p>
  const { type } = question
  if (type === 'emoji5' || type === 'scale10' || type === 'scale5') {
    return <NumericResult answers={answers} max={type === 'scale10' ? 10 : 5} isEmoji={type === 'emoji5'} />
  }
  if (type === 'yesno')     return <YesNoResult answers={answers} trueLabel="Evet"  falseLabel="Hayır"  />
  if (type === 'trueFalse') return <YesNoResult answers={answers} trueLabel="Doğru" falseLabel="Yanlış" />
  if (type === 'text')      return <TextResult  answers={answers} responseCount={responseCount} />
  return <p className="text-sm text-gray-400">Desteklenmeyen soru tipi.</p>
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function PortalSurveyResultsPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  const { authState } = useAuth()
  // company_admin tokens carry a company_id claim; super_admin (is_admin) does not.
  const companyId = authState.status === 'authenticated' ? authState.companyId : undefined

  const { data: survey, isLoading: surveyLoading } =
    useDocument<SurveyDoc>('surveys', id ?? null)

  // survey_responses read is company-scoped in the security rules
  // (isAdmin() || isCompanyMember(companyId)). Firestore rules are not filters,
  // so a company_admin MUST constrain the query by companyId for it to pass;
  // super_admin matches via isAdmin() and needs no companyId filter.
  const { data: responses = [], isLoading: responsesLoading } =
    useCollection<SurveyResponseDoc>(
      'survey_responses',
      id
        ? (companyId
            ? [where('surveyId', '==', id), where('companyId', '==', companyId)]
            : [where('surveyId', '==', id)])
        : [],
      ['survey_responses', id, companyId ?? ''],
    )

  const isLoading     = surveyLoading || responsesLoading
  const responseCount = responses.length
  const threshold     = survey?.minNThreshold ?? 5
  const isLocked      = responseCount < threshold

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
        <button onClick={() => navigate('/portal/surveys')} className="btn-primary mt-4">Geri Dön</button>
      </div>
    )
  }

  // ── Scoring (only computed when results are unlocked) ──────────────────────
  const categories  = isLocked ? [] : calcCategoryScores(survey.questions, responses)
  const hasCategories = categories.length > 0
  const enpsQuestion  = survey.questions.find(q => q.isEnps && q.type === 'scale10')
  const enpsResult    = (!isLocked && enpsQuestion) ? calcEnps(enpsQuestion, responses) : null

  const sortedCats = [...categories].sort((a, b) => b.score - a.score)
  const top3       = sortedCats.slice(0, 3)
  const bottom3    = sortedCats.length >= 3 ? [...sortedCats].sort((a, b) => a.score - b.score).slice(0, 3) : sortedCats.slice().reverse()

  const overallScore = hasCategories
    ? categories.reduce((s, c) => s + c.score, 0) / categories.length
    : null

  return (
    <div className="max-w-3xl mx-auto space-y-6">
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
            <h1 className="text-2xl font-bold text-gray-900">{survey.emoji} {survey.title}</h1>
            <StatusBadge status={survey.status} />
            {survey.isGate && (
              <span className="text-xs bg-blue-50 text-blue-700 border border-blue-100 font-medium px-2 py-0.5 rounded-full">
                🚪 Giriş Anketi{survey.isMandatory ? ' · Zorunlu' : ''}
              </span>
            )}
          </div>
          {survey.description && <p className="text-sm text-gray-500 mt-0.5">{survey.description}</p>}
        </div>
      </div>

      {/* Response count card */}
      <div className="card flex items-center gap-4">
        <div className="w-12 h-12 bg-brand-50 rounded-xl flex items-center justify-center text-2xl">📊</div>
        <div>
          <p className="text-2xl font-bold text-gray-900">{responseCount}</p>
          <p className="text-sm text-gray-500">toplam yanıt · en az {threshold} gerekli</p>
        </div>
        {!isLocked && (
          <div className="ml-auto flex items-center gap-1.5 text-green-600 text-sm font-medium">
            <span className="w-2 h-2 rounded-full bg-green-500 inline-block" />
            Sonuçlar görünür
          </div>
        )}
      </div>

      {/* Locked state */}
      {isLocked ? (
        <div className="card text-center py-14">
          <p className="text-5xl mb-4">🔒</p>
          <h2 className="text-lg font-semibold text-gray-900 mb-2">Sonuçlar Henüz Görüntülenemiyor</h2>
          <p className="text-sm text-gray-500 max-w-sm mx-auto leading-relaxed">
            Çalışan gizliliğini korumak için sonuçlar en az{' '}
            <strong>{threshold}</strong> yanıt olduğunda görüntülenir.
            Şu an <strong>{responseCount}</strong> yanıt var;{' '}
            <strong>{threshold - responseCount}</strong> yanıt daha bekleniyor.
          </p>
          <div className="mt-6 max-w-xs mx-auto">
            <div className="bg-gray-100 rounded-full h-2.5">
              <div
                className="bg-brand-500 h-2.5 rounded-full transition-all"
                style={{ width: `${Math.min((responseCount / threshold) * 100, 100)}%` }}
              />
            </div>
            <p className="text-xs text-gray-400 mt-2">{responseCount} / {threshold}</p>
          </div>
        </div>
      ) : (
        <div className="space-y-6">

          {/* Management summary */}
          {hasCategories && overallScore !== null && (
            <OverallSummary overall={overallScore} top3={top3} bottom3={bottom3} />
          )}

          {/* eNPS */}
          {enpsResult !== null && enpsQuestion && (
            <EnpsCard result={enpsResult} questionText={enpsQuestion.text} />
          )}

          {/* Category heatmap */}
          {hasCategories && <CategoryHeatmap categories={categories} />}

          {/* Trend disclaimer */}
          <TrendDisclaimer measurementCount={1} />

          {/* Per-question detail */}
          <div className="space-y-4">
            <h2 className="text-base font-bold text-gray-900">Soru Bazlı Detay</h2>
            {survey.questions.map((q, idx) => {
              const answers = responses
                .map((r) => r.answers[q.id])
                .filter((a) => a !== undefined && a !== null)
              return (
                <div key={q.id} className="card">
                  <div className="flex items-start gap-2 mb-3">
                    <span className="text-xs text-gray-400 font-medium uppercase tracking-wide flex-shrink-0 mt-0.5">
                      Soru {idx + 1}
                    </span>
                    {q.category && (
                      <span className="text-xs bg-gray-100 text-gray-500 font-medium px-2 py-0.5 rounded-full">
                        {q.category}
                      </span>
                    )}
                    {q.isEnps && (
                      <span className="text-xs bg-purple-50 text-purple-600 font-medium px-2 py-0.5 rounded-full">
                        eNPS
                      </span>
                    )}
                  </div>
                  <p className="font-semibold text-gray-900 mb-1">{q.text}</p>
                  {q.hint && <p className="text-xs text-gray-400 mb-4">{q.hint}</p>}
                  <QuestionResult question={q} answers={answers} responseCount={responseCount} />
                </div>
              )
            })}
          </div>

        </div>
      )}
    </div>
  )
}
