import { Location } from '@dash/inbox'
import { Coordinate, distanceBetween } from '@dash/location-util'
import { MKMapItem } from '@dash/mapkit'
import { Place, Client, Language, PlaceInputType } from '@googlemaps/google-maps-services-js'

import { normalizeLocationWithIdentifier } from './googleMaps'
import { InputData } from './inputData'

export const requiredEnvName = 'GOOGLE_API_KEY'
// If the secret is missing, it'll be error on deployment
const googleAPIKey = process.env[requiredEnvName] ?? ''

const googleMapsClient = new Client()

export function isAppleMapsLocation(inputData: InputData): boolean {
  return !!inputData.attachments['com.apple.mapkit.map-item']
}

export async function normalizeAppleMapsLocation(inputData: InputData): Promise<Location> {
  const mapItem = inputData.attachments['com.apple.mapkit.map-item']!

  const placeID = await searchGooglePlaceFor(mapItem)
  if (!placeID) {
    throw new Error('Cannot find Google Place for the MKMapItem')
  }

  return await normalizeLocationWithIdentifier(
    { placeid: placeID },
    inputData,
    mapItem.name ?? undefined,
  )
}

async function searchGooglePlaceFor(mapItem: MKMapItem): Promise<string | null> {
  if (!mapItem.name) {
    return null
  }

  const coordinate = mapItem.placemark.coordinate

  const response = await googleMapsClient.findPlaceFromText({
    params: {
      input: mapItem.name,
      inputtype: PlaceInputType.textQuery,
      // https://developers.google.com/maps/documentation/places/web-service/search-find-place#locationbias
      locationbias: `circle:200@${coordinate.latitude},${coordinate.longitude}`,
      fields: ['place_id', 'geometry'],
      language: Language.ja,
      key: googleAPIKey,
    },
  })

  const place = findNearestPlace(response.data.candidates, coordinate)
  return place?.place_id ?? null
}

function findNearestPlace(places: Place[], targetCoordinate: Coordinate): Place | null {
  let nearestPlace: Place | null = null
  let nearestDistance = Infinity

  for (const place of places) {
    if (!place.geometry?.location) {
      continue
    }

    const placeCoordinate: Coordinate = {
      latitude: place.geometry.location.lat,
      longitude: place.geometry.location.lng,
    }

    const distance = distanceBetween(placeCoordinate, targetCoordinate)

    // Reject too far places
    if (distance > 200) {
      continue
    }

    if (distance < nearestDistance) {
      nearestPlace = place
      nearestDistance = distance
    }
  }

  return nearestPlace
}
