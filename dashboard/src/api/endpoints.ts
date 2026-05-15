import { apiClient } from './client'

// ---------------------------------------------------------------------------
// Types — mirror the .NET API response models
// ---------------------------------------------------------------------------

export interface Dimensions {
  mood: number
  stress: number
  team: number
  growth: number
  balance: number
}

export type RetentionRisk = 'low' | 'medium' | 'high'

export interface WellbeingResponse {
  companyId: string
  companyName: string
  score: number
  dimensions: Dimensions
  participationRate: number
  retentionRisk: RetentionRisk
  employeeCount: number
  checkinCount: number
  generatedAt: string
}

export interface DepartmentData {
  departmentId: string
  departmentName: string
  score: number
  dimensions: Dimensions
  employeeCount: number
  checkinCount: number
  meetsThreshold: boolean
}

export interface DepartmentsResponse {
  departments: DepartmentData[]
  threshold: number
}

export interface TrendPoint {
  weekStart: string
  score: number
  dimensions: Dimensions
  participantCount: number
}

export interface TrendResponse {
  companyId: string
  days: number
  points: TrendPoint[]
}

export interface BenchmarkDimension {
  dimension: string
  companyScore: number
  industryAverage: number
  percentile: number
}

export interface BenchmarkResponse {
  companyId: string
  industryName: string
  overallPercentile: number
  dimensions: BenchmarkDimension[]
  topQuartileThreshold: number
}

// ---------------------------------------------------------------------------
// Endpoint functions
// ---------------------------------------------------------------------------

export async function fetchWellbeing(): Promise<WellbeingResponse> {
  const res = await apiClient.get<WellbeingResponse>('/api/v1/wellbeing')
  return res.data
}

export async function fetchDepartments(): Promise<DepartmentsResponse> {
  const res = await apiClient.get<DepartmentsResponse>('/api/v1/departments')
  return res.data
}

export async function fetchTrends(days = 90): Promise<TrendResponse> {
  const res = await apiClient.get<TrendResponse>('/api/v1/trends', { params: { days } })
  return res.data
}

export async function fetchBenchmark(): Promise<BenchmarkResponse> {
  const res = await apiClient.get<BenchmarkResponse>('/api/v1/benchmark')
  return res.data
}

/** Validate an API key by calling /api/v1/wellbeing. Returns the company name on success. */
export async function validateApiKey(key: string): Promise<string> {
  const res = await apiClient.request<WellbeingResponse>({
    method: 'GET',
    url: '/api/v1/wellbeing',
    headers: { 'X-Api-Key': key },
  })
  return res.data.companyName
}

// ---------------------------------------------------------------------------
// CSV download helper
// ---------------------------------------------------------------------------

export function buildTrendsCsv(trend: TrendResponse): string {
  const header = 'Hafta,Genel Skor,Ruh Hali,Stres,Takım,Gelişim,Denge,Katılımcı'
  const rows = trend.points.map((p) =>
    [
      p.weekStart,
      p.score.toFixed(1),
      p.dimensions.mood.toFixed(1),
      p.dimensions.stress.toFixed(1),
      p.dimensions.team.toFixed(1),
      p.dimensions.growth.toFixed(1),
      p.dimensions.balance.toFixed(1),
      p.participantCount,
    ].join(','),
  )
  return [header, ...rows].join('\n')
}
