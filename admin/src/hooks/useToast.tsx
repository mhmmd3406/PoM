import { useState, useCallback, useRef, useEffect } from 'react'

// ── Lightweight toast ──────────────────────────────────────────────────────────
// Self-contained: a page calls `const { toast, show } = useToast()` and renders
// `<Toast toast={toast} />`. No provider wiring required. Mirrors the old JSX
// admin's useToast contract but styled with Tailwind.

export type ToastType = 'ok' | 'err'

export interface ToastMessage {
  msg: string
  type: ToastType
}

const AUTO_DISMISS_MS = 3500

export function useToast() {
  const [toast, setToast] = useState<ToastMessage | null>(null)
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)

  const show = useCallback((msg: string, type: ToastType = 'ok') => {
    setToast({ msg, type })
    if (timer.current) clearTimeout(timer.current)
    timer.current = setTimeout(() => setToast(null), AUTO_DISMISS_MS)
  }, [])

  useEffect(() => () => {
    if (timer.current) clearTimeout(timer.current)
  }, [])

  return { toast, show }
}

export function Toast({ toast }: { toast: ToastMessage | null }) {
  if (!toast) return null
  const ok = toast.type === 'ok'
  return (
    <div
      role="status"
      className={`fixed bottom-6 right-6 z-50 flex items-start gap-2.5 max-w-sm rounded-xl border px-4 py-3 shadow-lg text-sm font-medium animate-[fadeIn_0.15s_ease-out] ${
        ok
          ? 'bg-green-50 border-green-200 text-green-800'
          : 'bg-red-50 border-red-200 text-red-700'
      }`}
    >
      {ok ? (
        <svg className="w-4 h-4 flex-shrink-0 mt-0.5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
        </svg>
      ) : (
        <svg className="w-4 h-4 flex-shrink-0 mt-0.5 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
        </svg>
      )}
      <span>{toast.msg}</span>
    </div>
  )
}
