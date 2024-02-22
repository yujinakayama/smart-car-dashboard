import { PlaceURL, convertAddressComponentsToObject, expandURL } from '@dash/google-maps'
import { Client, extractRestaurantIDFromURL } from '@dash/tabelog'
import { Restaurant } from '@dash/tabelog/src/restaurant'
import { onRequest } from 'firebase-functions/v2/https'
import { customsearch_v1, google } from 'googleapis'

import { Coordinate, distanceBetween } from './coordinate'

const googleAPIKeyEnvName = 'GOOGLE_API_KEY'
// If the secret is missing, it'll be error on deployment
const googleAPIKey = process.env[googleAPIKeyEnvName] ?? ''
const googleSearchClient = google.customsearch({ version: 'v1', auth: googleAPIKey })
const programmableSearchEngineID = '314a907db394d4045'

const tabelogDeviceIDEnvName = 'TABELOG_DEVICE_ID'
const tabelogSecretTokenEnvName = 'TABELOG_SECRET_TOKEN'
// If the secret is missing, it'll be error on deployment
const tabelogClient = new Client({
  deviceID: process.env[tabelogDeviceIDEnvName] ?? '',
  secretToken: process.env[tabelogSecretTokenEnvName] ?? '',
})

interface Request {
  place: {
    url: string
  }
}

interface Response {
  restaurant?: Restaurant
}

export const searchTabelogPage = onRequest(
  {
    region: 'asia-northeast1',
    secrets: [googleAPIKeyEnvName, tabelogDeviceIDEnvName, tabelogSecretTokenEnvName],
  },
  async (functionRequest, functionResponse) => {
    const request = functionRequest.body as Request
    console.log('request:', request)

    const url = new URL(request.place.url)
    const restaurant = await searchTabelogRestaurantFor(url)

    let response: Response
    if (restaurant) {
      response = { restaurant }
    } else {
      response = {}
    }
    functionResponse.send(response)
  },
)

type SearchResultWebpage = Pick<customsearch_v1.Schema$Result, 'title' | 'link'>

async function searchTabelogRestaurantFor(url: URL): Promise<Restaurant | null> {
  const expandedURL = await expandURL(url)
  const placeURL = new PlaceURL(expandedURL, googleAPIKey)

  const place = await placeURL.fetchPlaceDetails(['address_component', 'geometry', 'name'])
  if (!place) {
    throw new Error(`No Google Maps place found for ${placeURL}`)
  }
  if (!place.address_components || !place.geometry || !place.name) {
    throw new Error('address_component, geometry, or name is missing in the Place')
  }

  const address = convertAddressComponentsToObject(place.address_components)
  const searchWords = [place.name, address.administrative_area_level_1, address.locality].filter(
    (string) => string,
  )

  const webpages = await searchGoogle(searchWords.join(' '))
  if (!webpages) {
    return null
  }

  return await findTabelogRestaurantNear(webpages, {
    latitude: place.geometry.location.lat,
    longitude: place.geometry.location.lng,
  })
}

async function searchGoogle(query: string): Promise<SearchResultWebpage[] | null> {
  const response = await googleSearchClient.cse.list({
    cx: programmableSearchEngineID,
    // Geolocation of end user.
    // Specifying a gl parameter value should lead to more relevant results.
    // This is particularly true for international customers and, even more specifically,
    // for customers in English- speaking countries other than the United States.
    gl: 'ja',
    // Sets the user interface language.
    // Explicitly setting this parameter improves the performance and the quality of your search results.
    hl: 'ja',
    num: 10,
    q: query,
    // https://developers.google.com/custom-search/v1/performance#partial
    fields: 'items(title,link)',
  })

  return response.data.items ?? null
}

async function findTabelogRestaurantNear(
  webpages: SearchResultWebpage[],
  targetCoordinate: Coordinate,
): Promise<Restaurant | null> {
  const restaurantIDs = collectRestaurantIDsFrom(webpages)

  for (const restaurantID of restaurantIDs) {
    const restaurant = await tabelogClient.getRestaurant(restaurantID)
    if (!restaurant) {
      continue
    }

    const distance = distanceBetween(restaurant.coordinate, targetCoordinate)
    if (distance <= 100) {
      return restaurant
    }
  }

  return null
}

function collectRestaurantIDsFrom(webpages: SearchResultWebpage[]): Set<number> {
  const restaurantIDs = webpages
    .map((webpage) => {
      if (!webpage.link) {
        return null
      }
      return extractRestaurantIDFromURL(webpage.link)
    })
    .filter((id) => id) as number[]

  return new Set(restaurantIDs)
}
