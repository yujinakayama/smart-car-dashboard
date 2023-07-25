import { onRequest } from 'firebase-functions/v2/https'

import { Attachments, InputData } from './addItemToInbox/inputData'
import { isGoogleMapsLocation, normalizeGoogleMapsLocation } from './addItemToInbox/googleMaps'


export const geocode = onRequest({ region: 'asia-northeast1' }, async (functionRequest, functionResponse) => {
    const request = functionRequest.body

    console.log('request:', request)

    const attachments = request.attachments as Attachments
    const inputData = new InputData(attachments)

    if (!isGoogleMapsLocation(inputData)) {
        functionResponse.sendStatus(400)
        return
    }

    const location =  await normalizeGoogleMapsLocation(inputData)
    functionResponse.send(location)
})
