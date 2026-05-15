import { useState, useEffect } from 'react'
import { httpsCallable } from 'firebase/functions'
import { functions } from '../firebase'

// ── Types ────────────────────────────────────────────────────────────────────

export interface ThresholdConfig {
  company_min_n: number
  department_min_n: number
  [key: string]: number
}

interface FieldDef {
  key: keyof ThresholdConfig
  label: string
  description: string
  safetyFloor: number
  safetyFloorLabel: string
  min: number
  max: number
  unit: string
}

const FIELDS: FieldDef[] = [
  {
    key: 'company_min_n',
    label: 'Şirket Minimum Katılımcı',
    description: 'Şirket genelinde rapor oluşturmak için gereken minimum check-in sayısı.',
    safetyFloor: 7,
    safetyFloorLabel: 'Güvenlik tabanı: 7',
    min: 1,
    max: 200,
    unit: 'kişi',
  },
  {
    key: 'department_min_n',
    label: 'Departman Minimum Katılımcı',
    description: 'Departman bazlı rapor için gereken minimum check-in sayısı.',
    safetyFloor: 5,
    safetyFloorLabel: 'Güvenlik tabanı: 5',
    min: 1,
    max: 100,
    unit: 'kişi',
  },
]

// ── Props ────────────────────────────────────────────────────────────────────

interface ThresholdsFormProps {
  initialValues: ThresholdConfig
  lastUpdated?: Date | null
  onSaved?: (values: ThresholdConfig) => void
}

// ── Component ────────────────────────────────────────────────────────────────

export function ThresholdsForm({ initialValues, lastUpdated, onSaved }: ThresholdsFormProps) {
  const [values, setValues] = useState<ThresholdConfig>(initialValues)
  const [saving, setSaving] = useState(false)
  const [successMsg, setSuccessMsg] = useState<string | null>(null)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const [dirty, setDirty] = useState(false)

  // Sync when initialValues changes (e.g., after refetch)
  useEffect(() => {
    setValues(initialValues)
    setDirty(false)
  }, [initialValues])

  const handleChange = (key: keyof ThresholdConfig, raw: string) => {
    const parsed = parseInt(raw, 10)
    if (isNaN(parsed)) return
    setValues((v) => ({ ...v, [key]: parsed }))
    setDirty(true)
    setSuccessMsg(null)
    setErrorMsg(null)
  }

  const handleSave = async () => {
    setSaving(true)
    setSuccessMsg(null)
    setErrorMsg(null)

    try {
      const updateThresholds = httpsCallable<ThresholdConfig, ThresholdConfig>(
        functions,
        'updateThresholds',
      )
      const result = await updateThresholds(values)
      setValues(result.data)
      setDirty(false)
      setSuccessMsg('Eşikler başarıyla güncellendi.')
      onSaved?.(result.data)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Bir hata oluştu.'
      setErrorMsg(`Kayıt başarısız: ${msg}`)
    } finally {
      setSaving(false)
    }
  }

  const handleReset = () => {
    setValues(initialValues)
    setDirty(false)
    setSuccessMsg(null)
    setErrorMsg(null)
  }

  return (
    <div className="space-y-6">
      {/* Fields */}
      {FIELDS.map((field) => {
        const current = values[field.key] ?? field.safetyFloor
        const belowFloor = current < field.safetyFloor
        const original = initialValues[field.key]
        const changed = current !== original

        return (
          <div key={field.key} className="card p-5">
            <div className="flex flex-col sm:flex-row sm:items-start gap-4">
              {/* Info */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <h3 className="text-sm font-semibold text-gray-900">{field.label}</h3>
                  {changed && (
                    <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-50 text-amber-700 border border-amber-200">
                      Değiştirildi
                    </span>
                  )}
                </div>
                <p className="mt-1 text-xs text-gray-500">{field.description}</p>

                {/* Current vs floor */}
                <div className="mt-3 flex items-center gap-4 flex-wrap text-xs">
                  <span className="text-gray-500">
                    Mevcut DB değeri:{' '}
                    <span className="font-semibold text-gray-800 tabular-nums">
                      {original} {field.unit}
                    </span>
                  </span>
                  <span className="text-gray-400">|</span>
                  <span className={belowFloor ? 'text-red-600 font-semibold' : 'text-gray-500'}>
                    {field.safetyFloorLabel}
                  </span>
                </div>

                {/* Safety floor warning */}
                {belowFloor && (
                  <div className="mt-2 flex items-start gap-2 rounded-lg bg-red-50 border border-red-200 px-3 py-2">
                    <WarningIcon className="w-4 h-4 text-red-500 flex-shrink-0 mt-0.5" />
                    <p className="text-xs text-red-700">
                      Bu değer güvenlik tabanının ({field.safetyFloor}) altında. Kaydetseniz bile
                      Cloud Function güvenlik tabanını uygulayacak ve{' '}
                      <strong>{field.safetyFloor}</strong> olarak kullanılacak.
                    </p>
                  </div>
                )}
              </div>

              {/* Input */}
              <div className="flex flex-col items-end gap-1 min-w-[120px]">
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    min={field.min}
                    max={field.max}
                    value={current}
                    onChange={(e) => handleChange(field.key, e.target.value)}
                    className={`w-24 input-field text-center tabular-nums text-base font-semibold ${
                      belowFloor
                        ? 'border-red-400 focus:ring-red-400 focus:border-red-400 text-red-700'
                        : ''
                    }`}
                  />
                  <span className="text-sm text-gray-400">{field.unit}</span>
                </div>
                {/* Range slider for visual feedback */}
                <input
                  type="range"
                  min={field.min}
                  max={field.max}
                  value={current}
                  onChange={(e) => handleChange(field.key, e.target.value)}
                  className="w-32 accent-brand-600"
                />
                <span className="text-[10px] text-gray-400 tabular-nums">
                  {field.min}–{field.max}
                </span>
              </div>
            </div>
          </div>
        )
      })}

      {/* Footer: timestamps + actions */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pt-2">
        <div className="text-xs text-gray-400">
          {lastUpdated ? (
            <>
              Son güncelleme:{' '}
              <span className="text-gray-600">
                {lastUpdated.toLocaleString('tr-TR')}
              </span>
            </>
          ) : (
            'Son güncelleme tarihi bilinmiyor.'
          )}
        </div>

        <div className="flex items-center gap-3">
          {successMsg && (
            <span className="text-xs font-medium text-green-600 flex items-center gap-1">
              <CheckIcon className="w-4 h-4" /> {successMsg}
            </span>
          )}
          {errorMsg && (
            <span className="text-xs font-medium text-red-600">{errorMsg}</span>
          )}
          <button
            onClick={handleReset}
            disabled={!dirty || saving}
            className="btn-secondary text-xs py-1.5 px-3"
          >
            Sıfırla
          </button>
          <button
            onClick={handleSave}
            disabled={saving || !dirty}
            className="btn-primary text-xs py-1.5 px-4 min-w-[80px]"
          >
            {saving ? (
              <span className="flex items-center gap-1.5">
                <SpinnerIcon className="w-3.5 h-3.5 animate-spin" />
                Kaydediliyor…
              </span>
            ) : (
              'Kaydet'
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Inline icons ─────────────────────────────────────────────────────────────

function WarningIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
    </svg>
  )
}

function CheckIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
    </svg>
  )
}

function SpinnerIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
    </svg>
  )
}
