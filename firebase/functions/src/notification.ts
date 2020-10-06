import * as admin from 'firebase-admin';

import { Item } from './item';
import { NormalizedData } from './normalizedData';

admin.initializeApp();

interface ItemWithIdentifier extends Item {
    identifier: string;
}

interface NotificationPayload {
    aps: admin.messaging.Aps;
    foregroundPresentationOptions: UNNotificationPresentationOptions;
    item: ItemWithIdentifier;
    notificationType: 'share';
}

enum UNNotificationPresentationOptions {
    none = 0,
    badge = 1 << 0,
    sound = 1 << 1,
    alert = 1 << 2
}

export function notify(item: Item, identifier: string): Promise<any> {
    const payload = makeNotificationPayload(item, identifier);

    const message = {
        topic: 'Dash',
        apns: {
            // admin.messaging.ApnsPayload type requires `object` value for custom keys but it's wrong
            payload: payload as any
        }
    };

    return admin.messaging().send(message);
}

function makeNotificationPayload(item: Item, identifier: string): NotificationPayload {
    const normalizedData = item as unknown as NormalizedData;

    let alert: admin.messaging.ApsAlert;

    switch (normalizedData.type) {
        case 'location':
            alert = {
                title: '目的地',
                body: normalizedData.name || undefined
            }
            break;
        case 'musicItem':
            let body: string;

            if (normalizedData.name) {
                body = [normalizedData.name, normalizedData.creator].filter(e => e).join(' - ');
            } else {
                body = normalizedData.url;
            }

            alert = {
                title: '音楽',
                body: body
            }

            break;
        case 'website':
            alert = {
                title: 'Webサイト',
                body: normalizedData.title || normalizedData.url
            }
            break;
    }

    return {
        aps: {
            alert: alert,
            sound: 'Share.wav'
        },
        foregroundPresentationOptions: UNNotificationPresentationOptions.sound | UNNotificationPresentationOptions.alert,
        item: {
            identifier: identifier,
            ...item
        },
        notificationType: 'share'
    };
}
