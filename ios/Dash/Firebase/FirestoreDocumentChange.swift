//
//  FirestoreDocumentChange.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

struct FirestoreDocumentChange<DocumentObject> {
    var type: FirestoreDocumentChangeType
    var document: DocumentObject
}

// Firestore's DocumentChange doesn't print its type when debugging
enum FirestoreDocumentChangeType {
    case addition
    case removal
    case modification
    
    init(_ change: DocumentChange) {
        switch change.type {
        case .added:
            self = .addition
        case .removed:
            self = .removal
        case .modified:
            self = .modification
        }
    }
}
