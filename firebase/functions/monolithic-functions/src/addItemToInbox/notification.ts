import { InboxItem } from '@dash/inbox'
import { NotificationPayload, UNNotificationPresentationOptions } from '@dash/push-notification'
import * as firebase from 'firebase-admin'

interface ShareNotificationPayload extends NotificationPayload {
  aps: firebase.messaging.Aps
  foregroundPresentationOptions: UNNotificationPresentationOptions
  item: Omit<InboxItem, 'creationDate'>
  documentID: string
  notificationType: 'share'
}

export function makeNotificationPayload(
  item: InboxItem,
  documentID: string,
): ShareNotificationPayload {
  let alert: firebase.messaging.ApsAlert

  switch (item.type) {
    case 'location':
      alert = {
        title: '目的地',
        body: item.name || undefined,
      }
      break
    case 'musicItem': {
      let body: string

      if (item.name) {
        body = [item.name, item.creator].filter((e) => e).join(' - ')
      } else {
        body = item.url
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
        body: item.title || undefined,
      }

      break
    case 'website':
      alert = {
        title: 'Webサイト',
        body: item.title || item.url,
      }
      break
  }

  // TODO: Migrate from Firebase timestamp to plain JS Date
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { creationDate, ...itemWithoutCreationDate } = item

  return {
    aps: {
      alert: alert,
      sound: 'Share.wav',
    },
    foregroundPresentationOptions:
      UNNotificationPresentationOptions.sound | UNNotificationPresentationOptions.alert,
    item: itemWithoutCreationDate,
    documentID,
    notificationType: 'share',
  }
}
