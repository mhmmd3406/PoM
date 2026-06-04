import { useEffect, useState } from 'react'
import { useDocument, useSetDocument, serverTimestamp } from '../hooks/useFirestore'
import { useToast, Toast } from '../hooks/useToast'
import { useAuth } from '../hooks/useAuth'

// ── Types ────────────────────────────────────────────────────────────────────

interface FeatureFlagsDoc {
  head_to_head_enabled?: boolean
  retention_risk_enabled?: boolean
  maintenance_mode?: boolean
  maintenance_message?: string
}

interface FeatureFlagsDraft {
  head_to_head_enabled: boolean
  retention_risk_enabled: boolean
  maintenance_mode: boolean
  maintenance_message: string
}

const FLAGS: { key: keyof FeatureFlagsDraft; label: string; hint: string }[] = [
  {
    key: 'head_to_head_enabled',
    label: 'Head-to-Head Karşılaştırma',
    hint: 'Enterprise müşterilerin rakip bankalarla karşılaştırma yapabilmesini sağlar.',
  },
  {
    key: 'retention_risk_enabled',
    label: 'Retention Risk Analizi',
    hint: 'Çalışan elde tutma riski raporunu aktif eder.',
  },
  {
    key: 'maintenance_mode',
    label: 'Bakım Modu',
    hint: 'Tüm kullanıcılara bakım ekranı gösterir. Dikkatli kullan!',
  },
]

const DEFAULTS: FeatureFlagsDraft = {
  head_to_head_enabled: true,
  retention_risk_enabled: true,
  maintenance_mode: false,
  maintenance_message: '',
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function FeatureFlagsPage() {
  const { authState } = useAuth()
  const uid = authState.status === 'authenticated' ? authState.user.uid : null
  const { toast, show } = useToast()

  const { data, isLoading } = useDocument<FeatureFlagsDoc>('platform_config', 'feature_flags')
  const setFlags = useSetDocument('platform_config')

  const [draft, setDraft] = useState<FeatureFlagsDraft>(DEFAULTS)

  useEffect(() => {
    if (data === undefined) return // still loading
    const d: FeatureFlagsDoc = data ?? {}
    setDraft({
      head_to_head_enabled: d.head_to_head_enabled ?? true,
      retention_risk_enabled: d.retention_risk_enabled ?? true,
      maintenance_mode: d.maintenance_mode ?? false,
      maintenance_message: d.maintenance_message ?? '',
    })
  }, [data])

  const handleSave = () => {
    setFlags.mutate(
      {
        id: 'feature_flags',
        merge: true,
        data: { ...draft, updated_at: serverTimestamp(), updated_by: uid },
      },
      {
        onSuccess: () => show('Feature flags güncellendi ✓'),
        onError: (e) => show(e instanceof Error ? e.message : 'Kaydedilemedi', 'err'),
      },
    )
  }

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h1 className="text-xl font-bold text-gray-900">🚩 Feature Flags</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          Özellikleri deploy yapmadan aç/kapat. Değişiklikler kaydedildikten sonra etkin olur.
        </p>
      </div>

      <div className="space-y-3">
        {FLAGS.map((f) => (
          <div key={f.key} className="card p-5">
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="text-sm font-semibold text-gray-900">{f.label}</div>
                <div className="text-xs text-gray-500 mt-0.5">{f.hint}</div>
              </div>
              <Toggle
                checked={Boolean(draft[f.key])}
                disabled={isLoading}
                onChange={() => setDraft((d) => ({ ...d, [f.key]: !d[f.key] }))}
              />
            </div>

            {f.key === 'maintenance_mode' && draft.maintenance_mode && (
              <div className="mt-4">
                <label className="block text-xs font-medium text-gray-600 mb-1">
                  Bakım Mesajı (kullanıcıya gösterilecek)
                </label>
                <input
                  className="input-field"
                  value={draft.maintenance_message}
                  onChange={(e) =>
                    setDraft((d) => ({ ...d, maintenance_message: e.target.value }))
                  }
                  placeholder="Kısa süreliğine bakım yapılıyor…"
                />
              </div>
            )}
          </div>
        ))}
      </div>

      <button onClick={handleSave} disabled={isLoading || setFlags.isPending} className="btn-primary">
        {setFlags.isPending ? 'Kaydediliyor…' : 'Kaydet'}
      </button>

      <Toast toast={toast} />
    </div>
  )
}

// ── Toggle switch ────────────────────────────────────────────────────────────

function Toggle({
  checked,
  onChange,
  disabled,
}: {
  checked: boolean
  onChange: () => void
  disabled?: boolean
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={onChange}
      className={`relative inline-flex h-6 w-11 flex-shrink-0 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-brand-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed ${
        checked ? 'bg-brand-600' : 'bg-gray-300'
      }`}
    >
      <span
        className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${
          checked ? 'translate-x-6' : 'translate-x-1'
        }`}
      />
    </button>
  )
}
