//
//  InboxItemDatabase.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/10/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

class InboxItemDatabase: NSObject {
    static let documentDecoder = { (documentSnapshot: DocumentSnapshot) -> InboxItemProtocol? in
        do {
            return try InboxItem.makeItem(document: documentSnapshot)
        } catch {
            logger.error(error)
            return nil
        }
    }

    let vehicleID: String

    private lazy var collection = Firestore.firestore().collection("vehicles").document(vehicleID).collection("items")

    private lazy var query = collection.order(by: "creationDate", descending: true)

    init(vehicleID: String) {
        self.vehicleID = vehicleID
    }

    lazy var allItems = wrappedQuery(query)

    func items(type: InboxItem.ItemType? = nil, hasBeenOpened: Bool? = nil, createdAfter minCreationDate: Date? = nil) -> FirestoreQuery<InboxItemProtocol> {
        var query = query

        if let type = type {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }

        if let hasBeenOpened = hasBeenOpened {
            query = query.whereField("hasBeenOpened", isEqualTo: hasBeenOpened)
        }

        if let minCreationDate = minCreationDate {
            query = query.whereField("creationDate", isGreaterThan: minCreationDate)
        }

        return wrappedQuery(query)
    }

    func item(documentID: String) -> FirestoreDocument<InboxItemProtocol> {
        let document = collection.document(documentID)
        return FirestoreDocument(document, documentDecoder: Self.documentDecoder)
    }

    private func wrappedQuery(_ query: Query) -> FirestoreQuery<InboxItemProtocol> {
        return FirestoreQuery(query, documentDecoder: Self.documentDecoder)
    }
}
