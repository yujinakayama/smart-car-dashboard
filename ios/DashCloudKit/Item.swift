//
//  Item.swift
//  DashCloudKit
//
//  Created by Yuji Nakayama on 2020/02/07.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers
import MapKit
import DictionaryCoding

public class Item {
    private let encoder: ItemEncoderProtocol

    public init(extensionItem: NSExtensionItem) {
        encoder = ExtensionItemEncoder(extensionItem: extensionItem)
    }

    public init(encoder: ItemEncoderProtocol) {
        self.encoder = encoder
    }

    public var isValid: Bool {
        return encoder.hasEncodableContent
    }

    func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
        encoder.encode(completionHandler: completionHandler)
    }
}

public protocol ItemEncoderProtocol {
    var hasEncodableContent: Bool { get }
    func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void)
}

extension Item {
    public class Encoder: ItemEncoderProtocol {
        private var encodedDictionary: [String: Any] = [:]

        public init() {
        }

        public func add(_ url: URL) {
            add(url.absoluteString, for: .url)
        }

        public func add(_ string: String) {
            add(string, for: .plainText)
        }

        public func add(_ mapItem: MKMapItem) {
            add(dictionary(for: mapItem), for: .mapItem)
        }

        public func add(_ mapItem: MapItem) {
            var dictionary = dictionary(for: mapItem.mapItem)
            dictionary["pointOfInterestCategory"] = mapItem.customCategory
            add(dictionary, for: .mapItem)
        }

        public var hasEncodableContent: Bool {
            return !encodedDictionary.isEmpty
        }

        public func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
            completionHandler(.success(encodedDictionary))
        }

        private let serialQueue = DispatchQueue(label: "com.yujinakayama.DashCloudKit.Item.Encoder")

        private func add(_ value: Any, for type: UTType) {
            serialQueue.sync {
                encodedDictionary[type.identifier] = value
            }
        }

        private func dictionary(for mapItem: MKMapItem) -> [String: Any] {
            let encoder = DictionaryEncoder()
            return try! encoder.encode(mapItem)
        }
    }
}

extension Item {
    enum ExtensionItemEncoderError: Error {
        case noAttachments
    }

    class ExtensionItemEncoder: ItemEncoderProtocol {
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
