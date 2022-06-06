import * as functions from 'firebase-functions'
import * as admin from 'firebase-admin'

export const createVehicle = functions.region('asia-northeast1').auth.user().onCreate(async (user) => {
    const document = admin.firestore().collection('vehicles').doc(user.uid)
    await document.create({ email: user.email })
})

export const deleteVehicle = functions.region('asia-northeast1').auth.user().onDelete(async (user) => {
    await admin.firestore().collection('vehicles').doc(user.uid).delete
})
