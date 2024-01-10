import { PlaceURL, convertAddressComponentsToObject, expandURL } from '@dash/google-maps'
import { Client, extractRestaurantIDFromURL } from '@dash/tabelog'
import { Restaurant } from '@dash/tabelog/src/restaurant'
import { Place as GooglePlace } from '@googlemaps/google-maps-services-js'
import { onRequest } from 'firebase-functions/v2/https'
import { customsearch_v1, google } from 'googleapis'

import { distanceBetween } from './coordinate'

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

export const searchTabelogPage = onRequest(
  {
    region: 'asia-northeast1',
    secrets: [googleAPIKeyEnvName, tabelogDeviceIDEnvName, tabelogSecretTokenEnvName],
  },
  async (functionRequest, functionResponse) => {
    const request = functionRequest.body as Request
    console.log('request:', request)

    const url = await expandURL(request.place.url)
    const placeURL = new PlaceURL(url, googleAPIKey)
    const place = await placeURL.fetchPlaceDetails(['address_component', 'geometry', 'name'])
    if (!place) {
      throw new Error(`no Google Maps place found for ${placeURL}`)
    }
    const webpage = await searchTabelogPageFor(place)

    functionResponse.send(webpage)
  },
)

type SearchResultWebpage = Pick<customsearch_v1.Schema$Result, 'title' | 'link'>

async function searchTabelogPageFor(place: GooglePlace): Promise<SearchResultWebpage | null> {
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

  const restaurant = await findMatchingTabelogRestaurant(webpages, place)
  if (!restaurant) {
    return null
  }

  // For backward compatibility
  return {
    title: restaurant.name,
    link: restaurant.webURL.toString(),
  }
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

async function findMatchingTabelogRestaurant(
  webpages: SearchResultWebpage[],
  place: GooglePlace,
): Promise<Restaurant | null> {
  if (!place.geometry) {
    throw new Error('geometry is missing in the Place')
  }

  const restaurantIDs = collectRestaurantIDsFrom(webpages)

  const placeCoordinate = {
    latitude: place.geometry.location.lat,
    longitude: place.geometry.location.lng,
  }

  for (const restaurantID of restaurantIDs) {
    const restaurant = await tabelogClient.getRestaurant(restaurantID)
    if (!restaurant) {
      continue
    }

    const distance = distanceBetween(restaurant.coordinate, placeCoordinate)
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
