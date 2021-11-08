//
//  FirestorePagination.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/11/08.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

actor FirestoreQueryPagination {
    typealias UpdateHandler = (Result<QuerySnapshot, Error>) -> Void

    let query: Query
    let documentCountPerPage: Int
    let updateHandler: UpdateHandler

    var currentPage = 0
    var isLoadingPage = false

    private var querySnapshotListener: ListenerRegistration?
    private var lastQuerySnapshot: QuerySnapshot?

    init(query: Query, documentCountPerPage: Int, updateHandler: @escaping UpdateHandler) {
        self.query = query
        self.documentCountPerPage = documentCountPerPage
        self.updateHandler = updateHandler
    }

    deinit {
        querySnapshotListener?.remove()
    }

    func startLoadingNextPageIfAvailable() {
        guard isNextPageAvailable else { return }
        currentPage += 1
        startObservingDocuments(upToPage: currentPage)
    }

    private var isNextPageAvailable: Bool {
        guard let lastQuerySnapshot = lastQuerySnapshot else { return true }
        return lastQuerySnapshot.count >= documentCountPerPage * currentPage
    }

    private func startObservingDocuments(upToPage page: Int) {
        isLoadingPage = true

        querySnapshotListener?.remove()

        let queryWithLimit = query.limit(to: documentCountPerPage * page)

        querySnapshotListener = queryWithLimit.addSnapshotListener { [weak self] (querySnapshot, error) in
            guard let self = self else { return }

            Task {
                await self.handleUpdate(querySnapshot: querySnapshot, error: error)
            }
        }
    }

    private func handleUpdate(querySnapshot: QuerySnapshot?, error: Error?) {
        isLoadingPage = false

        if let error = error {
            updateHandler(.failure(error))
        } else if let querySnapshot = querySnapshot {
            lastQuerySnapshot = querySnapshot
            updateHandler(.success(querySnapshot))
        }
    }
}
