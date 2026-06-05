import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  collection,
  doc,
  getDocs,
  getDoc,
  setDoc,
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  serverTimestamp,
  QueryConstraint,
  DocumentData,
  WithFieldValue,
  UpdateData,
  Timestamp,
} from 'firebase/firestore'
import { db } from '../firebase'

// ── Generic collection query ────────────────────────────────────────────────

export function useCollection<T extends DocumentData>(
  collectionPath: string,
  constraints: QueryConstraint[] = [],
  queryKey?: unknown[],
) {
  return useQuery({
    queryKey: queryKey ?? [collectionPath, ...constraints],
    queryFn: async () => {
      const q = query(collection(db, collectionPath), ...constraints)
      const snapshot = await getDocs(q)
      return snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as T & { id: string }))
    },
  })
}

// ── Generic document query ──────────────────────────────────────────────────

export function useDocument<T extends DocumentData>(
  collectionPath: string,
  docId: string | null,
) {
  return useQuery({
    queryKey: [collectionPath, docId],
    queryFn: async () => {
      if (!docId) return null
      const snap = await getDoc(doc(db, collectionPath, docId))
      if (!snap.exists()) return null
      return { id: snap.id, ...snap.data() } as T & { id: string }
    },
    enabled: !!docId,
  })
}

// ── Set document ─────────────────────────────────────────────────────────────

export function useSetDocument<T extends DocumentData>(collectionPath: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({
      id,
      data,
      merge = false,
    }: {
      id: string
      data: WithFieldValue<T>
      merge?: boolean
    }) => {
      await setDoc(doc(db, collectionPath, id), data as WithFieldValue<DocumentData>, { merge })
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: [collectionPath] })
    },
  })
}

// ── Add document (auto-generated ID) ─────────────────────────────────────────

export function useAddDocument<T extends DocumentData>(collectionPath: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (data: WithFieldValue<T>) => {
      const ref = await addDoc(collection(db, collectionPath), data)
      return ref.id
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: [collectionPath] })
    },
  })
}

// ── Update document ──────────────────────────────────────────────────────────

export function useUpdateDocument<T extends DocumentData>(collectionPath: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, data }: { id: string; data: UpdateData<T> }) => {
      await updateDoc(doc(db, collectionPath, id), data)
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: [collectionPath] })
    },
  })
}

// ── Delete document ──────────────────────────────────────────────────────────

export function useDeleteDocument(collectionPath: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (id: string) => {
      await deleteDoc(doc(db, collectionPath, id))
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: [collectionPath] })
    },
  })
}

// ── Helpers re-exported for convenience ─────────────────────────────────────

export { where, orderBy, limit, serverTimestamp, Timestamp }
