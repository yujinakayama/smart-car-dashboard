import { initializeApp, cert } from 'firebase-admin/app';
import { DocumentData, getFirestore } from 'firebase-admin/firestore';

import { Attachments, InputData } from '../src/addItemToInbox/inputData';
import { isYouTubeVideo, normalizeYouTubeVideo } from '../src/addItemToInbox/youtube';

const serviceAccount = require('./firebase-service-account.json');

initializeApp({
  credential: cert(serviceAccount)
});

const firestore = getFirestore();

async function main() {
  const vehiclesSnapshot = await firestore.collection('vehicles').get();

  for (const vehicle of vehiclesSnapshot.docs) {
    const vehicleItems = firestore.collection('vehicles').doc(vehicle.id).collection('items');
    const videoSnapshot = await vehicleItems.where('type', '==', 'video').get();

    for (const video of videoSnapshot.docs) {
      renormalize(video)
    }
  }
}

async function renormalize(document: FirebaseFirestore.QueryDocumentSnapshot<DocumentData>) {
  const data = document.data();

  console.log(`Processing "${data.title}"`);

  const attachments = data.raw as Attachments;
  const inputData = new InputData(attachments);

  if (!isYouTubeVideo(inputData)) {
    return
  }

  try {
    const video = await normalizeYouTubeVideo(inputData);
    await document.ref.update(video);
  } catch (error) {
    if (error instanceof Error) {
      console.error(error.toString());
    } else {
      console.error(error);
    }
  } 
}

main();
