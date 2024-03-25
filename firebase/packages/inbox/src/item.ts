interface itemBase {
  type: string
  url: string
}

export interface Location extends itemBase {
  type: 'location'
  address: Address
  categories: string[]
  coordinate: {
    latitude: number
    longitude: number
  }
  description: string | null // Firebase doesn't allow `undefined` values
  name: string | null
  websiteURL: string | null
}

export interface Address {
  country: string | null // 国
  prefecture: string | null // 都道府県
  distinct: string | null // 郡
  locality: string | null // 市区町村
  subLocality: string | null // 大字・字・丁目
  houseNumber: string | null // 番地
}

export interface MusicItem extends itemBase {
  type: 'musicItem'
  artworkURLTemplate: string | null
  creator: string | null
  name: string | null
  playParameters: {
    id: string
    kind: string
  } | null
}

export interface Video extends itemBase {
  type: 'video'
  creator: string | null
  thumbnailURL: string | null
  title: string | null
}

export interface Website extends itemBase {
  type: 'website'
  title: string | null
}

// A plain item reperesenting each concrete type
export type Item = Location | MusicItem | Video | Website
