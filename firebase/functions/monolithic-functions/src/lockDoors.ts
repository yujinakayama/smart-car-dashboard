import { onRequest } from 'firebase-functions/v2/https'
import {
  NotificationPayload,
  UNNotificationPresentationOptions,
  sendNotificationToVehicle,
} from './notification'

interface Request {
  vehicleID: string
}

export const lockDoors = onRequest(
  {
    region: 'asia-northeast1',
  },
  async (functionRequest, functionResponse) => {
    const request = functionRequest.body as Request
    sendNotificationToVehicle(request.vehicleID, makeNotificationPayload())
    functionResponse.sendStatus(200)
  },
)

function makeNotificationPayload(): NotificationPayload {
  return {
    aps: {
      alert: {
        body: 'Dash Remoteからドアをロック中…',
      },
      sound: 'default',
      mutableContent: true,
    },
    foregroundPresentationOptions:
      UNNotificationPresentationOptions.sound | UNNotificationPresentationOptions.alert,
    notificationType: 'lockDoors',
  }
}
