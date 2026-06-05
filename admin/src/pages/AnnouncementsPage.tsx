import { useState } from 'react'
import {
  useCollection,
  useAddDocument,
  useUpdateDocument,
  orderBy,
  serverTimestamp,
  Timestamp,
} from '../hooks/useFirestore'
import { useToast, Toast } from '../hooks/useToast'
import { useAuth } from '../hooks/useAuth'
import { DataTable, Column } from '../components/DataTable'

// ── Types ────────────────────────────────────────────────────────────────────

interface AnnouncementDoc {
  id: string
  title?: string
  body?: string
  target_tier?: string
  is_active?: boolean
  published_at?: Timestamp
  expires_at?: Timestamp | null
}

const TIERS: { value: string; label: string }[] = [
  { value: 'all', label: 'Tüm Kullanıcılar' },
  { value: 'free', label: 'Free' },
  { value: 'pro', label: 'Pro' },
  { value: 'enterprise', label: 'Enterprise' },
]

const TIER_LABEL: Record<string, string> = Object.fromEntries(
  TIERS.map((t) => [t.value, t.label]),
)

const EMPTY_FORM = { title: '', body: '', target_tier: 'all', expires_at: '' }

// ── Helpers ──────────────────────────────────────────────────────────────────

function tsToString(ts: Timestamp | null | undefined): string {
  if (!ts || typeof (ts as Timestamp).toDate !== 'function') return '—'
  return ts.toDate().toLocaleDateString('tr-TR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  })
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function AnnouncementsPage() {
  const { authState } = useAuth()
  const uid = authState.status === 'authenticated' ? authState.user.uid : null
  const { toast, show } = useToast()

  const { data: items, isLoading } = useCollection<AnnouncementDoc>(
    'announcements',
    [orderBy('published_at', 'desc')],
    ['announcements', 'table'],
  )
  const addAnnouncement = useAddDocument('announcements')
  const updateAnnouncement = useUpdateDocument('announcements')

  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)

  const handlePublish = () => {
    if (!form.title.trim() || !form.body.trim()) return
    addAnnouncement.mutate(
      {
        title: form.title.trim(),
        body: form.body.trim(),
        target_tier: form.target_tier,
        is_active: true,
        published_at: serverTimestamp(),
        expires_at: form.expires_at ? Timestamp.fromDate(new Date(form.expires_at)) : null,
        created_by: uid,
      },
      {
        onSuccess: () => {
          show('Duyuru yayınlandı ✓')
          setForm(EMPTY_FORM)
          setShowForm(false)
        },
        onError: (e) => show(e instanceof Error ? e.message : 'Yayınlanamadı', 'err'),
      },
    )
  }

  const handleToggle = (a: AnnouncementDoc) => {
    updateAnnouncement.mutate(
      { id: a.id, data: { is_active: !a.is_active } },
      {
        onSuccess: () => show(a.is_active ? 'Duyuru kapatıldı' : 'Duyuru açıldı'),
        onError: (e) => show(e instanceof Error ? e.message : 'Güncellenemedi', 'err'),
      },
    )
  }

  const columns: Column<AnnouncementDoc>[] = [
    {
      key: 'title',
      header: 'Başlık',
      sortable: true,
      exportValue: (a) => a.title ?? '',
      render: (a) => (
        <div>
          <p className="text-sm font-medium text-gray-900">{a.title ?? '—'}</p>
          <p className="text-[11px] text-gray-400 truncate max-w-xs">{a.body ?? ''}</p>
        </div>
      ),
    },
    {
      key: 'target_tier',
      header: 'Hedef',
      sortable: true,
      exportValue: (a) => TIER_LABEL[a.target_tier ?? 'all'] ?? a.target_tier ?? '',
      render: (a) => (
        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-700">
          {TIER_LABEL[a.target_tier ?? 'all'] ?? a.target_tier}
        </span>
      ),
    },
    {
      key: 'published_at',
      header: 'Tarih',
      sortable: true,
      exportValue: (a) => tsToString(a.published_at),
      render: (a) => <span className="text-xs text-gray-500">{tsToString(a.published_at)}</span>,
    },
    {
      key: 'is_active',
      header: 'Durum',
      exportValue: (a) => (a.is_active ? 'Aktif' : 'Pasif'),
      render: (a) => (
        <span
          className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
            a.is_active ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-600'
          }`}
        >
          {a.is_active ? 'Aktif' : 'Pasif'}
        </span>
      ),
    },
    {
      key: 'actions',
      header: '',
      render: (a) => (
        <button
          onClick={() => handleToggle(a)}
          disabled={updateAnnouncement.isPending}
          className="text-xs text-brand-600 hover:text-brand-800 font-medium disabled:opacity-50"
        >
          {a.is_active ? 'Kapat' : 'Aç'}
        </button>
      ),
    },
  ]

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h1 className="text-xl font-bold text-gray-900">📢 Duyurular</h1>
          <p className="text-sm text-gray-500 mt-0.5">Uygulama içi banner bildirimleri</p>
        </div>
        <button onClick={() => setShowForm((s) => !s)} className="btn-primary">
          {showForm ? 'Kapat' : '+ Yeni Duyuru'}
        </button>
      </div>

      {showForm && (
        <div className="card p-5 max-w-xl space-y-4">
          <h2 className="text-sm font-semibold text-gray-900">Yeni Duyuru</h2>
          <div className="space-y-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Başlık</label>
              <input
                className="input-field"
                value={form.title}
                onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
                placeholder="Kısa başlık"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">İçerik</label>
              <textarea
                className="input-field min-h-[96px]"
                value={form.body}
                onChange={(e) => setForm((f) => ({ ...f, body: e.target.value }))}
                placeholder="Duyuru metni…"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Hedef Kitle</label>
              <select
                className="input-field"
                value={form.target_tier}
                onChange={(e) => setForm((f) => ({ ...f, target_tier: e.target.value }))}
              >
                {TIERS.map((t) => (
                  <option key={t.value} value={t.value}>
                    {t.label}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Son Geçerlilik Tarihi (isteğe bağlı)
              </label>
              <input
                type="date"
                className="input-field max-w-xs"
                value={form.expires_at}
                onChange={(e) => setForm((f) => ({ ...f, expires_at: e.target.value }))}
              />
            </div>
          </div>
          <div className="flex gap-3">
            <button
              onClick={handlePublish}
              disabled={addAnnouncement.isPending || !form.title.trim() || !form.body.trim()}
              className="btn-primary"
            >
              {addAnnouncement.isPending ? 'Yayınlanıyor…' : 'Yayınla'}
            </button>
            <button onClick={() => setShowForm(false)} className="btn-secondary">
              İptal
            </button>
          </div>
        </div>
      )}

      <DataTable
        columns={columns}
        data={items ?? []}
        keyExtractor={(a) => a.id}
        loading={isLoading}
        emptyMessage="Henüz duyuru yok."
        exportFilename="pom-duyurular"
      />

      <Toast toast={toast} />
    </div>
  )
}
