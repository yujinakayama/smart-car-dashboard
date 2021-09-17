//
//  Location.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit
import FirebaseFirestore
import CommonCrypto
import ParkingSearchKit

class Location: SharedItemProtocol {
    var firebaseDocument: DocumentReference?
    var identifier: String!

    let address: Address
    let coordinate: CLLocationCoordinate2D
    let name: String?
    let url: URL
    let websiteURL: URL?
    let creationDate: Date?
    var hasBeenOpened: Bool

    lazy var formattedAddress = address.format()

    lazy var pointOfInterestFinder: PointOfInterestFinder? = {
        guard let name = name else { return nil }
        return PointOfInterestFinder(name: name, coordinate: coordinate, maxDistance: 50)
    }()

    var title: String? {
        return name
    }

    func open() {
        markAsOpened()

        getNormalizedMapItem { (mapItem) in
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
        }
    }

    private func getNormalizedMapItem(completion: @escaping (MKMapItem) -> Void) {
        findCorrespondingPointOfInterest() { (pointOfInterest) in
            completion(pointOfInterest ?? self.mapItem)
        }
    }

    private func findCorrespondingPointOfInterest(completionHandler: @escaping (MKMapItem?) -> Void) {
        guard let pointOfInterestFinder = pointOfInterestFinder else {
            completionHandler(nil)
            return
        }

        pointOfInterestFinder.find(completionHandler: completionHandler)
    }

    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        return mapItem
    }

    var googleMapsDirectionsURL: URL {
        // https://developers.google.com/maps/documentation/urls/get-started#directions-action
        var components = URLComponents(string: "https://www.google.com/maps/dir/?api=1")!
        components.queryItems?.append(URLQueryItem(name: "destination", value: "\(coordinate.latitude),\(coordinate.longitude)"))
        components.queryItems?.append(URLQueryItem(name: "travelmode", value: "driving"))
        return components.url!
    }

    class PointOfInterestFinder {
        static let cache = Cache(name: "PointOfInterestFinder", ageLimit: 60 * 60 * 24 * 7) // 7 days

        let name: String
        let coordinate: CLLocationCoordinate2D
        let maxDistance: CLLocationDistance

        private (set) var cachedMapItem: MKMapItem? {
            get {
                return PointOfInterestFinder.cache.object(forKey: cacheKey) as? MKMapItem
            }

            set {
                PointOfInterestFinder.cache.setObjectAsync(newValue as Any, forKey: cacheKey)
            }
        }

        var isCached: Bool {
            PointOfInterestFinder.cache.containsObject(forKey: cacheKey)
        }

        private lazy var cacheKey: String = {
            let key = String(format: "%@|%f,%f|%f", name, coordinate.latitude, coordinate.longitude, maxDistance)
            return Cache.digestString(of: key)
        }()

        init(name: String, coordinate: CLLocationCoordinate2D, maxDistance: CLLocationDistance) {
            self.name = name
            self.coordinate = coordinate
            self.maxDistance = maxDistance
        }

        func find(completionHandler: @escaping (MKMapItem?) -> Void) {
            if isCached {
                completionHandler(cachedMapItem)
                return
            }

            MKLocalSearch(request: request).start { [weak self] (response, error) in
                guard let self = self else { return }

                guard error == nil else {
                    completionHandler(nil)
                    return
                }

                var foundMapItem: MKMapItem?

                if let mapItem = response?.mapItems.first, self.isClose(mapItem) {
                    foundMapItem = mapItem
                }

                self.cachedMapItem = foundMapItem
                completionHandler(foundMapItem)
            }
        }

        private var request: MKLocalSearch.Request {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = name
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: maxDistance, longitudinalMeters: maxDistance)
            return request
        }

        private func isClose(_ mapItem: MKMapItem) -> Bool {
            guard let pointOfInterestLocation = mapItem.placemark.location else {
                return false
            }

            return pointOfInterestLocation.distance(from: location) <= maxDistance
        }

        private var location: CLLocation {
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}

struct Address: Decodable {
    let country: String?
    let prefecture: String?
    let distinct: String?
    let locality: String?
    let subLocality: String?
    let houseNumber: String?

    func format() -> String? {
        let components = [
            prefecture,
            distinct,
            locality,
            subLocality,
            houseNumber
        ].compactMap { $0 }

        guard !components.isEmpty else { return nil }

        return components.reduce(into: [] as [String]) { (components, currentComponent) in
            guard let previousComponent = components.last else {
                components.append(currentComponent)
                return
            }

            if previousComponent.last?.isNumber ?? false && currentComponent.first?.isNumber ?? false {
                components.append("-")
            } else {
                components.append(" ")
            }

            components.append(currentComponent)
        }.joined()
    }
}
