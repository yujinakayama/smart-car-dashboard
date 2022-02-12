//
//  FirestoreQueryCountSubscription.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

class FirestoreQueryCountSubscription {
    typealias UpdateHandler = (Result<Int, Error>) -> Void

    let query: Query
    let updateHandler: UpdateHandler

    private var querySnapshotListener: ListenerRegistration?

    init(query: Query, onUpdate updateHandler: @escaping UpdateHandler) {
        self.query = query
        self.updateHandler = updateHandler
    }

    deinit {
        querySnapshotListener?.remove()
    }

    func activate() {
        querySnapshotListener = query.addSnapshotListener { [weak self] (querySnapshot, error) in
            guard let self = self else { return }

            if let error = error {
                self.updateHandler(.failure(error))
            } else if let querySnapshot = querySnapshot {
                self.updateHandler(.success(querySnapshot.count))
            }
        }
    }
}
