//
//  SharingItem.swift
//  ShareKit
//
//  Created by Yuji Nakayama on 2020/02/07.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import MobileCoreServices
import MapKit

enum SharingItemError: Error {
    case serverError
}

public class SharingItem {
    private let encoder: SharingItemEncoderProtocol

    public init(encoder: SharingItemEncoderProtocol) {
        self.encoder = encoder
    }

    public func share(with vehicleID: String, completionHandler: @escaping (Error?) -> Void) {
        encoder.encode { (result) in
            switch result {
            case .success(let encodedDictionary):
                self.send(encodedDictionary, to: vehicleID, completionHandler: completionHandler)
            case .failure(let error):
                completionHandler(error)
            }
        }
    }

    private func send(_ itemDictionary: [String: Any], to vehicleID: String, completionHandler: @escaping (Error?) -> Void) {
        var request = URLRequest(url: endPointURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "vehicleID": vehicleID,
            "item": itemDictionary
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completionHandler(error)
        }

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completionHandler(error)
                    return
                }

                if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                    completionHandler(SharingItemError.serverError)
                    return
                }

                completionHandler(nil)
            }
        }

        task.resume()
    }

    private var endPointURL: URL {
        let bundle = Bundle(for: GoogleServiceInfo.self)
        let googleServiceInfo = GoogleServiceInfo(path: bundle.path(forResource: "GoogleService-Info", ofType: "plist")!)
        let endPointURLString = "https://asia-northeast1-\(googleServiceInfo.projectID).cloudfunctions.net/share"
        return URL(string: endPointURLString)!
    }
}

extension SharingItem {
    enum TypeIdentifier: String {
        case url = "public.url"
        case plainText = "public.plain-text"
        case mapItem = "com.apple.mapkit.map-item"
    }
}

public protocol SharingItemEncoderProtocol {
    func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void)
}

extension SharingItem {
    public class Encoder: SharingItemEncoderProtocol {
        var encodedDictionary: [String: Any] = [:]

        public init() {
        }

        public func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
            completionHandler(.success(encodedDictionary))
        }

        public func add(_ url: URL) {
            add(url.absoluteString, for: .url)
        }

        public func add(_ string: String) {
            add(string, for: .plainText)
        }

        public func add(_ mapItem: MKMapItem) {
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

        private let serialQueue = DispatchQueue(label: "com.yujinakayama.ShareKit.SharingItem.Encoder")

        private func add(_ value: Any, for typeIdentifier: TypeIdentifier) {
            serialQueue.sync {
                encodedDictionary[typeIdentifier.rawValue] = value
            }
        }
    }
}

extension SharingItem {
    enum ExtensionItemEncoderError: Error {
        case noAttachments
    }

    public class ExtensionItemEncoder: SharingItemEncoderProtocol {
        let extensionItem: NSExtensionItem

        private let encoder = Encoder()

        public init(extensionItem: NSExtensionItem) {
            self.extensionItem = extensionItem
        }

        public func encode(completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
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
                completionHandler(.success(self.encoder.encodedDictionary))
            }
        }

        private func encode(_ attachment: NSItemProvider, completionHandler: @escaping () -> Void) {
            guard let typeIdentifierString = attachment.registeredTypeIdentifiers.first else {
                completionHandler()
                return
            }

            guard let typeIdentifier = TypeIdentifier(rawValue: typeIdentifierString) else {
                completionHandler()
                return
            }

            switch typeIdentifier {
            case .url:
                // Not sure why but loadItem(forTypeIdentifier:options:) does not work on Mac
                _ = attachment.loadObject(ofClass: URL.self) { (url, error) in
                    if let url = url {
                        self.encoder.add(url)
                    }
                    completionHandler()
                }
            case .plainText:
                attachment.loadItem(forTypeIdentifier: typeIdentifier.rawValue, options: nil) { (string, error) in
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
            }
        }
    }
}
