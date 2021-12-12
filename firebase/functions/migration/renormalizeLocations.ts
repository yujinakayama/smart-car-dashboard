import { initializeApp, cert } from 'firebase-admin/app';
import { DocumentData, FieldValue, getFirestore } from 'firebase-admin/firestore';

import { Attachments, InputData } from '../src/share/inputData';
import { Location } from '../src/share/normalizedData';
import { isAppleMapsLocation, normalizeAppleMapsLocation } from '../src/share/appleMaps';
import { isGoogleMapsLocation, normalizeGoogleMapsLocation } from '../src/share/googleMaps';

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
    console.log(error.message);
    document.ref.update({ categories: [] });
  }

  document.ref.update({ category: FieldValue.delete() });
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
