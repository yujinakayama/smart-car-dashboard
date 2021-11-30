import { AddressType, Client, Language, PlaceData, PlaceDetailsRequest, PlaceInputType, PlaceType1, PlaceType2 } from "@googlemaps/google-maps-services-js";
import axios from 'axios';
import * as functions from 'firebase-functions';

import { URL } from 'url';

import { decodeURLDataParameter } from './googleMapsURLDataParameter'
import { InputData } from './inputData';
import { Location, Address } from './normalizedData';
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
    'street_addres',
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
];

const googleMapsClient = new Client();
const googleMapsAPIKey = functions.config().googlemaps.api_key;

export function isGoogleMapsLocation(inputData: InputData): boolean {
    const url = inputData.url;

    if (url.toString().startsWith('https://goo.gl/maps/')) {
        return true;
    }

    return !!url.hostname.match(/((www|maps)\.)google\.(com|co\.jp)/)
        && !!url.pathname.startsWith('/maps/place/')
}

export async function normalizeGoogleMapsLocation(inputData: InputData): Promise<Location> {
    const expandedURL = await expandShortenURL(inputData.url);

    let locationData: Location | null;

    locationData = await normalizeLocationWithFtid(expandedURL);
    if (locationData) {
        return locationData;
    }

    locationData = await normalizeLocationWithCoordinate(expandedURL, inputData);
    if (locationData) {
        return locationData;
    }

    locationData = await normalizeLocationWithQuery(expandedURL);
    if (locationData) {
        return locationData;
    }

    throw new Error('Cannot find details for the Google Maps URL');
}

async function expandShortenURL(url: URL): Promise<URL> {
    if (url.hostname !== 'goo.gl') {
        return url;
    }

    const response = await axios.get(url.toString(), {
        maxRedirects: 0,
        validateStatus: (statusCode) => true
    });

    const expandedURLString = response.headers['location'];

    if (expandedURLString) {
        return new URL(expandedURLString);
    } else {
        throw new Error(`URL could not be expanded: ${url.toString()}`)
    }
}

// Point of Interests
// https://stackoverflow.com/a/47042514/784241
async function normalizeLocationWithFtid(expandedURL: URL): Promise<Location | null> {
    let ftid = expandedURL.searchParams.get('ftid');

    if (!ftid) {
        const matches = expandedURL.pathname.match(/\/data=([^\/]+)/)
        const dataParameter = matches && matches[1];

        if (!dataParameter) {
            return null;
        }

        const data = decodeURLDataParameter(dataParameter);
        ftid = data.place?.geometry?.ftid || null;
    }

    if (!ftid) {
        return null;
    }

    return normalizeLocationWithIdentifier({ ftid: ftid }, expandedURL);
}

async function normalizeLocationWithCoordinate(expandedURL: URL, inputData: InputData): Promise<Location | null> {
    const query = expandedURL.searchParams.get('q');

    if (!query) {
        return null;
    }

    if (!query.match(/^[\d\.]+,[\d\.]+$/)) {
        return null;
    }

    const response = await googleMapsClient.reverseGeocode({
        params: {
            latlng: query,
            language: Language.ja,
            key: googleMapsAPIKey
        }
    });

    const place = response.data.results[0];

    if (!place) {
        return null;
    }

    return {
        type: 'location',
        address: normalizeAddressComponents(place.address_components),
        category: categoryOf(place),
        coordinate: {
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        },
        name: convertAlphanumericsToAscii(inputData.attachments['public.plain-text']),
        url: expandedURL.toString(),
        websiteURL: null
    };
}

// Last resort
async function normalizeLocationWithQuery(expandedURL: URL): Promise<Location | null> {
    const query = expandedURL.searchParams.get('q');

    if (!query) {
        return null;
    }

    const response = await googleMapsClient.findPlaceFromText({
        params: {
            input: query,
            inputtype: PlaceInputType.textQuery,
            language: Language.ja,
            key: googleMapsAPIKey
        }
    });

    const place = response.data.candidates[0]

    if (!place) {
        return null;
    }

    return normalizeLocationWithIdentifier({ placeid: place.place_id }, expandedURL);
}

async function normalizeLocationWithIdentifier(id: { placeid?: string, ftid?: string }, expandedURL: URL): Promise<Location | null> {
    if (!id.placeid && !id.ftid) {
        throw new Error('Either placeid or ftid must be given');
    }

    const requestParameters: PlaceDetailsRequest = {
        params: {
            place_id: id.placeid || '',
            fields: ['address_component', 'geometry', 'name', 'type', 'website'],
            language: Language.ja,
            key: googleMapsAPIKey
        }
    }

    if (id.ftid) {
        // @ts-ignore
        requestParameters.params.ftid = id.ftid
    }

    const response = await googleMapsClient.placeDetails(requestParameters);

    const place = response.data.result;

    if (!place.geometry || !place.address_components) {
        return null;
    }

    return {
        type: 'location',
        address: normalizeAddressComponents(place.address_components),
        category: categoryOf(place),
        coordinate: {
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        },
        name: convertAlphanumericsToAscii(place.name),
        url: expandedURL.toString(),
        websiteURL: place.website || null
    };
}

function normalizeAddressComponents(rawAddressComponents: object[]): Address {
    const components: GoogleMapsAddressComponents = rawAddressComponents.reverse().reduce((object: any, rawComponent: any) => {
        const key = rawComponent.types.find((type: string) => googleMapsAddressComponentKeys.includes(type))
        if (!object[key]) {
            object[key] = convertAlphanumericsToAscii(rawComponent.long_name);
        }
        return object;
    }, {});

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
    };
}

function categoryOf(place: Partial<PlaceData>): string | null {
    const types = place.types;

    if (!types) {
        return null;
    }

    if (types.includes(PlaceType2.place_of_worship) && !isGooglePredefinedWorshipPlace(types)) {
        // https://ja.wikipedia.org/wiki/日本の寺院一覧
        if (place.name?.match(/(寺|院|大師|薬師|観音|帝釈天)$/)) {
            return 'buddhistTemple';
        }

        // https://ja.wikipedia.org/wiki/神社一覧
        if (place.name?.match(/(神社|大社|宮|分祠)$/)) {
            return 'shintoShrine';
        }
    }

    return convertToCamelCase(types[0].toString());
}

function isGooglePredefinedWorshipPlace(types: AddressType[]): boolean {
    return types.includes(PlaceType1.cemetery) ||
           types.includes(PlaceType1.church) ||
           types.includes(PlaceType1.hindu_temple) ||
           types.includes(PlaceType1.mosque) ||
           types.includes(PlaceType1.synagogue);
}

function convertToCamelCase(string: string): string {
    return string.replace(/(_[a-z])/ig, (match) => {
        return match.toUpperCase().replace('_', '');
    });
}
