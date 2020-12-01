//
//  SharedItemDatabase.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/10/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

protocol SharedItemDatabaseDelegate: NSObjectProtocol {
    func database(_ database: SharedItemDatabase, didUpdateItems items: [SharedItemProtocol], withChanges changes: [SharedItemDatabase.Change])
}

extension Notification.Name {
    static let SharedItemDatabaseDidUpdateItems = Notification.Name("SharedItemDatabaseDidUpdateItems")
}

class SharedItemDatabase: NSObject {
    let vehicleID: String
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

    private lazy var firestoreCollection = Firestore.firestore().collection("vehicles").document(vehicleID).collection("items")
    private var firestoreQuerySnapshotListener: ListenerRegistration?

    let dispatchQueue = DispatchQueue(label: "SharedItemDatabase")

    init(vehicleID: String) {
        self.vehicleID = vehicleID
    }

    deinit {
        endUpdating()
    }

    func startUpdating() {
        guard firestoreQuerySnapshotListener == nil else { return }

        firestoreQuerySnapshotListener = firestoreCollection.order(by: "creationDate", descending: true).addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self else { return }

            if let error = error {
                logger.error(error)
                return
            }

            guard let snapshot = snapshot else { return }

            self.updateItems(from: snapshot)
        }
    }

    func endUpdating() {
        firestoreQuerySnapshotListener?.remove()
        firestoreQuerySnapshotListener = nil
    }

    func findItem(identifier: String, completion: @escaping (SharedItemProtocol?, Error?) -> Void) {
        let document = firestoreCollection.document(identifier)

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

    private func updateItems(from firestoreSnapshot: QuerySnapshot) {
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

        let changes = firestoreSnapshot.documentChanges.map { (documentChange) -> Change in
            var changeType: Change.ChangeType!

            switch documentChange.type {
            case .added:
                changeType = .addition
            case .modified:
                changeType = .modification
            case .removed:
                changeType = .removal
            }

            return Change(type: changeType, oldIndex: Int(documentChange.oldIndex), newIndex: Int(documentChange.newIndex))
        }

        delegate?.database(self, didUpdateItems: items, withChanges: changes)

        NotificationCenter.default.post(name: .SharedItemDatabaseDidUpdateItems, object: self)
    }
}

extension SharedItemDatabase {
    struct Change {
        enum ChangeType {
            case addition
            case modification
            case removal
        }

        let type: ChangeType
        let oldIndex: Int
        let newIndex: Int
    }
}
