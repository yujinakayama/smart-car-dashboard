//
//  MapItemFetcher.swift
//  ParkingSearchActionExtension
//
//  Created by Yuji Nakayama on 2021/06/11.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit
import DashCloudKit
import UniformTypeIdentifiers

class MapItemFetcher {
    let extensionItem: NSExtensionItem

    init(extensionItem: NSExtensionItem) {
        self.extensionItem = extensionItem
    }

    func fetchMapItem(completion: @escaping (Result<MKMapItem, Error>) -> Void) {
        if loadMapItem(completion: completion) { return }
        if makeMapItem(completion: completion) { return }
        fatalError()
    }

    private func loadMapItem(completion: @escaping (Result<MKMapItem, Error>) -> Void) -> Bool {
        guard let attachment = mapItemAttachment else { return false }

        _ = attachment.loadObject(ofClass: MKMapItem.self) { (mapItem, error) in
            DispatchQueue.main.async {
                if let mapItem = mapItem as? MKMapItem {
                    completion(.success(mapItem))
                }

                if let error = error {
                    completion(.failure(error))
                }
            }
        }

        return true
    }

    private func makeMapItem(completion: @escaping (Result<MKMapItem, Error>) -> Void) -> Bool {
        guard let urlAttachment = urlAttachment else { return false }

        var finalCoordinate: CLLocationCoordinate2D?
        var finalPlainText: String?
        var finalError: Error?

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        _ = urlAttachment.loadObject(ofClass: URL.self) { (url, error) in
            if let url = url {
                self.cloudClient.geocodeGoogleMapsLocation(url) { (result) in
                    switch result {
                    case .success(let coordinate):
                        finalCoordinate = coordinate
                    case .failure(let error):
                        finalError = error
                    }
                    dispatchGroup.leave()
                }
            } else {
                finalError = error
                dispatchGroup.leave()
            }
        }

        if let plainTextAttachment = plainTextAttachment {
            dispatchGroup.enter()
            plainTextAttachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (string, error) in
                if let string = string as? String {
                    finalPlainText = string
                }

                if let error = error {
                    finalError = error
                }

                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            if let coordinate = finalCoordinate {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                if let plainText = finalPlainText {
                    mapItem.name = plainText.components(separatedBy: .newlines).first
                }
                completion(.success(mapItem))
            } else if let error = finalError {
                completion(.failure(error))
            }
        }

        return true
    }

    var mapItemAttachment: NSItemProvider? {
        return attachments[UTType.mapItem.identifier]
    }

    var urlAttachment: NSItemProvider? {
        return attachments[UTType.url.identifier]
    }

    var plainTextAttachment: NSItemProvider? {
        return attachments[UTType.plainText.identifier]
    }

    lazy var attachments: [String: NSItemProvider] = {
        var dictionary: [String: NSItemProvider] = [:]

        for attachment in extensionItem.attachments ?? [] {
            if let typeIdentifier = attachment.registeredTypeIdentifiers.first {
                dictionary[typeIdentifier] = attachment
            }
        }

        return dictionary
    }()

    lazy var cloudClient = DashCloudClient()
}
