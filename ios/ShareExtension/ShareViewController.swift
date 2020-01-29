//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseCore
import FirebaseFirestore
import MapKit

enum ShareError: Error {
    case noAttachmentIsAvailable
    case unknown
}

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        FirebaseApp.configure()

        share()
    }

    func share() {
        let extContext = extensionContext!

        guard let items = extContext.inputItems as? [NSExtensionItem], let attachments = items.first?.attachments else {
            extensionContext!.cancelRequest(withError: ShareError.noAttachmentIsAvailable)
            return
        }

        aggregate(attachments: attachments) { (result) in
            switch result {
            case .success(let document):
                self.createItemOnFirestore(document: document) { (error) in
                    if let error = error {
                        extContext.cancelRequest(withError: error)
                    } else {
                        extContext.completeRequest(returningItems: nil)
                    }
                }
            case .failure(let error):
                extContext.cancelRequest(withError: error)
            }
        }
    }

    func aggregate(attachments: [NSItemProvider], completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
        var document: [String: Any] = [:]

        let serialQueue = DispatchQueue(label: "exclusive-document-modification")
        let dispatchGroup = DispatchGroup()

        for attachment in attachments {
            dispatchGroup.enter()

            extractValues(from: attachment) { (partialDocument) in
                if let partialDocument = partialDocument {
                    serialQueue.async {
                        document.merge(partialDocument) { (current, _) in current }
                        dispatchGroup.leave()
                    }
                } else {
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .global()) {
            if document["public.url"] == nil {
                completionHandler(.failure(ShareError.unknown))
            } else {
                completionHandler(.success(document))
            }
        }
    }

    func extractValues(from attachment: NSItemProvider, completionHandler: @escaping ([String: Any]?) -> Void) {
        let typeIdentifier = attachment.registeredTypeIdentifiers.first!

        switch typeIdentifier {
        case "public.url":
            attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (url, error) in
                if let url = url as? URL {
                    completionHandler([typeIdentifier: url.absoluteString])
                } else {
                    completionHandler(nil)
                }
            }
        case "public.plain-text":
            attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (plainText, error) in
                if let plainText = plainText as? String {
                    completionHandler([typeIdentifier: plainText])
                } else {
                    completionHandler(nil)
                }
            }
        case "com.apple.mapkit.map-item":
            _ = attachment.loadObject(ofClass: MKMapItem.self) { (mapItem, error) in
                if let mapItem = mapItem as? MKMapItem {
                    completionHandler([typeIdentifier: self.extractValues(from: mapItem)])
                } else {
                    completionHandler(nil)
                }
            }
        default:
            completionHandler(nil)
        }
    }

    func extractValues(from mapItem: MKMapItem) -> [String: Any] {
        return [
            "coordinate": [
                "latitude": mapItem.placemark.coordinate.latitude,
                "longitude": mapItem.placemark.coordinate.longitude
            ],
            "name": mapItem.name as Any,
            "phoneNumber": mapItem.phoneNumber as Any,
            "pointOfInterestCategory": mapItem.pointOfInterestCategory?.rawValue as Any,
            "url": mapItem.url?.absoluteString as Any,
        ]
    }

    func createItemOnFirestore(document: [String: Any], completionHandler: @escaping (Error?) -> Void) {
        let entireDocument = ["raw": document]
        Firestore.firestore().collection("items").addDocument(data: entireDocument, completion: completionHandler)
    }
}
