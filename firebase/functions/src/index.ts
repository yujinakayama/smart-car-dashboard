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
    iconURL: string | null;
    title?: string;
    url: string;
}

type NormalizedData = LocationData | WebpageData;

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
        coordinate: mapItem.coordinate,
        name: mapItem.name,
        webpageURL: mapItem.url,
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

    const query = expandedURL.searchParams.get('q');

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
            url: expandedURL.toString()
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
            url: expandedURL.toString()
        };
    }
};

const normalizeWebpage = async (rawData: RawData, url: string): Promise<WebpageData> => {
    const responseBody = await request.get(url);
    const document = libxmljs.parseHtml(responseBody);

    const title = document.get('//head/title')?.text().trim() || rawData['public.plain-text'];

    return {
        type: 'webpage',
        iconURL: getIconURL(document, url),
        title: title,
        url: url
    };
};

const getIconURL = (document: libxmljs.Document, pageURL: string): string | null => {
    const icons = document.find('//head/link[(@rel="apple-touch-icon" or @rel="apple-touch-icon-precomposed" or @rel="icon") and @href]').map((link) => {
        let url = link.attr('href')!.value();

        if (url) {
            url = new URL(url, pageURL).toString();
        }

        let size = link.attr('sizes')?.value().split('x')[0];

        return {
            url: url,
            size: size ? parseInt(size) : undefined
        }
    });

    if (icons.length == 0) {
        return null;
    }

    const icon = icons.reduce((best, current) => {
        if (!current.size || !best.size) {
            return best;
        }

        return current.size > best.size ? current : best;
    });

    return icon.url;
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
                body: normalizedData.name
            }
            break;
        case 'webpage':
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
