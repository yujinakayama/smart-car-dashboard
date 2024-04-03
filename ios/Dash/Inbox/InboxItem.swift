//
//  InboxItem.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import DictionaryCoding
import FirebaseFirestore
import FirebaseFirestoreSwift
import WebKit

// TODO: Split metadata and content so that we can handle them easily on instantiation.
protocol InboxItemProtocol: Decodable {
    var firebaseDocument: DocumentReference? { get set }
    var title: String? { get }
    var url: URL { get }
    var creationDate: Date? { get }
    var hasBeenOpened: Bool { get }

    @MainActor
    func open(from viewController: UIViewController) async
}

extension InboxItemProtocol {
    var documentID: String? {
        firebaseDocument?.documentID
    }

    func openInDefaultApp() {
        UIApplication.shared.open(url, options: [:])
    }

    func openInInAppBrowser(from viewController: UIViewController) {
        WebViewController.present(url: url, from: viewController)
    }

    func markAsOpened(_ value: Bool) {
        firebaseDocument?.updateData(["hasBeenOpened": value])
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

enum InboxItemError: Error {
    case invalidDictionaryStructure
    case documentDoesNotExist
}

struct InboxItem {
    enum ItemType: String {
        case location
        case musicItem
        case video
        case website
        case unknown

        init(dictionary: [String: Any]) throws {
            guard let typeString = dictionary["type"] as? String else {
                throw InboxItemError.invalidDictionaryStructure
            }

            self = ItemType(rawValue: typeString) ?? .unknown
        }
    }

    static func makeItem(document: DocumentSnapshot) throws -> InboxItemProtocol {
        guard let dictionary = document.data() else {
            throw InboxItemError.documentDoesNotExist
        }

        let type = try ItemType(dictionary: dictionary)
        let decoder = Firestore.Decoder() // Supports decoding Firestore's Timestamp

        var item: InboxItemProtocol

        switch type {
        case .location:
            item = try decoder.decode(InboxLocation.self, from: dictionary)
        case .musicItem:
            item = try decoder.decode(MusicItem.self, from: dictionary)
        case .video:
            item = try decoder.decode(Video.self, from: dictionary)
        case .website:
            item = try decoder.decode(Website.self, from: dictionary)
        case .unknown:
            item = try decoder.decode(UnknownItem.self, from: dictionary)
        }

        item.firebaseDocument = document.reference

        return item
    }

    static func makeItem(dictionary: [String: Any]) throws -> InboxItemProtocol {
        let type = try ItemType(dictionary: dictionary)
        let decoder = DictionaryDecoder()

        switch type {
        case .location:
            return try decoder.decode(InboxLocation.self, from: dictionary)
        case .musicItem:
            return try decoder.decode(MusicItem.self, from: dictionary)
        case .video:
            return try decoder.decode(Video.self, from: dictionary)
        case .website:
            return try decoder.decode(Website.self, from: dictionary)
        case .unknown:
            return try decoder.decode(UnknownItem.self, from: dictionary)
        }
    }
}
