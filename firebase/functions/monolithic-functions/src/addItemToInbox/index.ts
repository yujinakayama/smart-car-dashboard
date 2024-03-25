import { InboxItem, Item, firestoreInboxItemConverter } from '@dash/inbox'
import { sendNotificationToVehicle } from '@dash/push-notification'
import { Timestamp } from '@google-cloud/firestore'
// Destructured imports are not supported in firebase-admin
// https://github.com/firebase/firebase-admin-node/issues/593#issuecomment-917173625
import * as firebase from 'firebase-admin'
import { initializeApp } from 'firebase-admin/app'
import { onRequest } from 'firebase-functions/v2/https'

import {
  isAppleMapsLocation,
  normalizeAppleMapsLocation,
  requiredEnvName as appleMapsRequiredEnvName,
} from './appleMaps'
import {
  isAppleMusicItem,
  normalizeAppleMusicItem,
  requiredEnvNames as appleMusicRequiredEnvNames,
} from './appleMusic'
import {
  isGoogleMapsLocation,
  normalizeGoogleMapsLocation,
  requiredEnvName as googleMapsRequiredEnvName,
} from './googleMaps'
import { Request, InputData } from './inputData'
import { makeNotificationPayload } from './notification'
import { normalizeWebpage } from './website'
import {
  isYouTubeVideo,
  normalizeYouTubeVideo,
  requiredEnvName as youtubeRequiredEnvName,
} from './youtube'

initializeApp()

const requiredSecrets = Array.from(
  new Set(
    [
      appleMapsRequiredEnvName,
      googleMapsRequiredEnvName,
      appleMusicRequiredEnvNames,
      youtubeRequiredEnvName,
    ].flat(),
  ),
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
    const item = await normalize(inputData)

    console.log('item:', item)

    const inboxItem: InboxItem = {
      creationDate: Timestamp.now(),
      hasBeenOpened: false,
      raw: request.attachments,
      ...item,
    }

    // Create a Firestore document without network access to get document identifier
    // https://github.com/googleapis/nodejs-firestore/blob/v3.8.6/dev/src/reference.ts#L2414-L2479
    const document = firebase
      .firestore()
      .collection('vehicles')
      .doc(request.vehicleID)
      .collection('items')
      .doc()

    const promises = [document.withConverter(firestoreInboxItemConverter).create(inboxItem)]
    if (request.notification !== false) {
      const payload = makeNotificationPayload(item, document.id)
      promises.push(sendNotificationToVehicle(request.vehicleID, payload))
    }
    await Promise.all(promises)

    functionResponse.sendStatus(200)
  },
)

async function normalize(inputData: InputData): Promise<Item> {
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
