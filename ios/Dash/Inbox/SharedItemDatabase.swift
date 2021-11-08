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
    func database(_ database: SharedItemDatabase, didUpdateItems update: SharedItemDatabase.Update)
}

extension Notification.Name {
    static let SharedItemDatabaseDidUpdateItems = Notification.Name("SharedItemDatabaseDidUpdateItems")
}

class SharedItemDatabase: NSObject {
    static let updateUserInfoKey = "updateUserInfoKey"

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

    private lazy var collection = Firestore.firestore().collection("vehicles").document(vehicleID).collection("items")

    private lazy var query = collection.order(by: "creationDate", descending: true)

    private lazy var queryPagination = FirestoreQueryPagination(query: query, documentCountPerPage: 20) { [weak self] (result) in
        self?.handleUpdate(result)
    }

    let dispatchQueue = DispatchQueue(label: "SharedItemDatabase")

    init(vehicleID: String) {
        self.vehicleID = vehicleID
    }

    func startLoadingNextPageIfAvailable() {
        Task {
            await queryPagination.startLoadingNextPageIfAvailable()
        }
    }

    var isLoadingPage: Bool {
        get async {
            return await queryPagination.isLoadingPage
        }
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

    private func handleUpdate(_ result: Result<FirestoreQueryPagination.Update, Error>) {
        do {
            let update = try result.get()
            updateItems(with: update)
        } catch {
            logger.error(error)
        }
    }

    private func updateItems(with update: FirestoreQueryPagination.Update) {
        items = update.querySnapshot.documents.compactMap({ (document) in
            do {
                var item = try SharedItem.makeItem(document: document)
                item.firebaseDocument = document.reference
                return item
            } catch {
                logger.error(error)
                return nil
            }
        })

        let changes = update.querySnapshot.documentChanges.map { (documentChange) -> Change in
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

        let databaseUpdate = Update(items: items, changes: changes, isCausedByPagination: update.isCausedByPagination)

        delegate?.database(self, didUpdateItems: databaseUpdate)

        NotificationCenter.default.post(name: .SharedItemDatabaseDidUpdateItems, object: self, userInfo: [SharedItemDatabase.updateUserInfoKey: databaseUpdate])
    }
}

extension SharedItemDatabase {
    struct Update {
        let items: [SharedItemProtocol]
        let changes: [Change]
        let isCausedByPagination: Bool
    }

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
