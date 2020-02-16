import * as maps from '@google/maps';
import * as functions from 'firebase-functions';
import * as https from 'https';

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

export const normalizeGoogleMapsLocation = async (inputData: InputData): Promise<LocationData> => {
    const expandedURL: URL = await new Promise((resolve, reject) => {
        https.get(inputData.url, (response) => {
            if (response.headers.location) {
                resolve(new URL(response.headers.location));
            } else {
                reject();
            }
        });
    });

    let locationData: LocationData | null;

    locationData = await normalizeGoogleMapsLocationWithFtid(expandedURL);
    if (locationData) {
        return locationData;
    }

    locationData = await normalizeGoogleMapsLocationWithCoordinate(expandedURL, inputData);
    if (locationData) {
        return locationData;
    }

    locationData = await normalizeGoogleMapsLocationWithQuery(expandedURL);
    if (locationData) {
        return locationData;
    }

    throw new Error('Cannot find details for the Google Maps URL');
};

// Point of Interests
// https://stackoverflow.com/a/47042514/784241
const normalizeGoogleMapsLocationWithFtid = async (expandedURL: URL): Promise<LocationData | null> => {
    const ftid = expandedURL.searchParams.get('ftid');

    if (!ftid) {
        return null;
    }

    return normalizeGoogleMapsLocationWithIdentifier({ ftid: ftid }, expandedURL);
};

const normalizeGoogleMapsLocationWithCoordinate = async (expandedURL: URL, inputData: InputData): Promise<LocationData | null> => {
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
        address: normalizeGoogleMapsAddressComponents(place.address_components),
        coordinate: {
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        },
        name: convertAlphanumericsToAscii(inputData.rawData['public.plain-text']),
        url: expandedURL.toString(),
        websiteURL: null
    };
};

// Last resort
const normalizeGoogleMapsLocationWithQuery = async (expandedURL: URL): Promise<LocationData | null> => {
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

    return normalizeGoogleMapsLocationWithIdentifier({ placeid: place.place_id }, expandedURL);
}

const normalizeGoogleMapsLocationWithIdentifier = async (id: { placeid?: string, ftid?: string }, expandedURL: URL): Promise<LocationData | null> => {
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
        address: normalizeGoogleMapsAddressComponents(place.address_components),
        coordinate: {
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        },
        name: convertAlphanumericsToAscii(place.name),
        url: expandedURL.toString(),
        websiteURL: place.website || null
    };
}

const normalizeGoogleMapsAddressComponents = (rawAddressComponents: object[]): Address => {
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
