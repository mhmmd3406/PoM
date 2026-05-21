import { Timestamp } from 'firebase/firestore'

export type QuestionType = 'emoji5' | 'scale10' | 'scale5' | 'yesno' | 'trueFalse' | 'text'
export type SurveyStatus = 'draft' | 'active' | 'closed'

export interface SurveyQuestion {
  id: string
  text: string
  type: QuestionType
  hint: string
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
