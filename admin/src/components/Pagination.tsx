export const PAGE_SIZES = [10, 50, 100, 500, 1000]

interface PaginationProps {
  page: number
  pageSize: number
  total: number
  onPageChange: (p: number) => void
  onPageSizeChange: (s: number) => void
  onExport?: () => void
}

export function Pagination({
  page, pageSize, total, onPageChange, onPageSizeChange, onExport,
}: PaginationProps) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize))
  const start = total === 0 ? 0 : page * pageSize + 1
  const end = Math.min((page + 1) * pageSize, total)

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 border-t border-gray-100 bg-white">
      <div className="flex items-center gap-2">
        <span className="text-xs text-gray-500">Sayfa başına:</span>
        <select
          value={pageSize}
          onChange={(e) => { onPageSizeChange(Number(e.target.value)); onPageChange(0) }}
          className="text-xs border border-gray-200 rounded-md px-2 py-1 bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-brand-500"
        >
          {PAGE_SIZES.map((s) => <option key={s} value={s}>{s}</option>)}
        </select>
        <span className="text-xs text-gray-400 tabular-nums">
          {start}–{end} / {total.toLocaleString('tr-TR')}
        </span>
      </div>

      <div className="flex items-center gap-1">
        {onExport && (
          <button
            onClick={onExport}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-white border border-gray-200 text-gray-600 hover:bg-gray-50 transition-colors mr-3"
          >
            <DownloadIcon className="w-3.5 h-3.5" />
            Excel İndir
          </button>
        )}
        <NavBtn onClick={() => onPageChange(0)} disabled={page === 0}>«</NavBtn>
        <NavBtn onClick={() => onPageChange(page - 1)} disabled={page === 0}>‹</NavBtn>
        <span className="text-xs text-gray-600 px-2 tabular-nums min-w-[60px] text-center">
          {page + 1} / {totalPages}
        </span>
        <NavBtn onClick={() => onPageChange(page + 1)} disabled={page >= totalPages - 1}>›</NavBtn>
        <NavBtn onClick={() => onPageChange(totalPages - 1)} disabled={page >= totalPages - 1}>»</NavBtn>
      </div>
    </div>
  )
}

function NavBtn({
  onClick, disabled, children,
}: { onClick: () => void; disabled: boolean; children: string }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="w-7 h-7 flex items-center justify-center rounded-md text-sm text-gray-500 hover:text-gray-800 hover:bg-gray-100 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
    >
      {children}
    </button>
  )
}

function DownloadIcon({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3" />
    </svg>
  )
}
