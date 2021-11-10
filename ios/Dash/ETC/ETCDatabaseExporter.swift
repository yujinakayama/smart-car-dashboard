//
//  ETCDatabaseMigration.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/11/09.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore
import CoreData

class ETCDatabaseExporter {
    let coreDataContext: NSManagedObjectContext
    let firestoreVehicleID: String

    lazy var firestoreVehicleDocument = Firestore.firestore().collection("vehicles").document(firestoreVehicleID)

    init(coreDataContext: NSManagedObjectContext, firestoreVehicleID: String) {
        self.coreDataContext = coreDataContext
        self.firestoreVehicleID = firestoreVehicleID
    }

    func run() {
        exportCards()
        exportPayments()
    }

    func exportCards() {
        for coreDataCard in coreDataCards {
            firestoreCardCollection.document(coreDataCard.uuid.uuidString).setData([
                "name": coreDataCard.name as Any,
                "brand": coreDataCard.brand.rawValue
            ])
        }
    }

    lazy var coreDataCards: [ETCCardManagedObject] = {
        let request = ETCCardManagedObject.fetchRequest()
        return try! coreDataContext.fetch(request)
    }()

    lazy var firestoreCardCollection = firestoreVehicleDocument.collection("etcCards")

    func exportPayments() {
        for coreDataPayment in coreDataPayments {
            let firestoreCardReference = firestoreCardCollection.document(coreDataPayment.card!.uuid.uuidString)

            firestorePaymentCollection.addDocument(data: [
                "amount": coreDataPayment.amount,
                "exitDate": coreDataPayment.date,
                "entranceTollboothID": coreDataPayment.entranceTollboothID,
                "exitTollboothID": coreDataPayment.entranceTollboothID,
                "vehicleClassification": coreDataPayment.vehicleClassification.rawValue,
                "card": firestoreCardReference
            ])
        }
    }

    lazy var coreDataPayments: [ETCPaymentManagedObject] = {
        let request = ETCPaymentManagedObject.fetchRequest()
        return try! coreDataContext.fetch(request)
    }()

    lazy var firestorePaymentCollection = firestoreVehicleDocument.collection("etcPayments")
}
