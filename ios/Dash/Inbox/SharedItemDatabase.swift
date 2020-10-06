//
//  SharedItemDatabase.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/10/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

protocol SharedItemDatabaseDelegate: NSObjectProtocol {
    func database(_ database: SharedItemDatabase, didUpdateItems items: [SharedItemProtocol])
}

class SharedItemDatabase {
    weak var delegate: SharedItemDatabaseDelegate?

    var items: [SharedItemProtocol] {
        get {
            return dispatchQueue.sync {
                return _items
            }
        }

        set {
            dispatchQueue.sync {
                _items = newValue
            }
        }
    }

    private var _items: [SharedItemProtocol] = []

    private lazy var firestoreQuery: Query = Firestore.firestore().collection("items").order(by: "creationDate", descending: true)
    private var firestoreQuerySnapshotListener: ListenerRegistration?

    let dispatchQueue = DispatchQueue(label: "SharedItemDatabase")

    func startUpdating() {
        guard firestoreQuerySnapshotListener == nil else { return }

        firestoreQuerySnapshotListener = firestoreQuery.addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self else { return }

            if let error = error {
                logger.error(error)
                return
            }

            guard let snapshot = snapshot else { return }

            self.updateItem(from: snapshot)
        }
    }

    func endUpdating() {
        firestoreQuerySnapshotListener?.remove()
        firestoreQuerySnapshotListener = nil
    }

    private func updateItem(from firestoreSnapshot: QuerySnapshot) {
        items = firestoreSnapshot.documents.compactMap({ (document) in
            do {
                var item = try SharedItem.makeItem(document: document)
                item.firebaseDocument = document.reference
                return item
            } catch {
                logger.error(error)
                return nil
            }
        })

        delegate?.database(self, didUpdateItems: items)
    }
}
