import { onRequest } from 'firebase-functions/v2/https'
import { customsearch_v1, google } from 'googleapis'
import { Client, Language } from '@googlemaps/google-maps-services-js'
import { CLLocationCoordinate2D, MKMapItem } from './mapItem'
import { GoogleMapsAddressComponents, convertAddressComponentsToObject } from './googleMapsUtil'

export const requiredEnvName = 'GOOGLE_API_KEY'
// If the secret is missing, it'll be error on deployment
const apiKey = process.env[requiredEnvName] ?? ''

const mapsClient = new Client()

const customSearchClient = google.customsearch({ version: 'v1', auth: apiKey })

const programmableSearchEngineID = 'd651ff481bfec4e8d'

const excludedDomains = [
    'akippa.com',
    'earth-car.com',
    'its-mo.com',
    'mapfan.com',
    'mapion.co.jp',
    'navitime.co.jp',
    'navitime.com',
    'parkinggod.jp',
    'times-info.net',
]

interface Request {
    mapItem: MKMapItem;
}

export const searchOfficialParkings = onRequest({
    region: 'asia-northeast1',
    secrets: [requiredEnvName]
}, async (functionRequest, functionResponse) => {
    const request = functionRequest.body as Request
    console.log('request:', request)
    const { mapItem } = request
    const address = await fetchAddressOf(mapItem.placemark.coordinate)
    const webpage = await fetchWebpageForOfficinalParkingOf(mapItem, address)
    functionResponse.send(webpage)
})

async function fetchAddressOf(coordinate: CLLocationCoordinate2D): Promise<GoogleMapsAddressComponents> {
    const response = await mapsClient.reverseGeocode({
        params: {
            latlng: coordinate,
            language: Language.ja,
            key: apiKey
        }
    })

    const geocodingResult = response.data.results[0]

    if (!geocodingResult) {
        throw new Error('No result for reverse geocode')
    }

    return convertAddressComponentsToObject(geocodingResult.address_components)
}

type SearchResultWebpage = Pick<customsearch_v1.Schema$Result, 'title' | 'link'>

async function fetchWebpageForOfficinalParkingOf(mapItem: MKMapItem, address: GoogleMapsAddressComponents): Promise<SearchResultWebpage | null> {
    const searchWords = [
        mapItem.name,
        '"駐車場"',
        address.administrative_area_level_1,
        address.locality,
    ].filter((string) => string)

    const queryComponents = searchWords.concat(excludedDomains.map((domain) => `-site:${domain}`))

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
        q: queryComponents.join(' '),
        // https://developers.google.com/custom-search/v1/performance#partial
        fields: 'items(title,link)',
    })

    return searchResponse.data.items?.[0] ?? null
}
