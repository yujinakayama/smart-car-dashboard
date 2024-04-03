//
//  FirestoreQuerySubscription.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

class FirestoreDocumentSubscription<DocumentObject> {
    typealias DocumentDecoder = (DocumentSnapshot) -> DocumentObject?
    typealias UpdateHandler = (Result<DocumentObject?, Error>) -> Void

    let document: DocumentReference
    let documentDecoder: DocumentDecoder
    let updateHandler: UpdateHandler

    private var querySnapshotListener: ListenerRegistration?

    init(document: DocumentReference, decodingDocumentWith documentDecoder: @escaping DocumentDecoder, onUpdate updateHandler: @escaping UpdateHandler) {
        self.document = document
        self.documentDecoder = documentDecoder
        self.updateHandler = updateHandler
    }

    deinit {
        querySnapshotListener?.remove()
    }

    func activate() {
        querySnapshotListener = document.addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self else { return }

            if let error = error {
                self.updateHandler(.failure(error))
            } else if let snapshot = snapshot {
                let document = documentDecoder(snapshot)
                self.updateHandler(.success(document))
            }
        }
    }
}
