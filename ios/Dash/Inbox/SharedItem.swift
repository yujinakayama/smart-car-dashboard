//
//  SharedItem.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import DictionaryCoding
import FirebaseFirestore
import FirebaseFirestoreSwift

protocol SharedItemProtocol: Decodable {
    var firebaseDocument: DocumentReference? { get set }
    var identifier: SharedItem.Identifier { get }
    var url: URL { get }
    var creationDate: Date? { get }
    var hasBeenOpened: Bool { get }
    func open()
}

extension SharedItemProtocol {
    var identifier: SharedItem.Identifier {
        return SharedItem.Identifier(url: url, creationDate: creationDate)
    }

    func markAsOpened() {
        firebaseDocument?.updateData(["hasBeenOpened": true])
    }

    func delete() {
        guard let firebaseDocument = firebaseDocument else { return }

        firebaseDocument.delete { (error) in
            if let error = error {
                logger.error(error)
            }
        }
    }
}

enum SharedItemError: Error {
    case invalidDictionaryStructure
}

struct SharedItem {
    struct Identifier: Hashable {
        let url: URL
        let creationDate: Date?
    }

    enum ItemType: String {
        case location
        case musicItem
        case website
        case unknown

        static func makeType(dictionary: [String: Any]) throws -> ItemType {
            guard let typeString = dictionary["type"] as? String else {
                throw SharedItemError.invalidDictionaryStructure
            }

            return ItemType(rawValue: typeString) ?? .unknown
        }
    }

    static func makeItem(document: QueryDocumentSnapshot) throws -> SharedItemProtocol {
        let dictionary = document.data()
        let type = try ItemType.makeType(dictionary: dictionary)
        let decoder = Firestore.Decoder() // Supports decoding Firestore's Timestamp

        switch type {
        case .location:
            return try decoder.decode(Location.self, from: dictionary)
        case .musicItem:
            return try decoder.decode(MusicItem.self, from: dictionary)
        case .website:
            return try decoder.decode(Website.self, from: dictionary)
        case .unknown:
            return try decoder.decode(UnknownItem.self, from: dictionary)
        }
    }

    static func makeItem(dictionary: [String: Any]) throws -> SharedItemProtocol {
        let type = try ItemType.makeType(dictionary: dictionary)
        let decoder = DictionaryDecoder()

        switch type {
        case .location:
            return try decoder.decode(Location.self, from: dictionary)
        case .musicItem:
            return try decoder.decode(MusicItem.self, from: dictionary)
        case .website:
            return try decoder.decode(Website.self, from: dictionary)
        case .unknown:
            return try decoder.decode(UnknownItem.self, from: dictionary)
        }
    }
}
