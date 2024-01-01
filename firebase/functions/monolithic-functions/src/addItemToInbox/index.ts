import { onRequest } from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'

import { Request, InputData } from './inputData'
import { NormalizedData } from './normalizedData'
import { Item } from './item'
import { isAppleMapsLocation, normalizeAppleMapsLocation } from './appleMaps'
import {
  isGoogleMapsLocation,
  normalizeGoogleMapsLocation,
  requiredEnvName as googleMapsRequiredEnvName,
} from './googleMaps'
import {
  isAppleMusicItem,
  normalizeAppleMusicItem,
  requiredEnvNames as appleMusicRequiredEnvName,
} from './appleMusic'
import {
  isYouTubeVideo,
  normalizeYouTubeVideo,
  requiredEnvName as youtubeRequiredEnvName,
} from './youtube'
import { normalizeWebpage } from './website'
import { makeNotificationPayload } from './notification'
import { sendNotificationToVehicle } from '../notification'

const requiredSecrets = Array.from(
  new Set([googleMapsRequiredEnvName, appleMusicRequiredEnvName, youtubeRequiredEnvName].flat()),
)

export const addItemToInbox = onRequest(
  {
    region: 'asia-northeast1',
    secrets: requiredSecrets,
    minInstances: 1,
  },
  async (functionRequest, functionResponse) => {
    const request = functionRequest.body as Request

    console.log('request:', request)

    const inputData = new InputData(request.attachments)
    const normalizedData = await normalize(inputData)

    console.log('normalizedData:', normalizedData)

    const item = {
      hasBeenOpened: false,
      raw: request.attachments,
      ...normalizedData,
    }

    // Create a Firestore document without network access to get document identifier
    // https://github.com/googleapis/nodejs-firestore/blob/v3.8.6/dev/src/reference.ts#L2414-L2479
    const document = admin
      .firestore()
      .collection('vehicles')
      .doc(request.vehicleID)
      .collection('items')
      .doc()

    const promises = [addItemToFirestore(item, document)]
    if (request.notification !== false) {
      const payload = makeNotificationPayload(item, document.id)
      promises.push(sendNotificationToVehicle(request.vehicleID, payload))
    }
    await Promise.all(promises)

    functionResponse.sendStatus(200)
  },
)

async function normalize(inputData: InputData): Promise<NormalizedData> {
  if (isAppleMapsLocation(inputData)) {
    return normalizeAppleMapsLocation(inputData)
  } else if (await isGoogleMapsLocation(inputData)) {
    return normalizeGoogleMapsLocation(inputData)
  } else if (isAppleMusicItem(inputData)) {
    return normalizeAppleMusicItem(inputData)
  } else if (await isYouTubeVideo(inputData)) {
    return normalizeYouTubeVideo(inputData)
  } else {
    return normalizeWebpage(inputData)
  }
}

async function addItemToFirestore(
  item: Item,
  document: FirebaseFirestore.DocumentReference,
): Promise<admin.firestore.WriteResult> {
  const data = {
    creationDate: admin.firestore.FieldValue.serverTimestamp(),
    ...item,
  }

  return document.create(data)
}
