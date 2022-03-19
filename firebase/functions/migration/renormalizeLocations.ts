import { initializeApp, cert } from 'firebase-admin/app';
import { DocumentData, getFirestore } from 'firebase-admin/firestore';

import { Attachments, InputData } from '../src/addItemToInbox/inputData';
import { Location } from '../src/addItemToInbox/normalizedData';
import { isAppleMapsLocation, normalizeAppleMapsLocation } from '../src/addItemToInbox/appleMaps';
import { isGoogleMapsLocation, normalizeGoogleMapsLocation } from '../src/addItemToInbox/googleMaps';

const serviceAccount = require('./firebase-service-account.json');

initializeApp({
  credential: cert(serviceAccount)
});

const firestore = getFirestore();

async function main() {
  const vehiclesSnapshot = await firestore.collection('vehicles').get();

  // const vehicle = vehiclesSnapshot.docs[0];
  // const vehicleItems = firestore.collection('vehicles').doc(vehicle.id).collection('items').orderBy('creationDate', 'desc');
  // const locationsSnapshot = await vehicleItems.where('type', '==', 'location').get();
  // const location = locationsSnapshot.docs[0];

  for (const vehicle of vehiclesSnapshot.docs) {
    const vehicleItems = firestore.collection('vehicles').doc(vehicle.id).collection('items');
    const locationsSnapshot = await vehicleItems.where('type', '==', 'location').get();

    for (const location of locationsSnapshot.docs) {
      renormalize(location)
    }
  }
}

async function renormalize(document: FirebaseFirestore.QueryDocumentSnapshot<DocumentData>) {
  const data = document.data();

  console.log(`Processing "${data.name}"`);

  const attachments = data.raw as Attachments;
  const inputData = new InputData(attachments);

  try {
    const location = await normalize(inputData);
    await document.ref.update(location);
  } catch (error) {
    if (error instanceof Error) {
      console.error(error.toString());
    } else {
      console.error(error);
    }
  } 
}

function normalize(inputData: InputData): Promise<Location> {
  if (isAppleMapsLocation(inputData)) {
    return normalizeAppleMapsLocation(inputData)
  } else if (isGoogleMapsLocation(inputData)) {
    return normalizeGoogleMapsLocation(inputData);
  } else {
    throw Error();
  }
}

main();
