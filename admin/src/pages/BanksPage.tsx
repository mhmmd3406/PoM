import { useMemo, useState } from 'react'
import { useCollection, useSetDocument, serverTimestamp } from '../hooks/useFirestore'
import { useToast, Toast } from '../hooks/useToast'
import { useAuth } from '../hooks/useAuth'
import { DataTable, Column } from '../components/DataTable'

// ── Types ────────────────────────────────────────────────────────────────────

interface BankDoc {
  id: string
  display_name?: string
  employee_count?: number
  is_active?: boolean
  logo_url?: string
}

interface BankForm {
  bank_id: string
  display_name: string
  employee_count: number
  is_active: boolean
  logo_url: string
}

const NEW = '__new__'
const EMPTY_FORM: BankForm = {
  bank_id: '',
  display_name: '',
  employee_count: 200,
  is_active: true,
  logo_url: '',
}

const MIN_EMPLOYEES = 200 // privacy filter threshold for display badge

// ── Page ─────────────────────────────────────────────────────────────────────

export default function BanksPage() {
  const { authState } = useAuth()
  const uid = authState.status === 'authenticated' ? authState.user.uid : null
  const { toast, show } = useToast()

  const { data: banks, isLoading } = useCollection<BankDoc>('banks', [], ['banks', 'table'])
  const upsertBank = useSetDocument('banks')

  const [editing, setEditing] = useState<string | null>(null) // null | NEW | bankId
  const [form, setForm] = useState<BankForm>(EMPTY_FORM)

  const sorted = useMemo(
    () => [...(banks ?? [])].sort((a, b) => a.id.localeCompare(b.id)),
    [banks],
  )

  const startNew = () => {
    setEditing(NEW)
    setForm(EMPTY_FORM)
  }

  const startEdit = (b: BankDoc) => {
    setEditing(b.id)
    setForm({
      bank_id: b.id,
      display_name: b.display_name ?? '',
      employee_count: b.employee_count ?? 0,
      is_active: b.is_active !== false,
      logo_url: b.logo_url ?? '',
    })
  }

  const save = () => {
    const id = form.bank_id.trim()
    if (!id) return
    upsertBank.mutate(
      {
        id,
        merge: true,
        data: {
          display_name: form.display_name.trim(),
          employee_count: Math.max(0, form.employee_count),
          is_active: form.is_active,
          logo_url: form.logo_url.trim(),
          updated_at: serverTimestamp(),
          updated_by: uid,
        },
      },
      {
        onSuccess: () => {
          show('Banka kaydedildi ✓')
          setEditing(null)
        },
        onError: (e) => show(e instanceof Error ? e.message : 'Kaydedilemedi', 'err'),
      },
    )
  }

  const toggleActive = (b: BankDoc) => {
    const currentlyActive = b.is_active !== false
    upsertBank.mutate(
      {
        id: b.id,
        merge: true,
        data: { is_active: !currentlyActive, updated_at: serverTimestamp(), updated_by: uid },
      },
      {
        onSuccess: () => show(currentlyActive ? 'Banka donduruldu' : 'Banka aktifleştirildi'),
        onError: (e) => show(e instanceof Error ? e.message : 'Güncellenemedi', 'err'),
      },
    )
  }

  const columns: Column<BankDoc>[] = [
    {
      key: 'id',
      header: 'Banka ID',
      sortable: true,
      exportValue: (b) => b.id,
      render: (b) => <code className="text-xs text-gray-600">{b.id}</code>,
    },
    {
      key: 'display_name',
      header: 'Görünen Ad',
      sortable: true,
      exportValue: (b) => b.display_name ?? '',
      render: (b) => <span className="text-sm text-gray-800">{b.display_name ?? '—'}</span>,
    },
    {
      key: 'employee_count',
      header: 'Çalışan',
      sortable: true,
      exportValue: (b) => b.employee_count ?? 0,
      render: (b) => {
        const n = b.employee_count ?? 0
        return n >= MIN_EMPLOYEES ? (
          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-50 text-green-700 tabular-nums">
            {n.toLocaleString('tr-TR')}
          </span>
        ) : (
          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-50 text-red-600 tabular-nums">
            {n.toLocaleString('tr-TR')} &lt;{MIN_EMPLOYEES}
          </span>
        )
      },
    },
    {
      key: 'is_active',
      header: 'Durum',
      exportValue: (b) => (b.is_active !== false ? 'Aktif' : 'Pasif'),
      render: (b) => (
        <span
          className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
            b.is_active !== false ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-600'
          }`}
        >
          {b.is_active !== false ? 'Aktif' : 'Pasif'}
        </span>
      ),
    },
    {
      key: 'actions',
      header: '',
      render: (b) => (
        <div className="flex items-center gap-3">
          <button
            onClick={() => startEdit(b)}
            className="text-xs text-brand-600 hover:text-brand-800 font-medium"
          >
            Düzenle
          </button>
          <button
            onClick={() => toggleActive(b)}
            disabled={upsertBank.isPending}
            className="text-xs text-gray-500 hover:text-gray-700 font-medium disabled:opacity-50"
          >
            {b.is_active !== false ? 'Dondur' : 'Aktifleştir'}
          </button>
        </div>
      ),
    },
  ]

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h1 className="text-xl font-bold text-gray-900">🏦 Banka Yönetimi</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Aktif bankalar, çalışan sayısı filtresi ve dondurma
          </p>
        </div>
        <button onClick={startNew} className="btn-primary">
          + Yeni Banka
        </button>
      </div>

      {editing && (
        <div className="card p-5 max-w-xl space-y-4">
          <h2 className="text-sm font-semibold text-gray-900">
            {editing === NEW ? 'Yeni Banka Ekle' : 'Banka Düzenle'}
          </h2>
          <div className="space-y-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Banka ID (benzersiz, değiştirilemez)
              </label>
              <input
                className="input-field"
                value={form.bank_id}
                disabled={editing !== NEW}
                onChange={(e) =>
                  setForm((f) => ({
                    ...f,
                    bank_id: e.target.value.toLowerCase().replace(/\s/g, '_'),
                  }))
                }
                placeholder="akbank"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Görünen Ad</label>
              <input
                className="input-field"
                value={form.display_name}
                onChange={(e) => setForm((f) => ({ ...f, display_name: e.target.value }))}
                placeholder="Akbank"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Çalışan Sayısı ({MIN_EMPLOYEES}+ filtresi için)
              </label>
              <input
                type="number"
                min={0}
                className="input-field max-w-xs"
                value={form.employee_count}
                onChange={(e) =>
                  setForm((f) => ({ ...f, employee_count: Number(e.target.value) }))
                }
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Logo URL (isteğe bağlı)
              </label>
              <input
                className="input-field"
                value={form.logo_url}
                onChange={(e) => setForm((f) => ({ ...f, logo_url: e.target.value }))}
                placeholder="https://…"
              />
            </div>
            <label className="flex items-center gap-2 cursor-pointer select-none">
              <input
                type="checkbox"
                className="h-4 w-4 rounded border-gray-300 text-brand-600 focus:ring-brand-500"
                checked={form.is_active}
                onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
              />
              <span className="text-sm text-gray-700">Aktif</span>
            </label>
          </div>
          <div className="flex gap-3">
            <button onClick={save} disabled={upsertBank.isPending || !form.bank_id.trim()} className="btn-primary">
              {upsertBank.isPending ? 'Kaydediliyor…' : 'Kaydet'}
            </button>
            <button onClick={() => setEditing(null)} className="btn-secondary">
              İptal
            </button>
          </div>
        </div>
      )}

      <DataTable
        columns={columns}
        data={sorted}
        keyExtractor={(b) => b.id}
        loading={isLoading}
        emptyMessage="Henüz banka yok."
        exportFilename="pom-bankalar"
      />

      <Toast toast={toast} />
    </div>
  )
}
