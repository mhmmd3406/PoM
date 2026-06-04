import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { doc, updateDoc, deleteDoc, serverTimestamp } from 'firebase/firestore'
import { useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../../hooks/useAuth'
import { useCollection, where, orderBy, Timestamp } from '../../hooks/useFirestore'
import { db } from '../../firebase'
import { SurveyDoc, SurveyQuestion } from './types'
import { StatusBadge } from './PortalDashboardPage'

export default function PortalSurveysPage() {
  const { authState } = useAuth()
  const navigate = useNavigate()
  const qc = useQueryClient()
  // super_admin has no companyId — they see platform-wide ('__admin__') surveys
  const companyId = authState.status === 'authenticated'
    ? (authState.companyId ?? '__admin__')
    : undefined
  // super_admin uses /surveys/*, company_admin uses /portal/surveys/*
  const base = authState.status === 'authenticated' && authState.role === 'super_admin'
    ? '/surveys'
    : '/portal/surveys'

  const { data: surveys = [], isLoading } = useCollection<SurveyDoc>(
    'surveys',
    companyId
      ? [where('companyId', '==', companyId), orderBy('created_at', 'desc')]
      : [],
    ['surveys', companyId],
  )

  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null)
  const [actionLoading, setActionLoading]     = useState<string | null>(null)
  const [previewSurvey, setPreviewSurvey]     = useState<SurveyDoc | null>(null)

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
        <button onClick={() => navigate(`${base}/new`)} className="btn-primary">
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
            <button onClick={() => navigate(`${base}/new`)} className="btn-primary mt-5">
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
                        <div className="flex items-center gap-2 flex-wrap">
                          <p className="font-medium text-gray-900">{s.title}</p>
                          {s.isGate && (
                            <span className="inline-flex items-center gap-1 text-xs bg-blue-50 text-blue-700 font-medium px-2 py-0.5 rounded-full border border-blue-100">
                              🚪 Giriş Anketi{s.isMandatory ? ' · Zorunlu' : ''}
                            </span>
                          )}
                        </div>
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
                      <button
                        onClick={() => setPreviewSurvey(s)}
                        className="text-xs px-2.5 py-1.5 rounded-lg bg-gray-100 text-gray-600 hover:bg-gray-200 font-medium"
                      >
                        Sorular
                      </button>
                      {(s.status === 'active' || s.status === 'closed') && (
                        <button
                          onClick={() => navigate(`${base}/${s.id}/results`)}
                          className="text-xs px-2.5 py-1.5 rounded-lg bg-brand-50 text-brand-700 hover:bg-brand-100 font-medium"
                        >
                          Sonuçlar
                        </button>
                      )}
                      <button
                        onClick={() => navigate(`${base}/${s.id}/edit`)}
                        className="text-xs px-2.5 py-1.5 rounded-lg bg-gray-100 text-gray-700 hover:bg-gray-200 font-medium"
                      >
                        Düzenle
                      </button>
                      {s.status === 'draft' && (
                        <button
                          onClick={() => updateStatus(s.id, 'active')}
                          disabled={actionLoading === s.id}
                          className="text-xs px-2.5 py-1.5 rounded-lg bg-green-50 text-green-700 hover:bg-green-100 font-medium disabled:opacity-50"
                        >
                          Yayınla
                        </button>
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

      {/* Questions preview modal */}
      {previewSurvey && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40">
          <div className="card max-w-2xl w-full max-h-[80vh] flex flex-col">
            <div className="flex items-start justify-between mb-4 flex-shrink-0">
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-2xl">{previewSurvey.emoji || '📊'}</span>
                  <h3 className="font-semibold text-gray-900">{previewSurvey.title}</h3>
                </div>
                <p className="text-xs text-gray-400 mt-1 ml-9">
                  {previewSurvey.questions?.length ?? 0} soru
                  {previewSurvey.isGate ? ' · 🚪 Giriş Anketi' : ''}
                  {previewSurvey.isMandatory ? ' · Zorunlu' : ''}
                </p>
              </div>
              <button
                onClick={() => setPreviewSurvey(null)}
                className="text-gray-400 hover:text-gray-600 text-xl leading-none"
              >
                ✕
              </button>
            </div>
            <div className="overflow-y-auto flex-1 space-y-2 pr-1">
              {(previewSurvey.questions ?? []).map((q: SurveyQuestion, i: number) => (
                <div key={q.id} className="flex gap-3 p-3 rounded-lg bg-gray-50 border border-gray-100">
                  <span className="text-xs font-bold text-gray-400 w-6 flex-shrink-0 mt-0.5">{i + 1}</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-gray-800">{q.text}</p>
                    <div className="flex flex-wrap items-center gap-2 mt-1.5">
                      <span className="text-xs bg-white border border-gray-200 text-gray-500 px-1.5 py-0.5 rounded">
                        {q.type}
                      </span>
                      {q.category && (
                        <span className="text-xs text-brand-600 bg-brand-50 px-1.5 py-0.5 rounded">
                          {q.category}
                        </span>
                      )}
                      {q.reverseScore && (
                        <span className="text-xs text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded">
                          ters puan
                        </span>
                      )}
                      {q.isEnps && (
                        <span className="text-xs text-purple-600 bg-purple-50 px-1.5 py-0.5 rounded">
                          eNPS
                        </span>
                      )}
                    </div>
                    {q.hint && <p className="text-xs text-gray-400 mt-1 italic">{q.hint}</p>}
                  </div>
                </div>
              ))}
            </div>
            <div className="mt-4 flex-shrink-0">
              <button
                onClick={() => setPreviewSurvey(null)}
                className="w-full px-4 py-2 rounded-lg border border-gray-200 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                Kapat
              </button>
            </div>
          </div>
        </div>
      )}

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
