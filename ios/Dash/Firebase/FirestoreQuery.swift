//
//  FirestoreQuery.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

class FirestoreQuery<DocumentObject> {
    typealias DocumentDecoder = (DocumentSnapshot) -> DocumentObject?
    typealias Subscription = FirestoreQuerySubscription<DocumentObject>
    typealias PaginatedSubscription = FirestoreQueryPaginatedSubscription<DocumentObject>
    typealias CountSubscription = FirestoreQueryCountSubscription

    private let query: Query
    private let documentDecoder: DocumentDecoder

    init(_ query: Query, documentDecoder: @escaping DocumentDecoder) {
        self.query = query
        self.documentDecoder = documentDecoder
    }

    func get() async throws -> [DocumentObject] {
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { documentDecoder($0) }
    }

    func subscribeToUpdates(updateHandler: @escaping Subscription.UpdateHandler) -> Subscription {
        let subscrition = Subscription(
            query: query,
            decodingDocumentWith: documentDecoder,
            onUpdate: updateHandler
        )

        subscrition.activate()

        return subscrition
    }

    func subscribeToUpdates(documentCountPerPage: Int, updateHandler: @escaping PaginatedSubscription.UpdateHandler) -> PaginatedSubscription {
        let subscription = PaginatedSubscription(
            query: query,
            documentCountPerPage: documentCountPerPage,
            decodingDocumentWith: documentDecoder,
            onUpdate: updateHandler
        )

        Task {
            await subscription.incrementPage()
        }

        return subscription
    }

    func subscribeToCountUpdates(updateHandler: @escaping CountSubscription.UpdateHandler) -> CountSubscription {
        let subscription = CountSubscription(
            query: query,
            onUpdate: updateHandler
        )

        subscription.activate()

        return subscription
    }
}
