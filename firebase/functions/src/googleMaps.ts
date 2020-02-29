import * as maps from '@google/maps';
import axios from 'axios';
import * as functions from 'firebase-functions';

import { URL } from 'url';

import { InputData } from './inputData';
import { LocationData, Address } from './normalizedData';
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

const googleMapsClient = maps.createClient({ key: functions.config().googlemaps.api_key, Promise: Promise });

export function isGoogleMapsLocation(inputData: InputData): boolean {
    return inputData.url.toString().startsWith('https://goo.gl/maps/');
}

export async function normalizeGoogleMapsLocation(inputData: InputData): Promise<LocationData> {
    const expandedURL = await expandShortenURL(inputData.url);

    let locationData: LocationData | null;

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

async function expandShortenURL(shortenURL: URL): Promise<URL> {
    const response = await axios.get(shortenURL.toString(), {
        maxRedirects: 0,
        validateStatus: (statusCode) => true
    });

    const expandedURLString = response.headers['location'];

    if (expandedURLString) {
        return new URL(expandedURLString);
    } else {
        throw new Error(`Shorten URL could not be expanded: ${shortenURL.toString()}`)
    }
}

// Point of Interests
// https://stackoverflow.com/a/47042514/784241
async function normalizeLocationWithFtid(expandedURL: URL): Promise<LocationData | null> {
    const ftid = expandedURL.searchParams.get('ftid');

    if (!ftid) {
        return null;
    }

    return normalizeLocationWithIdentifier({ ftid: ftid }, expandedURL);
}

async function normalizeLocationWithCoordinate(expandedURL: URL, inputData: InputData): Promise<LocationData | null> {
    const query = expandedURL.searchParams.get('q');

    if (!query) {
        return null;
    }

    if (!query.match(/^[\d\.]+,[\d\.]+$/)) {
        return null;
    }

    const response = await googleMapsClient.reverseGeocode({
        latlng: query,
        language: 'ja'
    }).asPromise()

    const place = response.json.results[0];

    if (!place) {
        return null;
    }

    return {
        type: 'location',
        address: normalizeAddressComponents(place.address_components),
        coordinate: {
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        },
        name: convertAlphanumericsToAscii(inputData.rawData['public.plain-text']),
        url: expandedURL.toString(),
        websiteURL: null
    };
}

// Last resort
async function normalizeLocationWithQuery(expandedURL: URL): Promise<LocationData | null> {
    const query = expandedURL.searchParams.get('q');

    if (!query) {
        return null;
    }

    const response = await googleMapsClient.findPlace({
        input: query,
        inputtype: 'textquery',
        language: 'ja'
    }).asPromise();

    const place = response.json.candidates[0]

    if (!place) {
        return null;
    }

    return normalizeLocationWithIdentifier({ placeid: place.place_id }, expandedURL);
}

async function normalizeLocationWithIdentifier(id: { placeid?: string, ftid?: string }, expandedURL: URL): Promise<LocationData | null> {
    if (!id.placeid && !id.ftid) {
        throw new Error('Either placeid or ftid must be given');
    }

    const requestParameters: maps.PlaceDetailsRequest = {
        placeid: id.placeid || '',
        fields: ['address_component', 'geometry', 'name', 'website'],
        language: 'ja'
    }

    const customParameters: any = {}

    if (id.ftid) {
        customParameters['ftid'] = id.ftid
    }

    // @ts-ignore
    const response = await googleMapsClient.place(requestParameters, null, customParameters).asPromise();

    const place = response.json.result;

    return {
        type: 'location',
        address: normalizeAddressComponents(place.address_components),
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
