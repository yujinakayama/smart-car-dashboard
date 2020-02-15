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
    coordinate: {
        latitude: number;
        longitude: number;
    };
    name: string | null;
    websiteURL: string | null;
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

    locationData = normalizeGoogleMapsLocationWithCoordinate(rawData, expandedURL);
    if (locationData) {
        return locationData;
    }

    locationData = await normalizeGoogleMapsLocationWithFtid(rawData, expandedURL);
    if (locationData) {
        return locationData;
    }

    locationData = await normalizeGoogleMapsLocationWithQuery(rawData, expandedURL);
    if (locationData) {
        return locationData;
    }

    throw new Error('Cannot find details for the Google Maps URL');
};

// No address location (e.g. Dropped pin)
const normalizeGoogleMapsLocationWithCoordinate = (rawData: RawData, expandedURL: URL): LocationData | null => {
    const query = expandedURL.searchParams.get('q');

    if (!query) {
        return null;
    }

    const coordinate = query.match(/^([\d\.]+),([\d\.]+)$/)

    if (!coordinate) {
        return null;
    }

    return {
        type: 'location',
        coordinate: {
            latitude: parseFloat(coordinate[1]),
            longitude: parseFloat(coordinate[2])
        },
        name: rawData['public.plain-text'] || null,
        url: expandedURL.toString(),
        websiteURL: null
    };
};

// Point of Interests
// https://stackoverflow.com/a/47042514/784241
const normalizeGoogleMapsLocationWithFtid = async (rawData: RawData, expandedURL: URL): Promise<LocationData | null> => {
    const ftid = expandedURL.searchParams.get('ftid');

    if (!ftid) {
        return null;
    }
    
    const requestParameters: maps.PlaceDetailsRequest = {
        placeid: '',
        fields: ['geometry', 'name', 'website'],
        language: 'ja'
    }

    // @ts-ignore
    const response = await googleMapsClient.place(requestParameters, null, { ftid: ftid }).asPromise();

    const place = response.json.result;

    return {
        type: 'location',
        coordinate: {
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        },
        name: place.name,
        url: expandedURL.toString(),
        websiteURL: place.website
    };
};

// Last resort
const normalizeGoogleMapsLocationWithQuery = async (rawData: RawData, expandedURL: URL): Promise<LocationData | null> => {
    const query = expandedURL.searchParams.get('q');

    if (!query) {
        return null;
    }

    const response = await googleMapsClient.findPlace({
        input: query,
        inputtype: 'textquery',
        fields: ['geometry', 'name'],
        language: 'ja'
    }).asPromise();

    const place = response.json.candidates[0]

    if (!place) {
        return null;
    }

    return {
        type: 'location',
        coordinate: {
            latitude: place.geometry!.location.lat,
            longitude: place.geometry!.location.lng
        },
        name: place.name || null,
        url: expandedURL.toString(),
        websiteURL: null
    };
};

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
