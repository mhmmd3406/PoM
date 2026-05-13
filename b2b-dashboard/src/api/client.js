import axios from 'axios';

const BASE = import.meta.env.VITE_API_BASE ?? '/api';

// Token stored in sessionStorage after login; injected into every request.
export function setToken(token) {
  sessionStorage.setItem('b2b_token', token);
}
export function getToken() {
  return sessionStorage.getItem('b2b_token');
}
export function clearToken() {
  sessionStorage.removeItem('b2b_token');
}

const http = axios.create({ baseURL: BASE });

http.interceptors.request.use((cfg) => {
  const t = getToken();
  if (t) cfg.headers.Authorization = `Bearer ${t}`;
  return cfg;
});

// ── API calls ─────────────────────────────────────────────────────────────

export const FAMILIES = [
  { id: 'all',                label: 'All Families' },
  { id: 'hq_it',             label: 'HQ IT & Technology' },
  { id: 'branch_operations', label: 'Branch Operations' },
  { id: 'corporate_banking', label: 'Corporate Banking' },
  { id: 'retail_banking',    label: 'Retail Banking' },
  { id: 'risk_compliance',   label: 'Risk & Compliance' },
  { id: 'human_resources',   label: 'Human Resources' },
  { id: 'finance_accounting',label: 'Finance & Accounting' },
];

export const METRICS = [
  { key: 'salary',     label: 'Salary',       icon: '💰' },
  { key: 'benefits',   label: 'Benefits',     icon: '🎁' },
  { key: 'workModel',  label: 'Work Model',   icon: '🏠' },
  { key: 'culture',    label: 'Culture',      icon: '🤝' },
  { key: 'wlb',        label: 'WLB',          icon: '⚖️' },
  { key: 'overall',    label: 'Overall',      icon: '⭐' },
];

/** Fetch benchmark for every business family in parallel. */
export async function fetchHeatmap(year, month) {
  const families = FAMILIES.filter((f) => f.id !== 'all');
  const results = await Promise.allSettled(
    families.map((f) =>
      http
        .get('/benchmark', { params: { businessFamily: f.id, year, month } })
        .then((r) => ({ family: f, data: r.data }))
        .catch(() => ({ family: f, data: null })),
    ),
  );
  return results.map((r) => (r.status === 'fulfilled' ? r.value : { family: null, data: null }));
}

export async function fetchTrend(businessFamily, fromYear, fromMonth, toYear, toMonth) {
  const res = await http.get('/trend', {
    params: { businessFamily, fromYear, fromMonth, toYear, toMonth },
  });
  return res.data;
}

export async function requestReport(payload) {
  const res = await http.post('/report/generate', payload);
  return res.data; // ReportStatus
}

export async function pollReport(reportId) {
  const res = await http.get(`/report/${reportId}`);
  return res.data;
}
