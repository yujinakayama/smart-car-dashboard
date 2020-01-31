import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as maps from '@google/maps';
import * as https from 'https';
import { URL } from 'url';

interface RawData {
    title?: string;
    contentText?: string;
    'public.url': string;
    'public.plain-text'?: string;
    'com.apple.mapkit.map-item'?: {
        coordinate: {
            latitude: number;
            longitude: number;
        };
        name?: string;
        phoneNumber?: string;
        pointOfInterestCategory?: string;
        url?: string;
    };
}

interface BaseNormalizedData {
    type: string;
    url: string;
}

interface LocationData extends BaseNormalizedData {
    type: 'location';
    coordinate: {
        latitude: number;
        longitude: number;
    };
    name?: string;
    url: string;
    webpageURL?: string;
}

interface WebpageData extends BaseNormalizedData {
    type: 'webpage';
    title?: string;
    url: string;
}

type NormalizedData = LocationData | WebpageData;

// We want to extend NormalizedData but it's not allowed
interface Item extends BaseNormalizedData {
    raw: RawData;
}

admin.initializeApp();

export const notifyAndAddItem = functions.region('asia-northeast1').https.onRequest(async (request, response) => {
    const rawData = request.body as RawData;

    const normalizedData = await normalize(rawData);

    const item = {
        raw: rawData,
        ...normalizedData
    };

    await notify(item);

    await addItemToFirestore(item);

    response.sendStatus(200);
});

const normalize = (rawData: RawData): Promise<NormalizedData> => {
    if (rawData['com.apple.mapkit.map-item']) {
        return normalizeAppleMapsLocation(rawData);
    } else if (rawData['public.url'].startsWith('https://goo.gl/maps/')) {
        return normalizeGoogleMapsLocation(rawData);
    } else {
        return normalizeWebpage(rawData);
    }
};

const normalizeAppleMapsLocation = async (rawData: RawData): Promise<LocationData> => {
    const mapItem = rawData['com.apple.mapkit.map-item']!;

    return {
        type: 'location',
        coordinate: mapItem.coordinate,
        name: mapItem.name,
        webpageURL: mapItem.url,
        url: rawData['public.url']
    };
};

const normalizeGoogleMapsLocation = async (rawData: RawData): Promise<LocationData> => {
    const url: URL = await new Promise((resolve, reject) => {
        https.get(rawData['public.url'], (response) => {
            if (response.headers.location) {
                resolve(new URL(response.headers.location));
            } else {
                reject();
            }
        });
    });

    const query = url.searchParams.get('q');

    if (!query) {
        throw new Error('Missing `q` parameter in Google Maps URL');
    }

    const coordinate = query.match(/^([\d\.]+),([\d\.]+)$/)

    if (coordinate) {
        return {
            type: 'location',
            coordinate: {
                latitude: parseFloat(coordinate[1]),
                longitude: parseFloat(coordinate[2])
            },
            name: rawData['public.plain-text'],
            url: url.toString()
        };
    } else {
        const client = maps.createClient({ key: functions.config().googlemaps.api_key, Promise: Promise });

        const response = await client.findPlace({
            input: query,
            inputtype: 'textquery',
            fields: ['geometry', 'name'],
            language: 'ja'
        }).asPromise();

        const place = response.json.candidates[0]

        if (!place) {
            throw new Error('Found no place from Google Maps URL');
        }

        return {
            type: 'location',
            coordinate: {
                latitude: place.geometry!.location.lat,
                longitude: place.geometry!.location.lng
            },
            name: place.name,
            url: url.toString()
        };
    }
};

const normalizeWebpage = async (rawData: RawData): Promise<WebpageData> => {
    return {
        type: 'webpage',
        title: rawData.title || rawData.contentText,
        url: rawData['public.url']
    };
};

const notify = (item: Item): Promise<any> => {
    const message = {
        topic: 'Dash',
        apns: {
            payload: {
                aps: {
                    sound: 'default'
                },
                // admin.messaging.ApnsPayload type requires `object` value for custom keys but it's wrong
                notificationType: 'item',
                item: item
            } as any
        }
    };

    return admin.messaging().send(message);
};

const addItemToFirestore = async (item: Item): Promise<any> => {
    const document = {
        creationTime: admin.firestore.FieldValue.serverTimestamp(),
        ...item
    };

    return admin.firestore().collection('items').add(document);
}
