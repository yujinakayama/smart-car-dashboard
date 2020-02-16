import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

import { RawInputData, InputData } from './inputData';
import { NormalizedData } from './normalizedData';
import { Item } from './item';
import { normalizeAppleMapsLocation } from './appleMaps';
import { normalizeGoogleMapsLocation } from './googleMaps';
import { normalizeAppleMusicItem } from './appleMusic';
import { normalizeWebpage } from './website';
import { notify } from './notification';

export const share = functions.region('asia-northeast1').https.onRequest(async (functionRequest, functionResponse) => {
    const rawData = functionRequest.body as RawInputData;
    const inputData = new InputData(rawData);

    console.log('rawData:', rawData);

    const normalizedData = await normalize(inputData);

    console.log('normalizedData:', normalizedData);

    const item = {
        raw: rawData,
        ...normalizedData
    };

    await notify(item);

    await addItemToFirestore(item);

    functionResponse.sendStatus(200);
});

function normalize(inputData: InputData): Promise<NormalizedData> {
    if (inputData.rawData['com.apple.mapkit.map-item']) {
        return normalizeAppleMapsLocation(inputData);
    } else if (inputData.url.toString().startsWith('https://goo.gl/maps/')) {
        return normalizeGoogleMapsLocation(inputData);
    } else if (inputData.url.toString().startsWith('https://music.apple.com/')) {
        return normalizeAppleMusicItem(inputData);
    } else {
        return normalizeWebpage(inputData);
    }
};

async function addItemToFirestore(item: Item): Promise<any> {
    const document = {
        creationDate: admin.firestore.FieldValue.serverTimestamp(),
        ...item
    };

    return admin.firestore().collection('items').add(document);
}
