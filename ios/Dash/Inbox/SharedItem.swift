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
import WebKit

// TODO: Split metadata and content so that we can handle them easily on instantiation.
protocol SharedItemProtocol: Decodable {
    var firebaseDocument: DocumentReference? { get set }
    var identifier: String! { get set }
    var title: String? { get }
    var url: URL { get }
    var creationDate: Date? { get }
    var hasBeenOpened: Bool { get }
    func open(from viewController: UIViewController?)
    func openSecondarily(from viewController: UIViewController?)
}

extension SharedItemProtocol {
    var rootViewController: UIViewController? {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
    }

    func markAsOpened() {
        firebaseDocument?.updateData(["hasBeenOpened": true])
    }

    func openInOtherApp() {
        UIApplication.shared.open(url, options: [:])
    }

    func openInInAppBrowser(from viewController: UIViewController?) {
        guard let viewController = viewController ?? rootViewController else { return }

        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: WebViewController.self))
        let navigationController = storyboard.instantiateViewController(withIdentifier: "WebViewNavigationController") as! UINavigationController
        let webViewController = navigationController.viewControllers.first as! WebViewController
        webViewController.item = self
        viewController.present(navigationController, animated: true)
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
    case documentDoesNotExist
}

struct SharedItem {
    enum ItemType: String {
        case location
        case musicItem
        case website
        case unknown

        init(dictionary: [String: Any]) throws {
            guard let typeString = dictionary["type"] as? String else {
                throw SharedItemError.invalidDictionaryStructure
            }

            self = ItemType(rawValue: typeString) ?? .unknown
        }
    }

    static func makeItem(document: DocumentSnapshot) throws -> SharedItemProtocol {
        guard let dictionary = document.data() else {
            throw SharedItemError.documentDoesNotExist
        }

        let type = try ItemType(dictionary: dictionary)
        let decoder = Firestore.Decoder() // Supports decoding Firestore's Timestamp

        var item: SharedItemProtocol!

        switch type {
        case .location:
            item = try decoder.decode(Location.self, from: dictionary)
        case .musicItem:
            item = try decoder.decode(MusicItem.self, from: dictionary)
        case .website:
            item = try decoder.decode(Website.self, from: dictionary)
        case .unknown:
            item = try decoder.decode(UnknownItem.self, from: dictionary)
        }

        item.firebaseDocument = document.reference
        item.identifier = document.documentID

        return item
    }

    static func makeItem(dictionary: [String: Any]) throws -> SharedItemProtocol {
        let type = try ItemType(dictionary: dictionary)
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
