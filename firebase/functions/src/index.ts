import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const notify = functions.firestore.document('items/{itemId}').onCreate(async (snapshot, context) => {
    const item = snapshot.data();

    if (!item) {
        return;
    }

    const message = {
        topic: 'Dash',
        notification: {
            body: item.url
        },
        apns: {
            payload: {
                aps: {
                    sound: 'default'
                }
            }
        }
    };

    await admin.messaging().send(message);
});
