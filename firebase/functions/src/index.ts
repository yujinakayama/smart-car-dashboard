import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as maps from '@google/maps';
import * as https from 'https';
import { URL } from 'url';

import { DocumentSnapshot } from 'firebase-functions/lib/providers/firestore';

interface RawData {
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

admin.initializeApp();

export const normalizeItemAndNotify = functions.region('asia-northeast1').firestore.document('items/{itemId}').onCreate(async (snapshot, context) => {
    await normalize(snapshot);
    await notify(snapshot.ref);
});

const normalize = (snapshot: DocumentSnapshot): Promise<any> => {
    const document = snapshot.ref;
    const rawData = snapshot.get('raw') as RawData;

    if (rawData['com.apple.mapkit.map-item']) {
        return normalizeAppleMapsLocation(document, rawData);
    } else if (rawData['public.url'].startsWith('https://goo.gl/maps/')) {
        return normalizeGoogleMapsLocation(document, rawData);
    } else {
        return normalizeWebpage(document, rawData);
    }
};

const normalizeAppleMapsLocation = (document: FirebaseFirestore.DocumentReference, rawData: RawData): Promise<any> => {
    const mapItem = rawData['com.apple.mapkit.map-item']!;

    return document.update({
        type: 'location',
        coordinate: mapItem.coordinate,
        name: mapItem.name,
        webpageURL: mapItem.url,
        url: rawData['public.url']
    });
};

const normalizeGoogleMapsLocation = async (document: FirebaseFirestore.DocumentReference, rawData: RawData): Promise<any> => {
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
        return document.update({
            type: 'location',
            coordinate: {
                latitude: parseFloat(coordinate[1]),
                longitude: parseFloat(coordinate[2])
            },
            name: rawData['public.plain-text'],
            url: rawData['public.url']
        });
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

        return document.update({
            type: 'location',
            coordinate: {
                latitude: place.geometry?.location.lat,
                longitude: place.geometry?.location.lng
            },
            name: place.name,
            url: rawData['public.url']
        });
    }
};

const normalizeWebpage = (document: FirebaseFirestore.DocumentReference, rawData: RawData): Promise<any> => {
    return document.update({
        type: 'webpage',
        url: rawData['public.url']
    });
};

const notify = async (document: FirebaseFirestore.DocumentReference): Promise<any> => {
    const snapshot = await document.get();

    const message = {
        topic: 'Dash',
        apns: {
            payload: {
                aps: {
                    sound: 'default'
                },
                // admin.messaging.ApnsPayload type requires `object` value for custom keys but it's wrong
                notificationType: 'item',
                item: snapshot.data()
            } as any
        }
    };

    return admin.messaging().send(message);
};
