import { Attachments } from '@dash/inbox'
import { onRequest } from 'firebase-functions/v2/https'

import {
  isGoogleMapsLocation,
  normalizeGoogleMapsLocation,
  requiredEnvName,
} from './addItemToInbox/googleMaps'
import { InputData } from './addItemToInbox/inputData'

export const geocode = onRequest(
  {
    region: 'asia-northeast1',
    secrets: [requiredEnvName],
  },
  async (functionRequest, functionResponse) => {
    const request = functionRequest.body

    console.log('request:', request)

    const attachments = request.attachments as Attachments
    const inputData = new InputData(attachments)

    if (!(await isGoogleMapsLocation(inputData))) {
      functionResponse.sendStatus(400)
      return
    }

    const location = await normalizeGoogleMapsLocation(inputData)
    functionResponse.send(location)
  },
)
