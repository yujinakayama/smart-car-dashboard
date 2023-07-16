//
//  FirestoreDocumentChange.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

enum FirestoreDocumentChange {
    case addition(newIndex: UInt)
    case removal(oldIndex: UInt)
    case move(oldIndex: UInt, newIndex: UInt)
    case update(index: UInt)
    
    init(_ change: DocumentChange) {
        switch change.type {
        case .added:
            self = Self.addition(newIndex: change.newIndex)
        case .removed:
            self = Self.removal(oldIndex: change.oldIndex)
        case .modified:
            if change.oldIndex == change.newIndex {
                self = Self.update(index: change.newIndex)
            } else {
                self = Self.move(oldIndex: change.oldIndex, newIndex: change.newIndex)
            }
        }
    }
}
