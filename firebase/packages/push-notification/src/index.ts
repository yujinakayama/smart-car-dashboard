import * as firebase from 'firebase-admin'
import { initializeApp } from 'firebase-admin/app'

initializeApp()

export function sendNotificationToVehicle(
  vehicleID: string,
  payload: NotificationPayload,
): Promise<any> {
  const message = {
    topic: vehicleID,
    apns: {
      payload: payload,
    },
  }

  return firebase.messaging().send(message)
}

export interface NotificationPayload {
  aps: firebase.messaging.Aps
  foregroundPresentationOptions: UNNotificationPresentationOptions
  notificationType: string
}

export enum UNNotificationPresentationOptions {
  none = 0,
  badge = 1 << 0,
  sound = 1 << 1,
  alert = 1 << 2,
}
