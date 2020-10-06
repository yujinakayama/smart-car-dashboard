import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

import { RawInputData, InputData } from './inputData';
import { NormalizedData } from './normalizedData';
import { Item } from './item';
import { isAppleMapsLocation, normalizeAppleMapsLocation } from './appleMaps';
import { isGoogleMapsLocation, normalizeGoogleMapsLocation } from './googleMaps';
import { isAppleMusicItem, normalizeAppleMusicItem } from './appleMusic';
import { normalizeWebpage } from './website';
import { notify } from './notification';

export const share = functions.region('asia-northeast1').https.onRequest(async (functionRequest, functionResponse) => {
    const rawData = functionRequest.body as RawInputData;
    const inputData = new InputData(rawData);

    console.log('rawData:', rawData);

    const normalizedData = await normalize(inputData);

    console.log('normalizedData:', normalizedData);

    const item = {
        hasBeenOpened: false,
        raw: rawData,
        ...normalizedData
    };

    // Create a Firestore document without network access to get document identifier
    // https://github.com/googleapis/nodejs-firestore/blob/v3.8.6/dev/src/reference.ts#L2414-L2479
    const document = admin.firestore().collection('items').doc();

    await Promise.all([
        notify(item, document.id),
        addItemToFirestore(item, document)
    ]);

    functionResponse.sendStatus(200);
});

function normalize(inputData: InputData): Promise<NormalizedData> {
    if (isAppleMapsLocation(inputData)) {
        return normalizeAppleMapsLocation(inputData);
    } else if (isGoogleMapsLocation(inputData)) {
        return normalizeGoogleMapsLocation(inputData);
    } else if (isAppleMusicItem(inputData)) {
        return normalizeAppleMusicItem(inputData);
    } else {
        return normalizeWebpage(inputData);
    }
};

async function addItemToFirestore(item: Item, document: FirebaseFirestore.DocumentReference): Promise<any> {
    const data = {
        creationDate: admin.firestore.FieldValue.serverTimestamp(),
        ...item
    };

    return document.create(data);
}
