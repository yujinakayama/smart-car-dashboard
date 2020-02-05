//
//  InputItem.swift
//  ShareExtension
//
//  Created by Yuji Nakayama on 2020/01/31.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit

class InputItem {
    let item: NSExtensionItem

    init(item: NSExtensionItem) throws {
        self.item = item
    }

    lazy var attachmentsByTypeIdentifier: [String: NSItemProvider] = {
        var attachmentsByTypeIdentifier: [String: NSItemProvider] = [:]

        for attachment in attachments {
            guard let typeIdentifier = attachment.registeredTypeIdentifiers.first else { continue }
            attachmentsByTypeIdentifier[typeIdentifier] = attachment
        }

        return attachmentsByTypeIdentifier
    }()

    var attachments: [NSItemProvider] {
        return item.attachments ?? []
    }

    func encode(completionHandler: @escaping ([String: Any]) -> Void) {
        var dictionary: [String: Any] = [
            "title": item.attributedTitle?.string as Any,
            "contentText": item.attributedContentText?.string as Any
        ]

        let serialQueue = DispatchQueue(label: "exclusive-dictionary-modification")
        let dispatchGroup = DispatchGroup()

        for (typeIdentifier, attachment) in attachmentsByTypeIdentifier {
            dispatchGroup.enter()

            encode(attachment) { (attachmentValue) in
                if let attachmentValue = attachmentValue {
                    serialQueue.async {
                        dictionary[typeIdentifier] = attachmentValue
                        dispatchGroup.leave()
                    }
                } else {
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .global()) {
            completionHandler(dictionary)
        }
    }

    private func encode(_ attachment: NSItemProvider, completionHandler: @escaping (Any?) -> Void) {
        let typeIdentifier = attachment.registeredTypeIdentifiers.first!

        switch typeIdentifier {
        case "public.url":
            attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (url, error) in
                if let url = url as? URL {
                    completionHandler(url.absoluteString)
                } else {
                    completionHandler(nil)
                }
            }
        case "public.plain-text":
            attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (plainText, error) in
                if let plainText = plainText as? String {
                    completionHandler(plainText)
                } else {
                    completionHandler(nil)
                }
            }
        case "com.apple.mapkit.map-item":
            _ = attachment.loadObject(ofClass: MKMapItem.self) { (mapItem, error) in
                if let mapItem = mapItem as? MKMapItem {
                    completionHandler(self.encode(mapItem))
                } else {
                    completionHandler(nil)
                }
            }
        default:
            completionHandler(nil)
        }
    }

    private func encode(_ mapItem: MKMapItem) -> [String: Any] {
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
}
