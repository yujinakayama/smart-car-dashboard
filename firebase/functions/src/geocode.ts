import * as functions from 'firebase-functions';

import { Attachments, InputData } from './addItemToInbox/inputData';
import { isGoogleMapsLocation, normalizeGoogleMapsLocation } from './addItemToInbox/googleMaps';


export const geocode = functions.region('asia-northeast1').https.onRequest(async (functionRequest, functionResponse) => {
    const request = functionRequest.body;

    console.log('request:', request);

    const attachments = request.attachments as Attachments;
    const inputData = new InputData(attachments);

    if (!isGoogleMapsLocation(inputData)) {
        functionResponse.sendStatus(400);
        return;
    }

    const location =  await normalizeGoogleMapsLocation(inputData);
    functionResponse.send(location);
});
