import { Timestamp } from 'firebase/firestore'

export type QuestionType = 'emoji5' | 'scale10' | 'scale5' | 'yesno' | 'trueFalse' | 'text'
export type SurveyStatus = 'draft' | 'active' | 'closed'

export interface SurveyQuestion {
  id: string
  text: string
  type: QuestionType
  hint: string
  /** Groups this question into a named category for aggregate scoring. */
  category?: string
  /** Evet=1,Hayır=5 when true (negatively-framed question, e.g. "Mobbing yaşadınız mı?"). */
  reverseScore?: boolean
  /** Marks the designated eNPS question (must be scale10). */
  isEnps?: boolean
}

export interface SurveyDoc {
  id: string
  companyId: string
  title: string
  description: string
  emoji: string
  status: SurveyStatus
  questions: SurveyQuestion[]
  deadline?: Timestamp | null
  minNThreshold: number
  responseCount: number
  /** When true this survey is shown as an entry gate on app launch. */
  isGate?: boolean
  /** When true users cannot skip the gate survey. */
  isMandatory?: boolean
  created_at?: Timestamp
  updated_at?: Timestamp
}

export interface SurveyResponseDoc {
  id: string
  surveyId: string
  companyId: string
  userIdHash: string
  answers: Record<string, number | string | boolean>
  created_at?: Timestamp
}
