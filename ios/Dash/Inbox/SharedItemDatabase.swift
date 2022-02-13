//
//  SharedItemDatabase.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/10/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

class SharedItemDatabase: NSObject {
    let vehicleID: String

    private lazy var collection = Firestore.firestore().collection("vehicles").document(vehicleID).collection("items")

    private lazy var query = collection.order(by: "creationDate", descending: true)

    init(vehicleID: String) {
        self.vehicleID = vehicleID
    }

    func findItem(identifier: String, completion: @escaping (SharedItemProtocol?, Error?) -> Void) {
        let document = collection.document(identifier)

        document.getDocument { (snapshot, error) in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let snapshot = snapshot, snapshot.exists else {
                completion(nil, nil)
                return
            }

            do {
                let item = try SharedItem.makeItem(document: snapshot)
                completion(item, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    lazy var allItems = wrappedQuery(query)

    func items(type: SharedItem.ItemType? = nil, hasBeenOpened: Bool? = nil, createdAfter minCreationDate: Date? = nil) -> FirestoreQuery<SharedItemProtocol> {
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

    private func wrappedQuery(_ query: Query) -> FirestoreQuery<SharedItemProtocol> {
        return FirestoreQuery(
            query,
            documentDecoder: { (documentSnapshot) in
                do {
                    return try SharedItem.makeItem(document: documentSnapshot)
                } catch {
                    logger.error(error)
                    return nil
                }
            }
        )
    }
}
