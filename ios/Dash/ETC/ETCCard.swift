//
//  ETCCard.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/13.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ETCCard: Codable {
    // documentRefernce may not be set even we have saved to Firestore
    // due to the offline support in client SDK
    @DocumentID var documentReference: DocumentReference?

    // Without name field in Firestore document the it will be ignored in query with "name" order
    var name: String = ""

    var brand: ETCCardBrand = .unknown

    var uuid: UUID {
        get {
            if let uuid = _uuid {
                return uuid
            }

            if let uuidString = documentReference?.documentID {
                return UUID(uuidString: uuidString)!
            }

            fatalError()
        }

        set {
            _uuid = newValue
        }
    }

    private var _uuid: UUID?

    init(uuid: UUID) {
        self.uuid = uuid
    }

    var displayedName: String {
        return name.isEmpty ? "Unnamed Card" : name
    }

    func save() throws {
        guard let documentReference = documentReference else {
            throw ETCCardError.missingDocumentReference
        }

        try documentReference.setData(from: self)
    }
}

enum ETCCardBrand: Int, Codable {
    case unknown = 0
    case visa
    case mastercard
}

enum ETCCardError: Error {
    case missingDocumentReference
}
