import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { doc, updateDoc, deleteDoc, serverTimestamp } from 'firebase/firestore'
import { useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../../hooks/useAuth'
import { useCollection, where, orderBy, Timestamp } from '../../hooks/useFirestore'
import { db } from '../../firebase'
import { SurveyDoc } from './types'
import { StatusBadge } from './PortalDashboardPage'

export default function PortalSurveysPage() {
  const { authState } = useAuth()
  const navigate = useNavigate()
  const qc = useQueryClient()
  // super_admin has no companyId — they see platform-wide ('__admin__') surveys
  const companyId = authState.status === 'authenticated'
    ? (authState.companyId ?? '__admin__')
    : undefined

  const { data: surveys = [], isLoading } = useCollection<SurveyDoc>(
    'surveys',
    companyId
      ? [where('companyId', '==', companyId), orderBy('created_at', 'desc')]
      : [],
    ['surveys', companyId],
  )

  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null)
  const [actionLoading, setActionLoading]     = useState<string | null>(null)

  const updateStatus = async (id: string, status: 'active' | 'closed') => {
    setActionLoading(id)
    try {
      await updateDoc(doc(db, 'surveys', id), { status, updated_at: serverTimestamp() })
      void qc.invalidateQueries({ queryKey: ['surveys', companyId] })
    } finally {
      setActionLoading(null)
    }
  }

  const deleteSurvey = async (id: string) => {
    setActionLoading(id)
    try {
      await deleteDoc(doc(db, 'surveys', id))
      void qc.invalidateQueries({ queryKey: ['surveys', companyId] })
    } finally {
      setActionLoading(null)
      setConfirmDeleteId(null)
    }
  }

  const tsStr = (ts?: Timestamp | null) => {
    if (!ts) return '—'
    const d = ts.toDate ? ts.toDate() : new Date((ts as { seconds: number }).seconds * 1000)
    return d.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' })
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Anketler</h1>
          <p className="text-sm text-gray-500 mt-0.5">Çalışanlarınıza yönelik anketleri yönetin</p>
        </div>
        <button onClick={() => navigate('/portal/surveys/new')} className="btn-primary">
          + Yeni Anket
        </button>
      </div>

      <div className="card overflow-hidden p-0">
        {isLoading ? (
          <div className="p-6 space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-14 bg-gray-100 rounded-lg animate-pulse" />
            ))}
          </div>
        ) : surveys.length === 0 ? (
          <div className="text-center py-14 px-6">
            <p className="text-4xl mb-3">📭</p>
            <p className="font-medium text-gray-600">Henüz anket oluşturulmadı</p>
            <p className="text-sm text-gray-400 mt-1">
              İlk anketinizi oluşturun; çalışanlarınız mobil uygulamadan yanıtlayabilsin.
            </p>
            <button onClick={() => navigate('/portal/surveys/new')} className="btn-primary mt-5">
              İlk Anketi Oluştur
            </button>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Anket</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Durum</th>
                <th className="text-right px-4 py-3 font-medium text-gray-600">Yanıtlar</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Son Tarih</th>
                <th className="text-right px-4 py-3 font-medium text-gray-600">İşlemler</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {surveys.map((s) => (
                <tr key={s.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2.5">
                      <span className="text-xl">{s.emoji || '📊'}</span>
                      <div>
                        <p className="font-medium text-gray-900">{s.title}</p>
                        {s.description && (
                          <p className="text-xs text-gray-400 truncate max-w-xs">{s.description}</p>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge status={s.status} />
                  </td>
                  <td className="px-4 py-3 text-right font-medium text-gray-700">
                    {s.responseCount ?? 0}
                  </td>
                  <td className="px-4 py-3 text-gray-500">{tsStr(s.deadline)}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center justify-end gap-2">
                      {(s.status === 'active' || s.status === 'closed') && (
                        <button
                          onClick={() => navigate(`/portal/surveys/${s.id}/results`)}
                          className="text-xs px-2.5 py-1.5 rounded-lg bg-brand-50 text-brand-700 hover:bg-brand-100 font-medium"
                        >
                          Sonuçlar
                        </button>
                      )}
                      {s.status === 'draft' && (
                        <>
                          <button
                            onClick={() => navigate(`/portal/surveys/${s.id}/edit`)}
                            className="text-xs px-2.5 py-1.5 rounded-lg bg-gray-100 text-gray-700 hover:bg-gray-200 font-medium"
                          >
                            Düzenle
                          </button>
                          <button
                            onClick={() => updateStatus(s.id, 'active')}
                            disabled={actionLoading === s.id}
                            className="text-xs px-2.5 py-1.5 rounded-lg bg-green-50 text-green-700 hover:bg-green-100 font-medium disabled:opacity-50"
                          >
                            Yayınla
                          </button>
                        </>
                      )}
                      {s.status === 'active' && (
                        <button
                          onClick={() => updateStatus(s.id, 'closed')}
                          disabled={actionLoading === s.id}
                          className="text-xs px-2.5 py-1.5 rounded-lg bg-amber-50 text-amber-700 hover:bg-amber-100 font-medium disabled:opacity-50"
                        >
                          Kapat
                        </button>
                      )}
                      <button
                        onClick={() => setConfirmDeleteId(s.id)}
                        className="text-xs px-2.5 py-1.5 rounded-lg bg-red-50 text-red-600 hover:bg-red-100 font-medium"
                      >
                        Sil
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Delete confirm modal */}
      {confirmDeleteId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40">
          <div className="card max-w-sm w-full">
            <h3 className="font-semibold text-gray-900 mb-2">Anketi sil?</h3>
            <p className="text-sm text-gray-500 mb-6">
              Bu işlem geri alınamaz. Ankete ait tüm yanıtlar da silinecektir.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setConfirmDeleteId(null)}
                className="flex-1 px-4 py-2 rounded-lg border border-gray-200 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                İptal
              </button>
              <button
                onClick={() => deleteSurvey(confirmDeleteId)}
                disabled={actionLoading === confirmDeleteId}
                className="flex-1 px-4 py-2 rounded-lg bg-red-600 text-white text-sm font-medium hover:bg-red-700 disabled:opacity-50"
              >
                Evet, Sil
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
