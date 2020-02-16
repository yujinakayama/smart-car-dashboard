import * as admin from 'firebase-admin';

import { Item } from './item';
import { NormalizedData } from './normalizedData';

admin.initializeApp();

interface NotificationPayload {
    aps: admin.messaging.Aps;
    foregroundPresentationOptions: UNNotificationPresentationOptions;
    item: Item;
    notificationType: 'share';
}

enum UNNotificationPresentationOptions {
    none = 0,
    badge = 1 << 0,
    sound = 1 << 1,
    alert = 1 << 2
}

export const notify = (item: Item): Promise<any> => {
    const payload = makeNotificationPayload(item);

    const message = {
        topic: 'Dash',
        apns: {
            // admin.messaging.ApnsPayload type requires `object` value for custom keys but it's wrong
            payload: payload as any
        }
    };

    return admin.messaging().send(message);
};

const makeNotificationPayload = (item: Item): NotificationPayload => {
    const normalizedData = item as unknown as NormalizedData;

    let alert: admin.messaging.ApsAlert;
    let foregroundPresentationOptions: UNNotificationPresentationOptions;

    switch (normalizedData.type) {
        case 'location':
            alert = {
                title: '目的地',
                body: normalizedData.name || undefined
            }
            foregroundPresentationOptions = UNNotificationPresentationOptions.sound;
            break;
        case 'musicItem':
            alert = {
                title: '音楽',
                body: normalizedData.title || normalizedData.url
            }
            foregroundPresentationOptions = UNNotificationPresentationOptions.sound | UNNotificationPresentationOptions.alert;
            break;
        case 'website':
            alert = {
                title: 'Webサイト',
                body: normalizedData.title || normalizedData.url
            }
            foregroundPresentationOptions = UNNotificationPresentationOptions.sound;
            break;
    }

    return {
        aps: {
            alert: alert,
            sound: 'Share.wav'
        },
        foregroundPresentationOptions: foregroundPresentationOptions,
        item: item,
        notificationType: 'share'
    };
}
