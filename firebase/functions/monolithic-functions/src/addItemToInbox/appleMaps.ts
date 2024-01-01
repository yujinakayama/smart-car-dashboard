import { InputData } from './inputData'
import { Location } from './normalizedData'

export function isAppleMapsLocation(inputData: InputData): boolean {
  return !!inputData.attachments['com.apple.mapkit.map-item']
}

export async function normalizeAppleMapsLocation(inputData: InputData): Promise<Location> {
  const mapItem = inputData.attachments['com.apple.mapkit.map-item']!

  return {
    type: 'location',
    address: {
      country: mapItem.placemark.country,
      prefecture: mapItem.placemark.administrativeArea,
      distinct: null,
      locality: mapItem.placemark.locality,
      subLocality: mapItem.placemark.thoroughfare,
      houseNumber: mapItem.placemark.subThoroughfare,
    },
    categories: normalizeCategory(mapItem.pointOfInterestCategory),
    coordinate: mapItem.placemark.coordinate,
    name: mapItem.name,
    websiteURL: mapItem.url ? new URL(mapItem.url).toString() : null, // To handle internationalized domain names
    url: inputData.url.toString(),
  }
}

export function normalizeCategory(category: string | null): string[] {
  if (!category) {
    return []
  }

  const normalizedCategory = category
    .replace(/^MKPOICategory/, '')
    .replace(/^[A-Z]+(?![a-z])|^[A-Z][a-z]+/, (firstWord) => firstWord.toLowerCase())

  return [normalizedCategory]
}
