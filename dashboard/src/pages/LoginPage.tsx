import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { setApiKey } from '../api/client'
import { validateApiKey } from '../api/endpoints'

export default function LoginPage() {
  const [key, setKey] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const navigate = useNavigate()

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    const trimmed = key.trim()
    if (!trimmed) {
      setError('Lütfen API anahtarınızı girin.')
      return
    }

    setLoading(true)
    setError(null)

    try {
      // Temporarily set the key so the axios instance uses it for validation
      setApiKey(trimmed)
      const companyName = await validateApiKey(trimmed)
      // Key is valid — already persisted in localStorage by setApiKey
      navigate('/overview', { state: { companyName } })
    } catch (err: unknown) {
      // Roll back invalid key
      setApiKey(null)
      const status = (err as { response?: { status?: number } })?.response?.status
      if (status === 401) {
        setError('Geçersiz API anahtarı. Lütfen kontrol edip tekrar deneyin.')
      } else if (status === 429) {
        setError('İstek limiti aşıldı. Lütfen bir süre bekleyip tekrar deneyin.')
      } else {
        setError('Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.')
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 to-brand-900 flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-brand-600 rounded-2xl mb-4">
            <span className="text-3xl text-white font-bold">P</span>
          </div>
          <h1 className="text-3xl font-bold text-white mb-1">PoM Kurumsal</h1>
          <p className="text-slate-400 text-sm">İşyeri refah verilerinize erişin</p>
        </div>

        {/* Card */}
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <h2 className="text-xl font-semibold text-slate-800 mb-1">Giriş Yap</h2>
          <p className="text-slate-500 text-sm mb-6">
            Kurumsal API anahtarınızı girerek devam edin.
          </p>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label
                htmlFor="apiKey"
                className="block text-sm font-medium text-slate-700 mb-1.5"
              >
                API Anahtarı
              </label>
              <input
                id="apiKey"
                type="password"
                value={key}
                onChange={(e) => setKey(e.target.value)}
                placeholder="pom_live_..."
                autoComplete="off"
                spellCheck={false}
                className="w-full px-3.5 py-2.5 rounded-lg border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent transition-shadow font-mono"
              />
            </div>

            {error && (
              <div className="flex items-start gap-2 bg-red-50 border border-red-200 rounded-lg px-3.5 py-3 text-sm text-red-700">
                <span className="shrink-0 font-bold mt-0.5">!</span>
                <span>{error}</span>
              </div>
            )}

            <button
              type="submit"
              disabled={loading || !key.trim()}
              className="btn-primary w-full py-2.5 flex items-center justify-center gap-2"
            >
              {loading ? (
                <>
                  <span className="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  Doğrulanıyor...
                </>
              ) : (
                'Giriş Yap'
              )}
            </button>
          </form>

          <p className="mt-6 text-center text-xs text-slate-400">
            API anahtarınız için{' '}
            <a
              href="mailto:support@pom.app"
              className="text-brand-600 hover:underline"
            >
              support@pom.app
            </a>{' '}
            adresine başvurun.
          </p>
        </div>

        <p className="text-center text-slate-500 text-xs mt-6">
          © {new Date().getFullYear()} PoM — Peace of Mind
        </p>
      </div>
    </div>
  )
}
