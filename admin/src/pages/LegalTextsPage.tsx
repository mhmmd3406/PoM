import { useEffect, useState } from 'react'
import { useDocument, useSetDocument, serverTimestamp, Timestamp } from '../hooks/useFirestore'
import { useToast, Toast } from '../hooks/useToast'
import { useAuth } from '../hooks/useAuth'

// ── Config ───────────────────────────────────────────────────────────────────

const TEXTS: { key: string; label: string; required: boolean }[] = [
  { key: 'kvkk', label: 'KVKK Aydınlatma Metni', required: true },
  { key: 'privacy_policy', label: 'Gizlilik Politikası', required: true },
  { key: 'terms_of_service', label: 'Kullanım Şartları', required: true },
  { key: 'community_rules', label: 'Topluluk Kuralları', required: false },
  { key: 'fraud_policy', label: 'Sahte Veri Politikası', required: false },
]

const MIN_LENGTH = 10

type LegalTextsDoc = Record<string, string | Timestamp | undefined>

// ── Helpers ──────────────────────────────────────────────────────────────────

function tsToDateString(ts: Timestamp | undefined): string | null {
  if (!ts || typeof (ts as Timestamp).toDate !== 'function') return null
  return ts.toDate().toLocaleDateString('tr-TR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  })
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function LegalTextsPage() {
  const { authState } = useAuth()
  const uid = authState.status === 'authenticated' ? authState.user.uid : null
  const { toast, show } = useToast()

  const { data } = useDocument<LegalTextsDoc>('platform_config', 'legal_texts')
  const setLegal = useSetDocument('platform_config')

  const [active, setActive] = useState('kvkk')
  const [text, setText] = useState('')
  const [version, setVersion] = useState('')

  // Seed the editor whenever the active tab or the underlying doc changes.
  useEffect(() => {
    const d: LegalTextsDoc = data ?? {}
    setText((d[`${active}_text`] as string) ?? '')
    setVersion((d[`${active}_version`] as string) ?? '')
  }, [active, data])

  const handleSave = () => {
    const trimmed = text.trim()
    if (trimmed.length < MIN_LENGTH) {
      show(`Metin en az ${MIN_LENGTH} karakter olmalı`, 'err')
      return
    }
    const newVersion = version.trim() || `${Date.now()}`
    setLegal.mutate(
      {
        id: 'legal_texts',
        merge: true,
        data: {
          [`${active}_text`]: trimmed,
          [`${active}_version`]: newVersion,
          [`${active}_updated_at`]: serverTimestamp(),
          updated_by: uid,
        },
      },
      {
        onSuccess: () =>
          show('Metin güncellendi — kullanıcılar yeni versiyonu onaylamak zorunda kalacak ✓'),
        onError: (e) => show(e instanceof Error ? e.message : 'Kaydedilemedi', 'err'),
      },
    )
  }

  const cur = TEXTS.find((t) => t.key === active)
  const updatedAt = tsToDateString(data?.[`${active}_updated_at`] as Timestamp | undefined)

  return (
    <div className="space-y-5 max-w-3xl">
      <div>
        <h1 className="text-xl font-bold text-gray-900">📄 Hukuki Metinler</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          Bir metin güncellendiğinde, kayıtlı kullanıcılar uygulamada tekrar onay vermek zorunda
          kalır.
        </p>
      </div>

      {/* Tabs */}
      <div className="flex flex-wrap gap-2">
        {TEXTS.map((t) => (
          <button
            key={t.key}
            onClick={() => setActive(t.key)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              active === t.key
                ? 'bg-brand-600 text-white'
                : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
            }`}
          >
            {t.label}
            {t.required && <span className="text-red-400 ml-1">*</span>}
          </button>
        ))}
      </div>

      {/* Editor */}
      <div className="card p-5 space-y-4">
        <div className="flex items-center gap-2 flex-wrap">
          <h2 className="text-sm font-semibold text-gray-900">{cur?.label}</h2>
          {version && (
            <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-700">
              v{version}
            </span>
          )}
          {updatedAt && <span className="text-xs text-gray-400">— {updatedAt}</span>}
        </div>

        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">
            Versiyon Etiketi (boş bırakılırsa otomatik üretilir)
          </label>
          <input
            className="input-field max-w-xs"
            value={version}
            onChange={(e) => setVersion(e.target.value)}
            placeholder={`${Date.now()}`}
          />
        </div>

        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">Metin</label>
          <textarea
            className="input-field min-h-[360px] font-mono text-xs leading-relaxed"
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Metin buraya yazılır…"
          />
          <p className="mt-1 text-xs text-gray-400">{text.trim().length} karakter</p>
        </div>

        <button
          onClick={handleSave}
          disabled={setLegal.isPending || text.trim().length < MIN_LENGTH}
          className="btn-primary"
        >
          {setLegal.isPending ? 'Kaydediliyor…' : 'Yayınla'}
        </button>
      </div>

      <Toast toast={toast} />
    </div>
  )
}
