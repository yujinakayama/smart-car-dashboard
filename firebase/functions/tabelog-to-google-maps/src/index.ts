import { Client, Place, PlaceInputType, Language } from '@googlemaps/google-maps-services-js'
import { onRequest } from 'firebase-functions/v2/https'

import { TabelogRestaurant, parseTabelogRestaurantText } from './tabelogRestaurant'

const googleAPIKeyEnvName = 'GOOGLE_API_KEY'
// If the secret is missing, it'll be error on deployment
const googleAPIKey = process.env[googleAPIKeyEnvName] ?? ''
const googleMapsClient = new Client()

interface Request {
  text: string
}

interface Response {
  googleMapsURL: string | null
}

export const searchGooglePlaceForTabelogRestaurant = onRequest(
  {
    region: 'asia-northeast1',
    secrets: [googleAPIKeyEnvName],
  },
  async (functionRequest, functionResponse) => {
    const request = functionRequest.body as Request
    console.log('request:', request)

    const tabelogRestaurant = parseTabelogRestaurantText(request.text)
    const googleMapsURL = await searchGooglePlaceFor(tabelogRestaurant)

    const response: Response = {
      googleMapsURL,
    }
    functionResponse.send(response)
  },
)

async function searchGooglePlaceFor(restaurant: TabelogRestaurant): Promise<string | null> {
  let placeID: string | undefined
  if (restaurant.phoneNumber) {
    const place = await searchGooglePlaceWithPhoneNumber(restaurant.phoneNumber)
    placeID = place?.place_id
  }

  if (!placeID && restaurant.name) {
    const queryWords = [restaurant.name, restaurant.address].filter((s) => s)
    const place = await searchGooglePlaceWithQuery(queryWords.join(' '))
    placeID = place?.place_id
  }

  if (!placeID) {
    return null
  }

  const placeDetailsResponse = await googleMapsClient.placeDetails({
    params: {
      place_id: placeID,
      fields: ['url'],
      language: Language.ja,
      key: googleAPIKey,
    },
  })

  return placeDetailsResponse.data.result.url ?? null
}

async function searchGooglePlaceWithPhoneNumber(phoneNumber: string): Promise<Place | null> {
  const response = await googleMapsClient.findPlaceFromText({
    params: {
      input: convertPhoneNumberToE164Format(phoneNumber),
      inputtype: PlaceInputType.phoneNumber,
      language: Language.ja,
      key: googleAPIKey,
    },
  })

  return response.data.candidates[0]
}

async function searchGooglePlaceWithQuery(query: string): Promise<Place | null> {
  const response = await googleMapsClient.findPlaceFromText({
    params: {
      input: query,
      inputtype: PlaceInputType.textQuery,
      language: Language.ja,
      key: googleAPIKey,
    },
  })

  return response.data.candidates[0]
}

function convertPhoneNumberToE164Format(phoneNumber: string): string {
  if (phoneNumber.startsWith('+')) {
    return phoneNumber
  }

  return '+81-' + phoneNumber.replace(/^0/, '')
}
