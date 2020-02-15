import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as maps from '@google/maps';
import * as request from 'request-promise';
import * as libxmljs from 'libxmljs';
import * as https from 'https';
import * as urlRegex from 'url-regex';
import { URL } from 'url';

interface RawData {
    'public.url'?: string;
    'public.plain-text'?: string;
    'com.apple.mapkit.map-item'?: {
        placemark: {
            coordinate: {
                latitude: number;
                longitude: number;
            };
            isoCountryCode: string | null;
            country: string | null;
            postalCode: string | null;
            administrativeArea: string | null;
            subAdministrativeArea: string | null;
            locality: string | null;
            subLocality: string | null;
            thoroughfare: string | null;
            subThoroughfare: string | null;
        };
        name: string | null;
        phoneNumber: string | null;
        pointOfInterestCategory: string | null;
        url: string | null;
    };
}

interface BaseNormalizedData {
    type: string;
    url: string;
}

// Firebase doesn't allow `undefined` values
interface LocationData extends BaseNormalizedData {
    type: 'location';
    address: Address;
    coordinate: {
        latitude: number;
        longitude: number;
    };
    name: string | null;
    websiteURL: string | null;
}

interface Address {
    country: string | null; // 国
    prefecture: string | null; // 都道府県
    distinct: string | null; // 郡
    locality: string | null; // 市区町村
    subLocality: string | null; // 大字・字・丁目
    houseNumber: string | null; // 番地
}

interface WebsiteData extends BaseNormalizedData {
    type: 'website';
    title: string | null;
}

type NormalizedData = LocationData | WebsiteData;

// We want to extend NormalizedData but it's not allowed
interface Item extends BaseNormalizedData {
    raw: RawData;
}

interface NotificationPayload {
    aps: admin.messaging.Aps;
    foregroundPresentationOptions: UNNotificationPresentationOptions;
    item: Item;
    notificationType: 'share';
}

enum UNNotificationPresentationOptions {
    none  = 0,
    badge = 1 << 0,
    sound = 1 << 1,
    alert = 1 << 2
}

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

admin.initializeApp();

const urlPattern = urlRegex({ strict: true });

const googleMapsClient = maps.createClient({ key: functions.config().googlemaps.api_key, Promise: Promise });

export const share = functions.region('asia-northeast1').https.onRequest(async (functionRequest, functionResponse) => {
    const rawData = functionRequest.body as RawData;

    console.log('rawData:', rawData);

    const normalizedData = await normalize(rawData);

    console.log('normalizedData:', normalizedData);

    const item = {
        raw: rawData,
        ...normalizedData
    };

    await notify(item);

    await addItemToFirestore(item);

    functionResponse.sendStatus(200);
});

const normalize = (rawData: RawData): Promise<NormalizedData> => {
    const url = extractURL(rawData);

    if (!url) {
        throw new Error('Item has no URL');
    }

    if (rawData['com.apple.mapkit.map-item']) {
        return normalizeAppleMapsLocation(rawData, url);
    } else if (url.startsWith('https://goo.gl/maps/')) {
        return normalizeGoogleMapsLocation(rawData, url);
    } else {
        return normalizeWebpage(rawData, url);
    }
};

const extractURL = (rawData: RawData): string | null => {
    if (rawData['public.url']) {
        return rawData['public.url']
    }

    if (rawData['public.plain-text']) {
        const urls = rawData['public.plain-text'].match(urlPattern);

        if (urls && urls[0]) {
            return urls[0];
        }
    }

    return null;
}

const normalizeAppleMapsLocation = async (rawData: RawData, url: string): Promise<LocationData> => {
    const mapItem = rawData['com.apple.mapkit.map-item']!;

    return {
        type: 'location',
        address: {
            country: mapItem.placemark.country,
            prefecture: mapItem.placemark.administrativeArea,
            distinct: null,
            locality: mapItem.placemark.locality,
            subLocality: mapItem.placemark.thoroughfare,
            houseNumber: mapItem.placemark.subThoroughfare
        },
        coordinate: mapItem.placemark.coordinate,
        name: mapItem.name,
        websiteURL: mapItem.url,
        url: url
    };
};

const normalizeGoogleMapsLocation = async (rawData: RawData, url: string): Promise<LocationData> => {
    const expandedURL: URL = await new Promise((resolve, reject) => {
        https.get(url, (response) => {
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


    locationData = await normalizeGoogleMapsLocationWithCoordinate(expandedURL, rawData);
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

const normalizeGoogleMapsLocationWithCoordinate = async (expandedURL: URL, rawData: RawData): Promise<LocationData | null> => {
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
        name: rawData['public.plain-text'] || null,
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
        name: place.name,
        url: expandedURL.toString(),
        websiteURL: place.website || null
    };
}

const normalizeGoogleMapsAddressComponents = (rawAddressComponents: object[]): Address => {
    const components: GoogleMapsAddressComponents = rawAddressComponents.reverse().reduce((object: any, rawComponent: any) => {
        const key = rawComponent.types.find((type: string) => googleMapsAddressComponentKeys.includes(type))
        if (!object[key]) {
            object[key] = rawComponent.long_name;
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

const normalizeWebpage = async (rawData: RawData, url: string): Promise<WebsiteData> => {
    let title = rawData['public.plain-text'];

    if (!title || urlPattern.test(title)) {
        const responseBody = await request.get(url);
        const document = libxmljs.parseHtml(responseBody);
        title = document.get('//head/title')?.text().trim();
    }

    return {
        type: 'website',
        title: title || null,
        url: url
    };
};

const notify = (item: Item): Promise<any> => {
    const content = makeNotificationContent(item);

    const payload: NotificationPayload = {
        aps: content,
        foregroundPresentationOptions: UNNotificationPresentationOptions.sound,
        item: item,
        notificationType: 'share'
    };

    const message = {
        topic: 'Dash',
        apns: {
            // admin.messaging.ApnsPayload type requires `object` value for custom keys but it's wrong
            payload: payload as any
        }
    };

    return admin.messaging().send(message);
};

const makeNotificationContent = (item: Item): admin.messaging.Aps => {
    const normalizedData = item as unknown as NormalizedData;

    let alert: admin.messaging.ApsAlert

    switch (normalizedData.type) {
        case 'location':
            alert = {
                title: '目的地',
                body: normalizedData.name || undefined
            }
            break;
        case 'website':
            alert = {
                title: 'Webサイト',
                body: normalizedData.title || normalizedData.url
            }
            break;
    }

    return {
        alert: alert,
        sound: 'Share.wav'
    }
}

const addItemToFirestore = async (item: Item): Promise<any> => {
    const document = {
        creationDate: admin.firestore.FieldValue.serverTimestamp(),
        ...item
    };

    return admin.firestore().collection('items').add(document);
}
