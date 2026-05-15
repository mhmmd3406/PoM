import axios, { type AxiosInstance } from 'axios'
import { useState, useEffect } from 'react'

const API_KEY_STORAGE = 'pom_api_key'

// ---------------------------------------------------------------------------
// Persistent API key state (module-level so all hooks share the same value)
// ---------------------------------------------------------------------------
let _apiKey: string | null = localStorage.getItem(API_KEY_STORAGE)
const _listeners = new Set<() => void>()

export function getApiKey(): string | null {
  return _apiKey
}

export function setApiKey(key: string | null): void {
  _apiKey = key
  if (key) {
    localStorage.setItem(API_KEY_STORAGE, key)
  } else {
    localStorage.removeItem(API_KEY_STORAGE)
  }
  _listeners.forEach((l) => l())
  // Rebuild axios instance with new key
  rebuildClient()
}

export function useApiKey() {
  const [apiKey, setLocal] = useState<string | null>(_apiKey)

  useEffect(() => {
    const handler = () => setLocal(_apiKey)
    _listeners.add(handler)
    return () => { _listeners.delete(handler) }
  }, [])

  return { apiKey, setApiKey }
}

// ---------------------------------------------------------------------------
// Axios instance
// ---------------------------------------------------------------------------
let apiClient: AxiosInstance = buildClient(_apiKey)

function buildClient(key: string | null): AxiosInstance {
  return axios.create({
    baseURL: import.meta.env.VITE_API_URL ?? 'https://api.pom.app',
    headers: {
      'Content-Type': 'application/json',
      ...(key ? { 'X-Api-Key': key } : {}),
    },
    timeout: 15_000,
  })
}

function rebuildClient() {
  apiClient = buildClient(_apiKey)
}

export { apiClient }
