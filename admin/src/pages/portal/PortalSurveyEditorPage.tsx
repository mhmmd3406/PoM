import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  doc, addDoc, updateDoc, getDoc, collection, serverTimestamp,
} from 'firebase/firestore'
import { useAuth } from '../../hooks/useAuth'
import { db } from '../../firebase'
import { SurveyQuestion, QuestionType } from './types'

const EMOJIS = [
  '📊', '😊', '🎯', '💼', '🚀', '❤️',
  '✅', '🌟', '🔔', '📝', '💡', '🏆',
  '🤝', '🎓', '🧘', '⚡',
]

const QUESTION_TYPES: { value: QuestionType; label: string; icon: string }[] = [
  { value: 'emoji5',    label: '5 Emoji  (😞 → 😄)',  icon: '😊' },
  { value: 'scale10',   label: 'Ölçek  (1 – 10)',      icon: '🔢' },
  { value: 'scale5',    label: 'Ölçek  (1 – 5)',       icon: '5️⃣'  },
  { value: 'yesno',     label: 'Evet / Hayır',         icon: '✓✗' },
  { value: 'trueFalse', label: 'Doğru / Yanlış',       icon: 'D/Y' },
  { value: 'text',      label: 'Serbest Metin',        icon: '💬' },
]

// ─── Live preview ─────────────────────────────────────────────────────────────

function QuestionPreview({
  question,
  idx,
  total,
  surveyTitle,
}: {
  question: SurveyQuestion | null
  idx: number
  total: number
  surveyTitle: string
}) {
  const pct = total > 0 ? Math.round(((idx + 1) / total) * 100) : 0

  return (
    <div className="rounded-2xl border border-gray-200 bg-white overflow-hidden shadow-sm">
      {/* Phone-like header */}
      <div className="bg-gray-50 border-b border-gray-100 px-4 py-3">
        <div className="flex items-center justify-between mb-1.5">
          <span className="text-xs font-bold text-gray-400 tracking-wide">
            SORU {idx + 1} / {total} · {pct}%
          </span>
          <span className="text-xs text-gray-400">✕</span>
        </div>
        <div className="bg-gray-200 rounded-full h-1.5 overflow-hidden">
          <div
            className="bg-brand-500 h-1.5 rounded-full transition-all duration-300"
            style={{ width: `${pct}%` }}
          />
        </div>
      </div>

      {/* Question body */}
      <div className="px-4 py-5">
        {/* Survey source chip */}
        <div className="inline-flex items-center gap-1.5 bg-gray-100 rounded-lg px-2.5 py-1 mb-4">
          <span className="text-xs text-gray-500 font-medium">
            {surveyTitle || 'Anket Başlığı'} · Platform
          </span>
        </div>

        {/* Question text */}
        <p className="text-lg font-bold text-gray-900 leading-snug mb-2">
          {question?.text || <span className="text-gray-300">Soru metni…</span>}
        </p>
        {question?.hint && (
          <p className="text-sm text-gray-500 mb-4">{question.hint}</p>
        )}

        <div className="mt-5">
          <PreviewInput type={question?.type ?? 'emoji5'} />
        </div>
      </div>

      {/* Bottom nav */}
      <div className="px-4 pb-5 flex items-center justify-between">
        <span className="text-sm text-gray-400 font-medium">← Geri</span>
        <div className="bg-brand-500 text-white text-sm font-bold px-5 py-2 rounded-xl">
          İleri →
        </div>
      </div>
    </div>
  )
}

function PreviewInput({ type }: { type: QuestionType }) {
  switch (type) {
    case 'emoji5':
      return (
        <div className="flex gap-2">
          {['😞', '😕', '😐', '🙂', '😄'].map((e, i) => (
            <div
              key={i}
              className="flex-1 aspect-square rounded-xl border border-gray-200 bg-gray-50 flex items-center justify-center text-2xl"
            >
              {e}
            </div>
          ))}
        </div>
      )
    case 'scale5':
      return (
        <div className="flex gap-2">
          {[1, 2, 3, 4, 5].map((n) => (
            <div
              key={n}
              className="flex-1 aspect-square rounded-full border border-gray-200 bg-gray-50 flex items-center justify-center font-bold text-gray-700"
            >
              {n}
            </div>
          ))}
        </div>
      )
    case 'scale10':
      return (
        <div className="flex flex-wrap gap-1.5">
          {Array.from({ length: 11 }, (_, i) => (
            <div
              key={i}
              className="w-9 h-9 rounded-full border border-gray-200 bg-gray-50 flex items-center justify-center text-xs font-bold text-gray-700"
            >
              {i}
            </div>
          ))}
        </div>
      )
    case 'yesno':
      return (
        <div className="flex gap-3">
          <div className="flex-1 h-14 rounded-xl border-2 border-green-200 bg-green-50 flex items-center justify-center font-bold text-green-700 text-base">
            Evet
          </div>
          <div className="flex-1 h-14 rounded-xl border-2 border-red-200 bg-red-50 flex items-center justify-center font-bold text-red-500 text-base">
            Hayır
          </div>
        </div>
      )
    case 'trueFalse':
      return (
        <div className="flex gap-3">
          <div className="flex-1 h-14 rounded-xl border-2 border-green-200 bg-green-50 flex items-center justify-center font-bold text-green-700 text-base">
            Doğru
          </div>
          <div className="flex-1 h-14 rounded-xl border-2 border-red-200 bg-red-50 flex items-center justify-center font-bold text-red-500 text-base">
            Yanlış
          </div>
        </div>
      )
    case 'text':
      return (
        <div className="w-full h-20 rounded-xl border border-gray-200 bg-gray-50 flex items-start p-3">
          <span className="text-gray-300 text-sm">Yanıtını buraya yaz…</span>
        </div>
      )
  }
}

// ─── Editor page ──────────────────────────────────────────────────────────────

export default function PortalSurveyEditorPage() {
  const { id } = useParams<{ id?: string }>()
  const isEdit = !!id
  const navigate = useNavigate()
  const { authState } = useAuth()
  // super_admin has no companyId — their surveys are platform-wide ('__admin__')
  const companyId = authState.status === 'authenticated'
    ? (authState.companyId ?? '__admin__')
    : undefined

  const [emoji, setEmoji]           = useState('📊')
  const [title, setTitle]           = useState('')
  const [desc, setDesc]             = useState('')
  const [deadline, setDeadline]     = useState('')
  const [minN, setMinN]             = useState(5)
  const [questions, setQuestions]   = useState<SurveyQuestion[]>([
    { id: crypto.randomUUID(), text: '', type: 'emoji5', hint: '' },
  ])
  const [focusedIdx, setFocusedIdx] = useState(0)
  const [loading, setLoading]       = useState(false)
  const [fetching, setFetching]     = useState(isEdit)
  const [error, setError]           = useState<string | null>(null)

  useEffect(() => {
    if (!isEdit || !id) return
    setFetching(true)
    getDoc(doc(db, 'surveys', id))
      .then((snap) => {
        if (!snap.exists()) { navigate('/portal/surveys'); return }
        const d = snap.data()
        setEmoji(d.emoji ?? '📊')
        setTitle(d.title ?? '')
        setDesc(d.description ?? '')
        setMinN(d.minNThreshold ?? 5)
        if (d.deadline) {
          const date = d.deadline.toDate
            ? d.deadline.toDate()
            : new Date(d.deadline.seconds * 1000)
          setDeadline(date.toISOString().slice(0, 10))
        }
        if (d.questions?.length) {
          setQuestions(d.questions)
          setFocusedIdx(0)
        }
      })
      .catch(() => navigate('/portal/surveys'))
      .finally(() => setFetching(false))
  }, [id, isEdit, navigate])

  const addQuestion = () => {
    const newIdx = questions.length
    setQuestions((prev) => [
      ...prev,
      { id: crypto.randomUUID(), text: '', type: 'emoji5', hint: '' },
    ])
    setFocusedIdx(newIdx)
  }

  const removeQuestion = (qid: string) => {
    setQuestions((prev) => {
      const next = prev.filter((q) => q.id !== qid)
      if (focusedIdx >= next.length) setFocusedIdx(Math.max(0, next.length - 1))
      return next
    })
  }

  const updateQuestion = (qid: string, patch: Partial<SurveyQuestion>) => {
    const idx = questions.findIndex((q) => q.id === qid)
    if (idx !== -1) setFocusedIdx(idx)
    setQuestions((prev) => prev.map((q) => (q.id === qid ? { ...q, ...patch } : q)))
  }

  const moveQuestion = (index: number, dir: -1 | 1) =>
    setQuestions((prev) => {
      const next = [...prev]
      const target = index + dir
      if (target < 0 || target >= next.length) return prev
      ;[next[index], next[target]] = [next[target], next[index]]
      setFocusedIdx(target)
      return next
    })

  const save = async (status: 'draft' | 'active') => {
    if (!title.trim()) { setError('Anket başlığı zorunludur.'); return }
    if (questions.some((q) => !q.text.trim())) {
      setError('Tüm soruların metni doldurulmalıdır.')
      return
    }
    if (!companyId) { setError('Oturum bilgisi bulunamadı, lütfen yeniden giriş yapın.'); return }

    setLoading(true)
    setError(null)

    try {
      const deadlineVal = deadline ? new Date(deadline) : null
      const payload = {
        title:          title.trim(),
        description:    desc.trim(),
        emoji,
        questions,
        status,
        deadline:       deadlineVal,
        minNThreshold:  minN,
        updated_at:     serverTimestamp(),
      }

      if (isEdit && id) {
        await updateDoc(doc(db, 'surveys', id), payload)
      } else {
        await addDoc(collection(db, 'surveys'), {
          ...payload,
          companyId,
          responseCount: 0,
          created_at:    serverTimestamp(),
        })
      }

      navigate('/portal/surveys')
    } catch {
      setError('Kaydedilirken hata oluştu. Lütfen tekrar deneyin.')
    } finally {
      setLoading(false)
    }
  }

  if (fetching) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-brand-600 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  const focusedQuestion = questions[focusedIdx] ?? questions[0] ?? null

  return (
    <div className="max-w-5xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <button
          onClick={() => navigate('/portal/surveys')}
          className="text-gray-400 hover:text-gray-600 text-sm"
        >
          ← Geri
        </button>
        <h1 className="text-2xl font-bold text-gray-900">
          {isEdit ? 'Anketi Düzenle' : 'Yeni Anket'}
        </h1>
      </div>

      {/* 2-column layout on large screens */}
      <div className="lg:grid lg:grid-cols-[1fr_340px] lg:gap-6 space-y-6 lg:space-y-0">

        {/* ── Left: form ───────────────────────────────────────────────────── */}
        <div className="space-y-6">

          {/* Basic info */}
          <div className="card space-y-4">
            <h2 className="font-semibold text-gray-900">Genel Bilgiler</h2>

            {/* Emoji */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Emoji</label>
              <div className="flex flex-wrap gap-2">
                {EMOJIS.map((e) => (
                  <button
                    key={e}
                    type="button"
                    onClick={() => setEmoji(e)}
                    className={`w-10 h-10 rounded-lg text-xl flex items-center justify-center transition-colors ${
                      emoji === e
                        ? 'bg-brand-100 ring-2 ring-brand-500'
                        : 'bg-gray-50 hover:bg-gray-100'
                    }`}
                  >
                    {e}
                  </button>
                ))}
              </div>
            </div>

            {/* Title */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">Başlık *</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Aylık Çalışan Memnuniyeti Anketi"
                className="input-field"
              />
            </div>

            {/* Description */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">Açıklama</label>
              <textarea
                value={desc}
                onChange={(e) => setDesc(e.target.value)}
                placeholder="Bu anket hakkında kısa bir açıklama…"
                rows={2}
                className="input-field resize-none"
              />
            </div>

            {/* Deadline + MinN */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1.5">Son Tarih</label>
                <input
                  type="date"
                  value={deadline}
                  onChange={(e) => setDeadline(e.target.value)}
                  className="input-field"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1.5">
                  Min. Yanıt (Gizlilik)
                </label>
                <input
                  type="number"
                  min={3}
                  max={50}
                  value={minN}
                  onChange={(e) => setMinN(parseInt(e.target.value) || 5)}
                  className="input-field"
                />
                <p className="text-xs text-gray-400 mt-1">
                  Sonuçlar en az {minN} yanıt olduğunda görünür
                </p>
              </div>
            </div>
          </div>

          {/* Questions */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="font-semibold text-gray-900">Sorular ({questions.length})</h2>
              <span className="text-xs text-gray-400">Düzenlemek için soruya tıkla</span>
            </div>

            {questions.map((q, idx) => (
              <div
                key={q.id}
                onClick={() => setFocusedIdx(idx)}
                className={`card space-y-3 cursor-pointer transition-all ${
                  focusedIdx === idx
                    ? 'ring-2 ring-brand-500 border-brand-300'
                    : 'hover:border-gray-300'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-gray-500">Soru {idx + 1}</span>
                    {focusedIdx === idx && (
                      <span className="text-xs bg-brand-50 text-brand-600 font-semibold px-2 py-0.5 rounded-full">
                        Düzenleniyor
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-1">
                    <button
                      type="button"
                      onClick={(e) => { e.stopPropagation(); moveQuestion(idx, -1) }}
                      disabled={idx === 0}
                      className="p-1 rounded text-gray-400 hover:text-gray-600 disabled:opacity-30"
                      title="Yukarı taşı"
                    >
                      ↑
                    </button>
                    <button
                      type="button"
                      onClick={(e) => { e.stopPropagation(); moveQuestion(idx, 1) }}
                      disabled={idx === questions.length - 1}
                      className="p-1 rounded text-gray-400 hover:text-gray-600 disabled:opacity-30"
                      title="Aşağı taşı"
                    >
                      ↓
                    </button>
                    <button
                      type="button"
                      onClick={(e) => { e.stopPropagation(); removeQuestion(q.id) }}
                      disabled={questions.length === 1}
                      className="p-1 rounded text-red-400 hover:text-red-600 disabled:opacity-30"
                      title="Soruyu sil"
                    >
                      ✕
                    </button>
                  </div>
                </div>

                <input
                  type="text"
                  value={q.text}
                  onChange={(e) => updateQuestion(q.id, { text: e.target.value })}
                  onClick={(e) => e.stopPropagation()}
                  placeholder="Soru metni…"
                  className="input-field"
                />

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Yanıt Türü</label>
                    <select
                      value={q.type}
                      onChange={(e) => updateQuestion(q.id, { type: e.target.value as QuestionType })}
                      onClick={(e) => e.stopPropagation()}
                      className="input-field"
                    >
                      {QUESTION_TYPES.map((t) => (
                        <option key={t.value} value={t.value}>{t.label}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      İpucu (opsiyonel)
                    </label>
                    <input
                      type="text"
                      value={q.hint}
                      onChange={(e) => updateQuestion(q.id, { hint: e.target.value })}
                      onClick={(e) => e.stopPropagation()}
                      placeholder="Kullanıcıya yardımcı not…"
                      className="input-field"
                    />
                  </div>
                </div>
              </div>
            ))}

            <button
              type="button"
              onClick={addQuestion}
              className="w-full py-2.5 border-2 border-dashed border-gray-200 rounded-xl text-sm font-medium text-gray-500 hover:border-brand-300 hover:text-brand-600 transition-colors"
            >
              + Soru Ekle
            </button>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-2 rounded-lg bg-red-50 border border-red-200 px-3 py-2.5">
              <p className="text-sm text-red-700">{error}</p>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-3 pb-8">
            <button
              type="button"
              onClick={() => save('draft')}
              disabled={loading}
              className="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
            >
              {loading ? 'Kaydediliyor…' : 'Taslak Kaydet'}
            </button>
            <button
              type="button"
              onClick={() => save('active')}
              disabled={loading}
              className="flex-1 btn-primary disabled:opacity-50"
            >
              {loading ? 'Yayınlanıyor…' : 'Yayınla'}
            </button>
          </div>
        </div>

        {/* ── Right: live preview ───────────────────────────────────────────── */}
        <div className="hidden lg:block">
          <div className="sticky top-6 space-y-3">
            <div className="flex items-center justify-between px-1">
              <p className="text-xs font-bold text-gray-400 tracking-widest uppercase">
                Canlı Önizleme
              </p>
              <span className="text-xs text-gray-400">
                Soru {focusedIdx + 1} / {questions.length}
              </span>
            </div>
            <QuestionPreview
              question={focusedQuestion}
              idx={focusedIdx}
              total={questions.length}
              surveyTitle={title}
            />
          </div>
        </div>

      </div>
    </div>
  )
}
