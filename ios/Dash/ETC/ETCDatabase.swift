//
//  ETCDataStore.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/12.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

enum ETCDataStoreError: Error {
    case currentCardMustBeSet
}

class ETCDatabase: NSObject {
    let vehicleID: String

    private lazy var vehicleDocument = Firestore.firestore().collection("vehicles").document(vehicleID)

    private lazy var cardCollection = vehicleDocument.collection("etcCards")
    private lazy var cardsQuery = cardCollection.order(by: "name")

    private lazy var paymentCollection = vehicleDocument.collection("etcPayments")
    private lazy var paymentsQuery = paymentCollection.order(by: "exitDate", descending: true)

    init(vehicleID: String) {
        self.vehicleID = vehicleID
    }

    func hasSaved(_ payment: ETCPayment) async throws -> Bool {
        let query = paymentCollection.whereField("exitDate", isEqualTo: payment.exitDate).limit(to: 1)
        let snapshot = try await query.getDocuments()
        return snapshot.count > 0
    }

    func save(_ payment: ETCPayment, for card: ETCCard) throws {
        guard let cardDocumentReference = card.documentReference else {
            throw ETCDatabaseError.missingCardDocumentReference
        }

        var dictionary = try Firestore.Encoder().encode(payment)
        dictionary["card"] = cardDocumentReference
        paymentCollection.document().setData(dictionary)
    }

    func findCard(uuid: UUID) async throws -> ETCCard? {
        let reference = cardDocumentReference(uuid: uuid)
        return try await reference.getDocument().data(as: ETCCard.self)
    }

    func findOrCreateCard(uuid: UUID) async throws -> ETCCard {
        let reference = cardDocumentReference(uuid: uuid)

        if let card = try await reference.getDocument().data(as: ETCCard.self) {
            return card
        } else {
            var card = ETCCard(uuid: uuid)
            try reference.setData(from: card)
            card.documentReference = reference
            return card
        }
    }

    lazy var allCards = FirestoreQuery<ETCCard>(cardsQuery)

    lazy var allPayments = FirestoreQuery<ETCPayment>(paymentsQuery)

    func payments(for card: ETCCard) throws -> FirestoreQuery<ETCPayment> {
        guard let cardDocumentReference = card.documentReference else {
            throw ETCDatabaseError.missingCardDocumentReference
        }

        let query = paymentsQuery.whereField("card", isEqualTo: cardDocumentReference)
        return FirestoreQuery<ETCPayment>(query)
    }

    private func cardDocumentReference(uuid: UUID) -> DocumentReference {
        return cardCollection.document(uuid.uuidString)
    }
}

enum ETCDatabaseError: Error {
    case missingCardDocumentReference
}
