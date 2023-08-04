import { AddressType, Client, Language, PlaceData, PlaceDetailsRequest, PlaceInputType, PlaceType1, PlaceType2 } from '@googlemaps/google-maps-services-js'
// @ts-ignore: no type definition provided
import { parse_host as parseHost } from 'tld-extract'


import { URL } from 'url'

import { decodeURLDataParameter } from './googleMapsURLDataParameter'
import { InputData } from './inputData'
import { Location, Address } from './normalizedData'
import { convertAlphanumericsToAscii } from './util'

// https://developers.google.com/maps/documentation/geocoding/intro#Types
interface GoogleMapsAddressComponents {
    street_address?: string;
    route?: string;
    intersection?: string;
    political?: string;
    country?: string;
    administrative_area_level_1?: string;
    administrative_area_level_2?: string;
    administrative_area_level_3?: string;
    administrative_area_level_4?: string;
    administrative_area_level_5?: string;
    colloquial_area?: string;
    locality?: string;
    sublocality_level_1?: string;
    sublocality_level_2?: string;
    sublocality_level_3?: string;
    sublocality_level_4?: string;
    sublocality_level_5?: string;
    neighborhood?: string;
    premise?: string;
    subpremise?: string;
    postal_code?: string;
    natural_feature?: string;
    airport?: string;
    park?: string;
    point_of_interest?: string;
}

const googleMapsAddressComponentKeys = [
    'street_address',
    'route',
    'intersection',
    'political',
    'country',
    'administrative_area_level_1',
    'administrative_area_level_2',
    'administrative_area_level_3',
    'administrative_area_level_4',
    'administrative_area_level_5',
    'colloquial_area',
    'locality',
    'sublocality_level_1',
    'sublocality_level_2',
    'sublocality_level_3',
    'sublocality_level_4',
    'sublocality_level_5',
    'neighborhood',
    'premise',
    'subpremise',
    'postal_code',
    'natural_feature',
    'airport',
    'park',
    'point_of_interest'
]

export const requiredEnvName = 'GOOGLE_API_KEY'
// If the secret is missing, it'll be error on deployment
const apiKey = process.env[requiredEnvName] ?? ''

const client = new Client()

export async function isGoogleMapsLocation(inputData: InputData): Promise<boolean> {
    let url = inputData.url

    if (isGoogleShortenURL(url)) {
        url = await inputData.expandURL()
    }

    if (url.hostname.match(/^maps\.google\.(com|co\.jp)$/)) {
        return url.searchParams.has('q') || url.searchParams.has('ftid')
    } else if (url.hostname.match(/\.google\.(com|co\.jp)$/)) {
        return url.pathname.startsWith('/maps/place/')
    } else {
        return false
    }
}

function isGoogleShortenURL(url: URL): boolean {
    return parseHost(url.host).domain == 'goo.gl'
}

export async function normalizeGoogleMapsLocation(inputData: InputData): Promise<Location> {
    const expandedURL = await inputData.expandURL()

    let locationData: Location | null

    locationData = await normalizeLocationWithFtid(expandedURL, inputData)
    if (locationData) {
        return locationData
    }

    locationData = await normalizeLocationWithCoordinate(expandedURL, inputData)
    if (locationData) {
        return locationData
    }

    locationData = await normalizeLocationWithQuery(expandedURL, inputData)
    if (locationData) {
        return locationData
    }

    throw new Error('Cannot find details for the Google Maps URL')
}

// Point of Interests
// https://stackoverflow.com/a/47042514/784241
async function normalizeLocationWithFtid(expandedURL: URL, inputData: InputData): Promise<Location | null> {
    let ftid = expandedURL.searchParams.get('ftid')

    if (!ftid) {
        const matches = expandedURL.pathname.match(/\/data=([^/]+)/)
        const dataParameter = matches && matches[1]

        if (!dataParameter) {
            return null
        }

        const data = decodeURLDataParameter(dataParameter)
        ftid = data.place?.geometry?.ftid || null
    }

    if (!ftid) {
        return null
    }

    return await normalizeLocationWithIdentifier({ ftid: ftid }, expandedURL, inputData)
}

async function normalizeLocationWithCoordinate(expandedURL: URL, inputData: InputData): Promise<Location | null> {
    const query = expandedURL.searchParams.get('q')

    if (!query) {
        return null
    }

    if (!query.match(/^[\d.]+,[\d.]+$/)) {
        return null
    }

    const response = await client.reverseGeocode({
        params: {
            latlng: query,
            language: Language.ja,
            key: apiKey
        }
    })

    const place = response.data.results[0]

    if (!place) {
        return null
    }

    return {
        type: 'location',
        address: normalizeAddressComponents(place.address_components),
        categories: normalizeCategories(place),
        coordinate: {
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        },
        name: convertAlphanumericsToAscii(inputData.attachments['public.plain-text']),
        url: expandedURL.toString(),
        websiteURL: null
    }
}

// Last resort
async function normalizeLocationWithQuery(expandedURL: URL, inputData: InputData): Promise<Location | null> {
    let query = expandedURL.searchParams.get('q')

    if (!query) {
        const placeName = expandedURL.pathname.match(/^\/maps\/place\/([^/]+)/)?.[1]

        if (placeName) {
            query = decodeURIComponent(placeName)
        } else {
            return null
        }
    }

    const response = await client.findPlaceFromText({
        params: {
            input: query,
            inputtype: PlaceInputType.textQuery,
            language: Language.ja,
            key: apiKey
        }
    })

    const place = response.data.candidates[0]

    if (!place) {
        return null
    }

    return normalizeLocationWithIdentifier({ placeid: place.place_id }, expandedURL, inputData)
}

async function normalizeLocationWithIdentifier(id: { placeid?: string, ftid?: string }, expandedURL: URL, inputData: InputData): Promise<Location | null> {
    if (!id.placeid && !id.ftid) {
        throw new Error('Either placeid or ftid must be given')
    }

    const requestParameters: PlaceDetailsRequest = {
        params: {
            place_id: id.placeid || '',
            fields: ['address_component', 'geometry', 'name', 'type', 'website'],
            language: Language.ja,
            key: apiKey
        }
    }

    if (id.ftid) {
        // @ts-ignore ftid is not officially supported but works
        requestParameters.params.ftid = id.ftid
    }

    const response = await client.placeDetails(requestParameters)

    const place = response.data.result

    if (!place.geometry || !place.address_components) {
        return null
    }

    let name: string | undefined
    
    if (isPointOfInterest(place)) {
        name = place.name || inputData.attachments['public.plain-text']
    } else {
        name = inputData.attachments['public.plain-text'] || place.name
    }

    return {
        type: 'location',
        address: normalizeAddressComponents(place.address_components),
        categories: normalizeCategories(place),
        coordinate: {
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        },
        name: convertAlphanumericsToAscii(name),
        url: expandedURL.toString(),
        websiteURL: place.website ? (new URL(place.website)).toString() : null // // To handle internationalized domain names
    }
}

function normalizeAddressComponents(rawAddressComponents: object[]): Address {
    const components: GoogleMapsAddressComponents = rawAddressComponents.reverse().reduce((object: any, rawComponent: any) => {
        const key = rawComponent.types.find((type: string) => googleMapsAddressComponentKeys.includes(type))
        if (!object[key]) {
            object[key] = convertAlphanumericsToAscii(rawComponent.long_name)
        }
        return object
    }, {})

    return {
        country: components.country || null,
        prefecture: components.administrative_area_level_1 || null,
        distinct: components.administrative_area_level_2 || null,
        locality: components.locality || null,
        subLocality: [
            components.sublocality_level_1,
            components.sublocality_level_2,
            components.sublocality_level_3,
            components.sublocality_level_4,
            components.sublocality_level_5
        ].filter((e) => e).join('') || null,
        houseNumber: components.premise || null
    }
}

function isPointOfInterest(place: Partial<PlaceData>): boolean {
    if (!place.types) {
        return false
    }

    return place.types[0] !== PlaceType2.premise
}

function normalizeCategories(place: Partial<PlaceData>): string[] {
    const types = place.types

    if (!types) {
        return []
    }

    const categories = types.map((type) => convertToCamelCase(type.toString()))

    if (place.name) {
        const names = extractNameSegments(convertAlphanumericsToAscii(place.name) ?? '')

        if (types.includes(PlaceType2.place_of_worship) && !isGooglePredefinedWorshipPlace(types)) {
            if (names.some((name) => name.match(/(寺|院|大師|薬師|観音|帝釈天)$/))) {
                // https://ja.wikipedia.org/wiki/日本の寺院一覧
                categories.unshift('buddhistTemple')
            } else if (names.some((name) => name.match(/(神社|大社|宮|祠)$/))) {
                // https://ja.wikipedia.org/wiki/神社一覧
                categories.unshift('shintoShrine')
            }
        }

        if (names.some((name) => name.match(/(\W(PA|SA)|(パーキング|サービス)エリア)$|ハイウェイオアシス|EXPASA/))) {
            categories.unshift('restArea')
        }

        if (place.name.startsWith('道の駅')) {
            categories.unshift('roadsideStation')
        }
    }

    return categories
}

function isGooglePredefinedWorshipPlace(types: AddressType[]): boolean {
    return types.includes(PlaceType1.cemetery) ||
           types.includes(PlaceType1.church) ||
           types.includes(PlaceType1.hindu_temple) ||
           types.includes(PlaceType1.mosque) ||
           types.includes(PlaceType1.synagogue)
}

function convertToCamelCase(string: string): string {
    return string.replace(/(_[a-z])/g, (match) => {
        return match.toUpperCase()
    }).replace(/_/g, '')
}

function extractNameSegments(name: string): string[] {
    // eslint-disable-next-line no-irregular-whitespace
    return name.split(/[\s　()（）]+/).filter((string) => string)
}
