import {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
  Timestamp,
  WithFieldValue,
} from '@google-cloud/firestore'

import { Attachments } from './attachments'
import { Item } from './item'

// An item persisted in the inbox
export type InboxItem = Item & {
  creationDate: Timestamp
  hasBeenOpened: boolean
  raw: Attachments
}

export const firestoreInboxItemConverter: FirestoreDataConverter<InboxItem> = {
  toFirestore: (item: WithFieldValue<InboxItem>): WithFieldValue<DocumentData> => {
    return item
  },
  fromFirestore: (document: QueryDocumentSnapshot): InboxItem => {
    return document.data() as InboxItem
  },
}
