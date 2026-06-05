import { useState } from 'react'
import {
  useCollection,
  useUpdateDocument,
  orderBy,
  serverTimestamp,
  Timestamp,
} from '../hooks/useFirestore'
import { useToast, Toast } from '../hooks/useToast'
import { useAuth } from '../hooks/useAuth'
import { DataTable, Column } from '../components/DataTable'

// ── Types ────────────────────────────────────────────────────────────────────

interface DisputeDoc {
  id: string
  bank_id?: string
  category?: string
  description?: string
  status?: string
  admin_note?: string
  submitted_at?: Timestamp
}

const STATUS_META: Record<string, { label: string; cls: string }> = {
  pending: { label: 'Bekliyor', cls: 'bg-amber-50 text-amber-700' },
  under_review: { label: 'İnceleniyor', cls: 'bg-blue-50 text-blue-700' },
  resolved: { label: 'Çözüldü', cls: 'bg-green-50 text-green-700' },
  rejected: { label: 'Reddedildi', cls: 'bg-red-50 text-red-600' },
}

const CATEGORY_LABELS: Record<string, string> = {
  methodology: 'Metodoloji',
  data_accuracy: 'Veri Doğruluğu',
  manipulation_suspicion: 'Manipülasyon Şüphesi',
  other: 'Diğer',
}

const RESOLVE_OPTIONS = [
  { value: 'under_review', label: 'İnceleniyor' },
  { value: 'resolved', label: 'Çözüldü' },
  { value: 'rejected', label: 'Reddedildi' },
]

// ── Helpers ──────────────────────────────────────────────────────────────────

function tsToString(ts: Timestamp | undefined): string {
  if (!ts || typeof (ts as Timestamp).toDate !== 'function') return '—'
  return ts.toDate().toLocaleDateString('tr-TR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  })
}

function StatusBadge({ status }: { status?: string }) {
  const meta = STATUS_META[status ?? ''] ?? { label: status ?? '—', cls: 'bg-gray-100 text-gray-600' }
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${meta.cls}`}>
      {meta.label}
    </span>
  )
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function DisputesPage() {
  const { authState } = useAuth()
  const uid = authState.status === 'authenticated' ? authState.user.uid : null
  const { toast, show } = useToast()

  const { data: disputes, isLoading } = useCollection<DisputeDoc>(
    'disputes',
    [orderBy('submitted_at', 'desc')],
    ['disputes', 'table'],
  )
  const updateDispute = useUpdateDocument('disputes')

  const [selected, setSelected] = useState<DisputeDoc | null>(null)

  const handleResolve = (status: string, adminNote: string) => {
    if (!selected) return
    updateDispute.mutate(
      {
        id: selected.id,
        data: {
          status,
          admin_note: adminNote,
          resolved_at: serverTimestamp(),
          resolved_by: uid,
        },
      },
      {
        onSuccess: () => {
          show('İtiraz güncellendi ✓')
          setSelected(null)
        },
        onError: (e) => show(e instanceof Error ? e.message : 'Güncellenemedi', 'err'),
      },
    )
  }

  const columns: Column<DisputeDoc>[] = [
    {
      key: 'bank_id',
      header: 'Banka',
      sortable: true,
      exportValue: (d) => d.bank_id ?? '',
      render: (d) => <code className="text-xs text-gray-600">{d.bank_id ?? '—'}</code>,
    },
    {
      key: 'category',
      header: 'Kategori',
      sortable: true,
      exportValue: (d) => CATEGORY_LABELS[d.category ?? ''] ?? d.category ?? '',
      render: (d) => (
        <span className="text-sm text-gray-700">
          {CATEGORY_LABELS[d.category ?? ''] ?? d.category ?? '—'}
        </span>
      ),
    },
    {
      key: 'submitted_at',
      header: 'Tarih',
      sortable: true,
      exportValue: (d) => tsToString(d.submitted_at),
      render: (d) => <span className="text-xs text-gray-500">{tsToString(d.submitted_at)}</span>,
    },
    {
      key: 'status',
      header: 'Durum',
      sortable: true,
      exportValue: (d) => STATUS_META[d.status ?? '']?.label ?? d.status ?? '',
      render: (d) => <StatusBadge status={d.status} />,
    },
    {
      key: 'actions',
      header: '',
      render: (d) => (
        <button
          onClick={() => setSelected(d)}
          className="text-xs text-brand-600 hover:text-brand-800 font-medium"
        >
          İncele
        </button>
      ),
    },
  ]

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-gray-900">📬 İtiraz Yönetimi</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          Bankalar tarafından gönderilen metodoloji ve veri doğruluğu itirazları
        </p>
      </div>

      <DataTable
        columns={columns}
        data={disputes ?? []}
        keyExtractor={(d) => d.id}
        loading={isLoading}
        emptyMessage="Henüz itiraz yok."
        exportFilename="pom-itirazlar"
      />

      {selected && (
        <ReviewModal
          key={selected.id}
          dispute={selected}
          saving={updateDispute.isPending}
          onClose={() => setSelected(null)}
          onSubmit={handleResolve}
        />
      )}

      <Toast toast={toast} />
    </div>
  )
}

// ── Review modal ─────────────────────────────────────────────────────────────

function ReviewModal({
  dispute,
  saving,
  onClose,
  onSubmit,
}: {
  dispute: DisputeDoc
  saving: boolean
  onClose: () => void
  onSubmit: (status: string, adminNote: string) => void
}) {
  const [status, setStatus] = useState(
    dispute.status === 'pending' || !dispute.status ? 'under_review' : dispute.status,
  )
  const [note, setNote] = useState(dispute.admin_note ?? '')

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="card w-full max-w-md p-6">
        <div className="flex items-start justify-between mb-4">
          <h2 className="text-base font-semibold text-gray-900">İtiraz Detayı</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18 18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <p className="text-xs text-gray-500">Banka</p>
              <p className="font-mono text-xs text-gray-800 mt-0.5">{dispute.bank_id ?? '—'}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500">Kategori</p>
              <p className="text-gray-800 mt-0.5">
                {CATEGORY_LABELS[dispute.category ?? ''] ?? dispute.category ?? '—'}
              </p>
            </div>
          </div>

          <div>
            <p className="text-xs text-gray-500 mb-1">Açıklama</p>
            <div className="rounded-lg bg-gray-50 border border-gray-100 px-3 py-2 text-xs leading-relaxed text-gray-700 whitespace-pre-wrap">
              {dispute.description || '—'}
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Durum</label>
            <select
              className="input-field"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
            >
              {RESOLVE_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">Admin Notu</label>
            <textarea
              className="input-field min-h-[88px]"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="İçeride görünür not…"
            />
          </div>
        </div>

        <div className="mt-5 flex justify-end gap-3">
          <button onClick={onClose} className="btn-secondary text-sm py-1.5">
            Kapat
          </button>
          <button
            onClick={() => onSubmit(status, note)}
            disabled={saving}
            className="btn-primary text-sm py-1.5 min-w-[80px]"
          >
            {saving ? 'Kaydediliyor…' : 'Kaydet'}
          </button>
        </div>
      </div>
    </div>
  )
}
