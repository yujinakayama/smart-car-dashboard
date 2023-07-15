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
    @DocumentID var documentReference: DocumentReference!

    var name: String = ""

    var brand: Brand = .unknown

    var order: UInt = 0
    
    init(documentReference: DocumentReference) {
        self.documentReference = documentReference
    }

    var uuid: UUID {
        return UUID(uuidString: documentReference.documentID)!
    }

    var displayedName: String {
        return name.isEmpty ? String(localized: "Unnamed Card") : name
    }

    func save() throws {
        guard let documentReference = documentReference else {
            throw ETCCardError.missingDocumentReference
        }

        try documentReference.setData(from: self)
    }
}

extension ETCCard {
    enum Brand: Int, Codable {
        case unknown = 0
        case visa
        case mastercard
    }
}

enum ETCCardError: Error {
    case missingDocumentReference
}
