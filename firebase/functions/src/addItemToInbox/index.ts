import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

import { Request, InputData } from './inputData';
import { NormalizedData } from './normalizedData';
import { Item } from './item';
import { isAppleMapsLocation, normalizeAppleMapsLocation } from './appleMaps';
import { isGoogleMapsLocation, normalizeGoogleMapsLocation } from './googleMaps';
import { isAppleMusicItem, normalizeAppleMusicItem } from './appleMusic';
import { isYouTubeVideo, normalizeYouTubeVideo } from './youtube';
import { normalizeWebpage } from './website';
import { notify } from './notification';

export const addItemToInbox = functions.region('asia-northeast1').https.onRequest(async (functionRequest, functionResponse) => {
    if (functionRequest.method === 'GET') {
        await warmUpFirestore();
        functionResponse.sendStatus(200);
        return;
    }

    const request = functionRequest.body as Request;

    console.log('request:', request);

    const attachments = request.attachments || request.item || {};
    const inputData = new InputData(attachments);
    const normalizedData = await normalize(inputData);

    console.log('normalizedData:', normalizedData);

    const item = {
        hasBeenOpened: false,
        raw: attachments,
        ...normalizedData
    };

    // Create a Firestore document without network access to get document identifier
    // https://github.com/googleapis/nodejs-firestore/blob/v3.8.6/dev/src/reference.ts#L2414-L2479
    const document = admin.firestore().collection('vehicles').doc(request.vehicleID).collection('items').doc();

    await Promise.all([
        notify(request.vehicleID, item, document.id),
        addItemToFirestore(item, document)
    ]);

    functionResponse.sendStatus(200);
});

function warmUpFirestore(): Promise<any> {
    // Initial call to Firestore client takes about 5 seconds,
    // so we warm up the client every 2 minutes.
    // https://github.com/firebase/firebase-functions/issues/263#issuecomment-397129178
    return admin.firestore().collection('health').get();
}

function normalize(inputData: InputData): Promise<NormalizedData> {
    if (isAppleMapsLocation(inputData)) {
        return normalizeAppleMapsLocation(inputData);
    } else if (isGoogleMapsLocation(inputData)) {
        return normalizeGoogleMapsLocation(inputData);
    } else if (isAppleMusicItem(inputData)) {
        return normalizeAppleMusicItem(inputData);
    } else if (isYouTubeVideo(inputData)) {
        return normalizeYouTubeVideo(inputData);
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
