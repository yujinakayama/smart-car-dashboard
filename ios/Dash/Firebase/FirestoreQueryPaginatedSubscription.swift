//
//  FirestorePagination.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/11/08.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

actor FirestoreQueryPaginatedSubscription<DocumentObject> {
    typealias DocumentDecoder = (DocumentSnapshot) -> DocumentObject?
    typealias Update = (documents: [DocumentObject], changes: [FirestoreDocumentChange<DocumentObject>], isCausedByPagination: Bool)
    typealias UpdateHandler = (Result<Update, Error>) -> Void

    let query: Query
    let documentCountPerPage: Int
    let documentDecoder: DocumentDecoder
    let updateHandler: UpdateHandler

    var currentSubscription: FirestoreQuerySubscription<DocumentObject>?
    var currentPage = 0
    var isLoadingNewPage = false

    private var querySnapshotListener: ListenerRegistration?
    private var lastQueryDocumentCount: Int?

    init(query: Query, documentCountPerPage: Int, decodingDocumentWith documentDecoder: @escaping DocumentDecoder, onUpdate updateHandler: @escaping UpdateHandler) {
        self.query = query
        self.documentCountPerPage = documentCountPerPage
        self.documentDecoder = documentDecoder
        self.updateHandler = updateHandler
    }

    deinit {
        querySnapshotListener?.remove()
    }

    func incrementPage() {
        guard isNextPageAvailable else { return }
        currentPage += 1
        startObservingDocuments(upToPage: currentPage)
    }

    private var isNextPageAvailable: Bool {
        guard let lastQueryDocumentCount = lastQueryDocumentCount else { return true }
        return lastQueryDocumentCount >= documentCountPerPage * currentPage
    }

    private func startObservingDocuments(upToPage page: Int) {
        isLoadingNewPage = true

        let queryWithLimit = query.limit(to: documentCountPerPage * page)

        currentSubscription = FirestoreQuerySubscription(query: queryWithLimit, decodingDocumentWith: documentDecoder, onUpdate: { [weak self] (result) in
            guard let self = self else { return }

            Task {
                await self.handleUpdate(result: result)
            }
        })

        currentSubscription?.activate()
    }

    private func handleUpdate(result: Result<FirestoreQuerySubscription<DocumentObject>.Update, Error>) {
        let isCausedByPagination = isLoadingNewPage
        isLoadingNewPage = false

        do {
            let (documents, changes) = try result.get()
            lastQueryDocumentCount = documents.count
            let update = (documents: documents, changes: changes, isCausedByPagination: isCausedByPagination)
            updateHandler(.success(update))

        } catch {
            updateHandler(.failure(error))
        }
    }
}
