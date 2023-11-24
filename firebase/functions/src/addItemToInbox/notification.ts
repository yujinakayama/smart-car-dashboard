import * as admin from 'firebase-admin'

import { Item } from './item'
import { NormalizedData } from './normalizedData'
import { NotificationPayload, UNNotificationPresentationOptions } from '../notification'

admin.initializeApp()

interface ShareNotificationPayload extends NotificationPayload {
  aps: admin.messaging.Aps
  foregroundPresentationOptions: UNNotificationPresentationOptions
  item: ItemWithIdentifier
  notificationType: 'share'
}

interface ItemWithIdentifier extends Item {
  identifier: string
}

export function makeNotificationPayload(item: Item, identifier: string): ShareNotificationPayload {
  const normalizedData = item as unknown as NormalizedData

  let alert: admin.messaging.ApsAlert

  switch (normalizedData.type) {
    case 'location':
      alert = {
        title: '目的地',
        body: normalizedData.name || undefined,
      }
      break
    case 'musicItem': {
      let body: string

      if (normalizedData.name) {
        body = [normalizedData.name, normalizedData.creator].filter((e) => e).join(' - ')
      } else {
        body = normalizedData.url
      }

      alert = {
        title: '音楽',
        body: body,
      }

      break
    }
    case 'video':
      alert = {
        title: '動画',
        body: normalizedData.title || undefined,
      }

      break
    case 'website':
      alert = {
        title: 'Webサイト',
        body: normalizedData.title || normalizedData.url,
      }
      break
  }

  return {
    aps: {
      alert: alert,
      sound: 'Share.wav',
    },
    foregroundPresentationOptions:
      UNNotificationPresentationOptions.sound | UNNotificationPresentationOptions.alert,
    item: {
      identifier: identifier,
      ...item,
    },
    notificationType: 'share',
  }
}
