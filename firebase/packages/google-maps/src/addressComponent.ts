import { convertAlphanumericsToASCII } from '@dash/text-util'
import { AddressComponent } from '@googlemaps/google-maps-services-js'

// https://developers.google.com/maps/documentation/geocoding/intro#Types
export interface Address {
  administrative_area_level_1?: string
  administrative_area_level_2?: string
  administrative_area_level_3?: string
  administrative_area_level_4?: string
  administrative_area_level_5?: string
  airport?: string
  colloquial_area?: string
  country?: string
  intersection?: string
  locality?: string
  natural_feature?: string
  neighborhood?: string
  park?: string
  point_of_interest?: string
  postal_code?: string
  premise?: string
  route?: string
  street_address?: string
  sublocality_level_1?: string
  sublocality_level_2?: string
  sublocality_level_3?: string
  sublocality_level_4?: string
  sublocality_level_5?: string
  subpremise?: string
}

const componentKeys = [
  'administrative_area_level_1',
  'administrative_area_level_2',
  'administrative_area_level_3',
  'administrative_area_level_4',
  'administrative_area_level_5',
  'airport',
  'colloquial_area',
  'country',
  'intersection',
  'locality',
  'natural_feature',
  'neighborhood',
  'park',
  'point_of_interest',
  'postal_code',
  'premise',
  'route',
  'street_address',
  'sublocality_level_1',
  'sublocality_level_2',
  'sublocality_level_3',
  'sublocality_level_4',
  'sublocality_level_5',
  'subpremise',
]

export function convertAddressComponentsToObject(
  rawAddressComponents: AddressComponent[],
): Address {
  return rawAddressComponents.reverse().reduce((object: any, rawComponent: AddressComponent) => {
    const key = rawComponent.types.find((type: string) => componentKeys.includes(type))
    if (key && !object[key]) {
      object[key] = convertAlphanumericsToASCII(rawComponent.long_name)
    }
    return object
  }, {})
}
