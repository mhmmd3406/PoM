import { useMemo } from 'react'
import { httpsCallable } from 'firebase/functions'
import { functions } from '../firebase'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { ThresholdsForm, ThresholdConfig } from '../components/ThresholdsForm'
import { doc, getDoc, Timestamp } from 'firebase/firestore'
import { db } from '../firebase'

// ── Types ────────────────────────────────────────────────────────────────────

interface ThresholdsDoc extends ThresholdConfig {
  _updated_at?: Timestamp
}

// ── Defaults ─────────────────────────────────────────────────────────────────

const DEFAULT_THRESHOLDS: ThresholdConfig = {
  company_min_n: 15,
  department_min_n: 10,
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function ThresholdsPage() {
  const qc = useQueryClient()

  // Fetch via Cloud Function (respects caching and auth)
  const { data: rawData, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['thresholds'],
    queryFn: async () => {
      const getThresholds = httpsCallable<void, ThresholdConfig>(functions, 'getThresholds')
      const result = await getThresholds()
      return result.data
    },
    staleTime: 0, // always fresh for admin page
  })

  // Also fetch the raw Firestore doc for the _updated_at timestamp
  const { data: firestoreDoc } = useQuery({
    queryKey: ['thresholds', 'firestoreDoc'],
    queryFn: async () => {
      const snap = await getDoc(doc(db, 'platform_config', 'thresholds'))
      if (!snap.exists()) return null
      return snap.data() as ThresholdsDoc
    },
    staleTime: 0,
  })

  const lastUpdated = useMemo(() => {
    const ts = firestoreDoc?._updated_at
    if (!ts) return null
    return ts.toDate ? ts.toDate() : new Date((ts as { seconds: number }).seconds * 1000)
  }, [firestoreDoc])

  const currentValues = rawData ?? DEFAULT_THRESHOLDS

  const handleSaved = (updated: ThresholdConfig) => {
    qc.setQueryData(['thresholds'], updated)
    void qc.invalidateQueries({ queryKey: ['thresholds', 'firestoreDoc'] })
  }

  return (
    <div className="space-y-6 max-w-3xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-gray-900">Anonimleştirme Eşikleri</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          Cloud Function'ların kullandığı minimum katılımcı eşiklerini yönetin.
          Bu değerler, çalışanların kimliğini korumak için raporlarda minimum veri noktası sayısını belirler.
        </p>
      </div>

      {/* Info banner */}
      <div className="flex items-start gap-3 rounded-xl bg-amber-50 border border-amber-200 px-4 py-3">
        <InfoIcon className="w-5 h-5 text-amber-500 flex-shrink-0 mt-0.5" />
        <div className="text-sm text-amber-800 space-y-1">
          <p className="font-semibold">Güvenlik Tabanı Nasıl Çalışır?</p>
          <p>
            Belirlediğiniz değerler Cloud Function'a gönderilir ancak uygulanan değer
            her zaman <strong>güvenlik tabanı</strong> ile karşılaştırılır ve büyük olan
            kullanılır. Bu, hiçbir zaman çok küçük gruplara ait verilerin açığa çıkmamasını
            garanti eder.
          </p>
        </div>
      </div>

      {/* Loading */}
      {isLoading && (
        <div className="space-y-4">
          {[1, 2].map((i) => (
            <div key={i} className="card p-5">
              <div className="h-4 bg-gray-100 rounded animate-pulse w-1/3 mb-3" />
              <div className="h-3 bg-gray-100 rounded animate-pulse w-2/3 mb-4" />
              <div className="h-8 bg-gray-100 rounded animate-pulse w-24" />
            </div>
          ))}
        </div>
      )}

      {/* Error */}
      {isError && !isLoading && (
        <div className="card p-5 flex items-start gap-3">
          <AlertIcon className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-semibold text-red-700">Eşikler yüklenemedi</p>
            <p className="text-xs text-red-600 mt-0.5">
              {error instanceof Error ? error.message : 'Bilinmeyen hata'}
            </p>
            <button
              onClick={() => void refetch()}
              className="mt-3 btn-secondary text-xs py-1 px-3"
            >
              Tekrar Dene
            </button>
          </div>
        </div>
      )}

      {/* Form */}
      {!isLoading && (
        <ThresholdsForm
          initialValues={currentValues}
          lastUpdated={lastUpdated}
          onSaved={handleSaved}
        />
      )}

      {/* How it's used section */}
      <div className="card p-5 space-y-3">
        <h2 className="text-sm font-semibold text-gray-700">Eşikler Nerede Kullanılır?</h2>
        <div className="space-y-2 text-xs text-gray-500">
          <div className="flex items-start gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-brand-500 flex-shrink-0 mt-1.5" />
            <div>
              <span className="font-medium text-gray-700">computeInsights</span> — Şirket ve departman
              raporları oluşturulmadan önce minimum katılımcı kontrolü yapılır.
            </div>
          </div>
          <div className="flex items-start gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-brand-500 flex-shrink-0 mt-1.5" />
            <div>
              <span className="font-medium text-gray-700">daasWidgetApi</span> — DaaS müşterilerine
              veri sunulmadan önce minimum check-in sayısı kontrol edilir.
            </div>
          </div>
          <div className="flex items-start gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-brand-500 flex-shrink-0 mt-1.5" />
            <div>
              <span className="font-medium text-gray-700">platform_config/thresholds</span> — Firestore
              koleksiyonunda saklanır, 5 dakikalık bellek önbelleği ile okunur.
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

// ── Inline icons ─────────────────────────────────────────────────────────────

function InfoIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" />
    </svg>
  )
}

function AlertIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
    </svg>
  )
}
