export interface MKMapItem {
  placemark: MKPlacemark
  name: string | null
  phoneNumber: string | null
  pointOfInterestCategory: string | null
  url: string | null
}

export interface MKPlacemark {
  coordinate: CLLocationCoordinate2D
  isoCountryCode: string | null
  country: string | null
  postalCode: string | null
  administrativeArea: string | null
  subAdministrativeArea: string | null
  locality: string | null
  subLocality: string | null
  thoroughfare: string | null
  subThoroughfare: string | null
}

export interface CLLocationCoordinate2D {
  latitude: number
  longitude: number
}
