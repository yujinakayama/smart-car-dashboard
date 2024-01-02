import * as firebase from 'firebase-admin'
import * as functions from 'firebase-functions/v1'

// Note: Cloud Functions for Firebase (2nd gen) does not provide support for the events and triggers described in this guide.
// Because 1st gen and 2nd gen functions can coexist side-by-side in the same source file,
// you can still develop and deploy this functionality together with 2nd gen functions.
// https://firebase.google.com/docs/functions/auth-events

export const createVehicle = functions
  .region('asia-northeast1')
  .auth.user()
  .onCreate(async (user) => {
    const document = firebase.firestore().collection('vehicles').doc(user.uid)
    await document.create({ email: user.email })
  })

export const deleteVehicle = functions
  .region('asia-northeast1')
  .auth.user()
  .onDelete(async (user) => {
    await firebase.firestore().collection('vehicles').doc(user.uid).delete
  })
