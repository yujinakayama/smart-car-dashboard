//
//  FirestoreQuery.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class FirestoreDocument<DocumentObject> {
    typealias DocumentDecoder = (DocumentSnapshot) -> DocumentObject?
    typealias Subscription = FirestoreDocumentSubscription<DocumentObject>

    private let document: DocumentReference
    private let documentDecoder: DocumentDecoder

    init(_ document: DocumentReference, documentDecoder: @escaping DocumentDecoder) {
        self.document = document
        self.documentDecoder = documentDecoder
    }

    func get() async throws -> DocumentObject? {
        let snapshot = try await document.getDocument()
        return documentDecoder(snapshot)
    }

    func subscribeToUpdates(updateHandler: @escaping Subscription.UpdateHandler) -> Subscription {
        let subscrition = Subscription(
            document: document,
            decodingDocumentWith: documentDecoder,
            onUpdate: updateHandler
        )

        subscrition.activate()

        return subscrition
    }
}

extension FirestoreDocument where DocumentObject: Decodable {
    convenience init(_ document: DocumentReference) {
        let documentDecoder: DocumentDecoder = { (documentSnapshot) in
            do {
                return try documentSnapshot.data(as: DocumentObject.self)
            } catch {
                logger.error(error)
                return nil
            }
        }

        self.init(document, documentDecoder: documentDecoder)
    }
}
