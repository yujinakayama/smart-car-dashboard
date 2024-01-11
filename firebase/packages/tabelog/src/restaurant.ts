import { Coordinate } from './coordinate'

export interface Restaurant {
  address: string
  averageBudget: Budget
  coordinate: Coordinate
  genres: string[]
  id: number
  name: string
  reviewCount: number
  score: number
  webURL: URL
}

interface Budget {
  lunch: string
  dinner: string
}
