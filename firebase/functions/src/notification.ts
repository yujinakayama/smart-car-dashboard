import { messaging } from 'firebase-admin'

export function sendNotificationToVehicle(vehicleID: string, payload: NotificationPayload): Promise<any> {
    const message = {
        topic: vehicleID,
        apns: {
            payload: payload
        }
    }

    return messaging().send(message)
}

export interface NotificationPayload {
    aps: messaging.Aps;
    foregroundPresentationOptions: UNNotificationPresentationOptions;
    notificationType: string;
}

export enum UNNotificationPresentationOptions {
    none = 0,
    badge = 1 << 0,
    sound = 1 << 1,
    alert = 1 << 2
}
