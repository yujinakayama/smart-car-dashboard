import { PlaceURL, convertAddressComponentsToObject, expandURL } from '@dash/google-maps'
import { Place } from '@googlemaps/google-maps-services-js'
import { onRequest } from 'firebase-functions/v2/https'
import { customsearch_v1, google } from 'googleapis'

export const requiredEnvName = 'GOOGLE_API_KEY'
// If the secret is missing, it'll be error on deployment
const apiKey = process.env[requiredEnvName] ?? ''

const customSearchClient = google.customsearch({ version: 'v1', auth: apiKey })
const programmableSearchEngineID = '314a907db394d4045'

interface Request {
  place: {
    url: string
  }
}

export const searchTabelogPage = onRequest(
  {
    region: 'asia-northeast1',
    secrets: [requiredEnvName],
  },
  async (functionRequest, functionResponse) => {
    const request = functionRequest.body as Request
    console.log('request:', request)

    const url = await expandURL(request.place.url)
    const placeURL = new PlaceURL(url, apiKey)
    const place = await placeURL.fetchPlaceDetails(['address_component', 'name'])
    if (!place) {
      throw new Error(`no Google Maps place found for ${placeURL}`)
    }
    const webpage = await searchTabelogPageFor(place)

    functionResponse.send(webpage)
  },
)

type SearchResultWebpage = Pick<customsearch_v1.Schema$Result, 'title' | 'link'>

async function searchTabelogPageFor(place: Place): Promise<SearchResultWebpage | null> {
  if (!place.address_components) {
    throw new Error('address_component is missing in the Place')
  }

  const address = convertAddressComponentsToObject(place.address_components)

  const searchWords = [place.name, address.administrative_area_level_1, address.locality].filter(
    (string) => string,
  )

  const searchResponse = await customSearchClient.cse.list({
    cx: programmableSearchEngineID,
    // Geolocation of end user.
    // Specifying a gl parameter value should lead to more relevant results.
    // This is particularly true for international customers and, even more specifically,
    // for customers in English- speaking countries other than the United States.
    gl: 'ja',
    // Sets the user interface language.
    // Explicitly setting this parameter improves the performance and the quality of your search results.
    hl: 'ja',
    num: 1,
    q: searchWords.join(' '),
    // https://developers.google.com/custom-search/v1/performance#partial
    fields: 'items(title,link)',
  })
  if (!searchResponse.data.items) {
    return null
  }

  const tabelogRestaurantPage = searchResponse.data.items.find((item) => {
    if (!item.link) {
      return false
    }

    return isTabelogRestaurantPageURL(new URL(item.link))
  })

  return tabelogRestaurantPage ?? null
}

function isTabelogRestaurantPageURL(url: URL): boolean {
  // https://tabelog.com/tokyo/A1301/A130102/13168901/
  // https://tabelog.com/tokyo/A1301/A130102/13168901/dtlphotolst/smp2/
  return url.pathname.match(/^\/[a-z]+\/[A-Z]\d+\/[A-Z]\d+\/\d+/) !== null
}
