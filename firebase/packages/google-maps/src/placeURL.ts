import {
  Client,
  Language,
  Place,
  PlaceDetailsRequest,
  PlaceInputType,
} from '@googlemaps/google-maps-services-js'

import { ExpandedURL } from './url'
import { decodeURLDataParameter } from './urlDataParameter'

type PlaceIdentifier = { placeid: string } | { ftid: string }

export class PlaceURL {
  client: Client

  constructor(
    public url: ExpandedURL,
    public apiKey: string,
  ) {
    if (!isPlaceURL(url)) {
      throw new Error(`${url} is not a place URL of Google Maps`)
    }

    this.client = new Client()
  }

  async fetchPlaceDetails(fields: string[]): Promise<Place | null> {
    const identifier = await this.getPlaceIdentifier()
    if (!identifier) {
      return null
    }

    const request = this.buildPlaceDetailsRequest(identifier)
    request.params.fields = fields
    const response = await this.client.placeDetails(request)
    return response.data.result
  }

  // https://stackoverflow.com/a/47042514/784241
  async getPlaceIdentifier(): Promise<PlaceIdentifier | null> {
    const ftid = this.extractFtid()
    if (ftid) {
      return { ftid }
    }

    const query = this.extractQuery() ?? this.extractPlaceName()
    if (!query) {
      return null
    }

    const placeid = await this.findPlaceIDFromQuery(query)
    if (!placeid) {
      return null
    }

    return { placeid }
  }

  extractFtid(): string | null {
    const ftid = this.url.searchParams.get('ftid')
    if (ftid) {
      return ftid
    }

    const matches = this.url.pathname.match(/\/data=([^/]+)/)
    const dataParameter = matches && matches[1]
    if (!dataParameter) {
      return null
    }

    const data = decodeURLDataParameter(dataParameter)
    return data.place?.geometry?.ftid ?? null
  }

  extractQuery(): string | null {
    return this.url.searchParams.get('q')
  }

  extractPlaceName(): string | null {
    const placeName = this.url.pathname.match(/^\/maps\/place\/([^/]+)/)?.[1]
    if (!placeName) {
      return null
    }
    return decodeURIComponent(placeName)
  }

  async findPlaceIDFromQuery(query: string): Promise<string | null> {
    const response = await this.client.findPlaceFromText({
      params: {
        input: query,
        inputtype: PlaceInputType.textQuery,
        language: Language.ja,
        key: this.apiKey,
      },
    })

    const place = response.data.candidates[0]
    return place.place_id || null
  }

  buildPlaceDetailsRequest(identifier: PlaceIdentifier): PlaceDetailsRequest {
    const request: PlaceDetailsRequest = {
      params: {
        place_id: 'placeid' in identifier ? identifier.placeid : '',
        language: Language.ja,
        key: this.apiKey,
      },
    }

    if ('ftid' in identifier) {
      request.params = Object.assign(request.params, { ftid: identifier.ftid })
    }

    return request
  }
}

export function isPlaceURL(url: URL): boolean {
  if (url.hostname.match(/^maps\.google\.(com|co\.jp)$/)) {
    return url.searchParams.has('q') || url.searchParams.has('ftid')
  } else if (url.hostname.match(/\.google\.(com|co\.jp)$/)) {
    return url.pathname.startsWith('/maps/place/')
  } else {
    return false
  }
}
