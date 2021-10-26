//
//  SharingItem.swift
//  ShareKit
//
//  Created by Yuji Nakayama on 2020/02/07.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers
import MapKit

public class Item {
    private let encoder: SharingItemEncoderProtocol

    public init(extensionItem: NSExtensionItem) {
        encoder = ExtensionItemEncoder(extensionItem: extensionItem)
    }

    public init(url: URL? = nil, plainText: String? = nil, mapItem: MKMapItem? = nil) {
        let encoder = Encoder()

        if let url = url {
            encoder.add(url)
        }

        if let plainText = plainText {
            encoder.add(plainText)
        }

        if let mapItem = mapItem {
            encoder.add(mapItem)
        }

        self.encoder = encoder
    }

    public var isValid: Bool {
        return encoder.hasEncodableContent
    }

    func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
        encoder.encode(completionHandler: completionHandler)
    }
}

protocol SharingItemEncoderProtocol {
    var hasEncodableContent: Bool { get }
    func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void)
}

extension Item {
    class Encoder: SharingItemEncoderProtocol {
        private var encodedDictionary: [String: Any] = [:]

        func add(_ url: URL) {
            add(url.absoluteString, for: .url)
        }

        func add(_ string: String) {
            add(string, for: .plainText)
        }

        func add(_ mapItem: MKMapItem) {
            let dictionary = [
                "placemark": [
                    "coordinate": [
                        "latitude": mapItem.placemark.coordinate.latitude,
                        "longitude": mapItem.placemark.coordinate.longitude
                    ],
                    "isoCountryCode": mapItem.placemark.isoCountryCode as Any,
                    "country": mapItem.placemark.country as Any,
                    "postalCode": mapItem.placemark.postalCode as Any,
                    "administrativeArea": mapItem.placemark.administrativeArea as Any,
                    "subAdministrativeArea": mapItem.placemark.subAdministrativeArea as Any,
                    "locality": mapItem.placemark.locality as Any,
                    "subLocality": mapItem.placemark.subLocality as Any,
                    "thoroughfare": mapItem.placemark.thoroughfare as Any,
                    "subThoroughfare": mapItem.placemark.subThoroughfare as Any
                ],
                "name": mapItem.name as Any,
                "phoneNumber": mapItem.phoneNumber as Any,
                "pointOfInterestCategory": mapItem.pointOfInterestCategory?.rawValue as Any,
                "url": mapItem.url?.absoluteString as Any,
            ]

            add(dictionary, for: .mapItem)
        }

        var hasEncodableContent: Bool {
            return !encodedDictionary.isEmpty
        }

        func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
            completionHandler(.success(encodedDictionary))
        }

        private let serialQueue = DispatchQueue(label: "com.yujinakayama.DashCloudKit.Item.Encoder")

        private func add(_ value: Any, for type: UTType) {
            serialQueue.sync {
                encodedDictionary[type.identifier] = value
            }
        }
    }
}

extension Item {
    enum ExtensionItemEncoderError: Error {
        case noAttachments
    }

    class ExtensionItemEncoder: SharingItemEncoderProtocol {
        static let supportedTypes: Set<UTType> = [
            .url,
            .plainText,
            .mapItem
        ]

        let extensionItem: NSExtensionItem

        private let encoder = Encoder()

        init(extensionItem: NSExtensionItem) {
            self.extensionItem = extensionItem
        }

        var hasEncodableContent: Bool {
            guard let attachments = extensionItem.attachments else { return false }

            let types = attachments.map { (attachment) -> UTType? in
                guard let typeIdentifier = attachment.registeredTypeIdentifiers.first else { return nil }
                return UTType(typeIdentifier)
            }.compactMap { $0 }

            return !Self.supportedTypes.intersection(types).isEmpty
        }

        func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
            guard let attachments = extensionItem.attachments else {
                completionHandler(.failure(ExtensionItemEncoderError.noAttachments))
                return
            }

            let dispatchGroup = DispatchGroup()

            for attachment in attachments {
                dispatchGroup.enter()

                encode(attachment) {
                    dispatchGroup.leave()
                }
            }

            dispatchGroup.notify(queue: .main) {
                self.encoder.encode(completionHandler: completionHandler)
            }
        }

        private func encode(_ attachment: NSItemProvider, completionHandler: @escaping () -> Void) {
            guard let typeIdentifier = attachment.registeredTypeIdentifiers.first else {
                completionHandler()
                return
            }

            guard let type = UTType(typeIdentifier) else {
                completionHandler()
                return
            }

            switch type {
            case .url:
                // Not sure why but loadItem(forTypeIdentifier:options:) does not work on Mac
                _ = attachment.loadObject(ofClass: URL.self) { (url, error) in
                    if let url = url {
                        self.encoder.add(url)
                    }
                    completionHandler()
                }
            case .plainText:
                attachment.loadItem(forTypeIdentifier: type.identifier, options: nil) { (string, error) in
                    if let string = string as? String {
                        self.encoder.add(string)
                    }
                    completionHandler()
                }
            case .mapItem:
                _ = attachment.loadObject(ofClass: MKMapItem.self) { (mapItem, error) in
                    if let mapItem = mapItem as? MKMapItem {
                        self.encoder.add(mapItem)
                    }
                    completionHandler()
                }
            default:
                completionHandler()
            }
        }
    }
}
