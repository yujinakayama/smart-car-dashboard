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

    var isLoading = false

    private var _items: [SharedItemProtocol] = []

    private lazy var collection = Firestore.firestore().collection("vehicles").document(vehicleID).collection("items")

    private lazy var baseQuery = collection.order(by: "creationDate", descending: true)

    private var querySnapshotListener: ListenerRegistration?

    private var lastQuerySnapshot: QuerySnapshot?

    private var currentPage = 0

    private let itemCountPerPage = 20

    let dispatchQueue = DispatchQueue(label: "SharedItemDatabase")

    init(vehicleID: String) {
        self.vehicleID = vehicleID
    }

    deinit {
        endUpdating()
    }

    func startUpdating() {
        currentPage = 0
        loadNextPageIfAvailable()
    }

    func endUpdating() {
        querySnapshotListener?.remove()
        querySnapshotListener = nil
        lastQuerySnapshot = nil
    }

    func loadNextPageIfAvailable() {
        guard isNextPageAvailable else { return }
        currentPage += 1
        startObservingItems(upToPage: currentPage)
    }

    private var isNextPageAvailable: Bool {
        guard let lastQuerySnapshot = lastQuerySnapshot else { return true }
        return lastQuerySnapshot.count >= itemCountPerPage * currentPage
    }

    private func startObservingItems(upToPage page: Int) {
        print(#function, page)

        querySnapshotListener?.remove()

        let query = baseQuery.limit(to: itemCountPerPage * page)

        isLoading = true

        querySnapshotListener = query.addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self else { return }

            self.isLoading = false

            if let error = error {
                logger.error(error)
                return
            }

            guard let snapshot = snapshot else { return }

            self.lastQuerySnapshot = snapshot

            self.updateItems(from: snapshot)
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

        let update = Update(items: items, changes: changes)

        delegate?.database(self, didUpdateItems: update)

        NotificationCenter.default.post(name: .SharedItemDatabaseDidUpdateItems, object: self, userInfo: [SharedItemDatabase.updateUserInfoKey: update])
    }
}

extension SharedItemDatabase {
    struct Update {
        let items: [SharedItemProtocol]
        let changes: [Change]
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
