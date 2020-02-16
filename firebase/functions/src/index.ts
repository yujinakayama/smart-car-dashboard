import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

import { RawData, extractURL } from './rawData';
import { NormalizedData } from './normalizedData';
import { Item } from './item';
import { normalizeAppleMapsLocation } from './appleMaps';
import { normalizeGoogleMapsLocation } from './googleMaps';
import { normalizeAppleMusicItem } from './appleMusic';
import { normalizeWebpage } from './website';
import { notify } from './notification';

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
    } else if (url.startsWith('https://music.apple.com/')) {
        return normalizeAppleMusicItem(rawData, url);
    } else {
        return normalizeWebpage(rawData, url);
    }
};

const addItemToFirestore = async (item: Item): Promise<any> => {
    const document = {
        creationDate: admin.firestore.FieldValue.serverTimestamp(),
        ...item
    };

    return admin.firestore().collection('items').add(document);
}
