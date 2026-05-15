import { type ReactNode } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import { setApiKey } from '../api/client'

interface NavItem {
  to: string
  label: string
  icon: string
}

const NAV_ITEMS: NavItem[] = [
  { to: '/overview',    label: 'Genel Bakış',   icon: '📊' },
  { to: '/trends',      label: 'Trendler',       icon: '📈' },
  { to: '/departments', label: 'Departmanlar',   icon: '🏢' },
  { to: '/benchmark',   label: 'Kıyaslama',      icon: '🏆' },
]

export default function Layout({ children }: { children: ReactNode }) {
  const navigate = useNavigate()

  function handleLogout() {
    setApiKey(null)
    navigate('/login')
  }

  return (
    <div className="min-h-screen flex">
      {/* Sidebar */}
      <aside className="w-64 bg-slate-900 text-white flex flex-col shrink-0">
        {/* Logo */}
        <div className="px-6 py-5 border-b border-slate-700">
          <span className="text-xl font-bold tracking-tight">
            <span className="text-brand-400">PoM</span>
            <span className="ml-2 text-slate-300 text-sm font-normal">Kurumsal</span>
          </span>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-4 py-4 space-y-1">
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-brand-600 text-white'
                    : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                }`
              }
            >
              <span className="text-base">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        {/* Footer */}
        <div className="px-4 py-4 border-t border-slate-700">
          <button
            onClick={handleLogout}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-slate-400 hover:bg-slate-800 hover:text-white transition-colors"
          >
            <span>🚪</span>
            Çıkış Yap
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <div className="max-w-7xl mx-auto px-6 py-8">
          {children}
        </div>
      </main>
    </div>
  )
}
