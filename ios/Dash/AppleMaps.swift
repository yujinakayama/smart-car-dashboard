//
//  AppleMaps.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/10/23.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

class AppleMaps {
    static let shared = AppleMaps()

    func openDirections(to destination: MKMapItem, snappingToPointOfInterest: Bool) async {
        if snappingToPointOfInterest {
            let foundMapItem = try? await findCorrespondingPointOfInterest(to: destination)
            openDirections(to: foundMapItem ?? destination)
        } else {
            openDirections(to: destination)
        }
    }

    private func openDirections(to destination: MKMapItem) {
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func findCorrespondingPointOfInterest(to mapItem: MKMapItem) async throws -> MKMapItem? {
        let pointOfInterestFinder = PointOfInterestFinder(name: mapItem.name ?? "", coordinate: mapItem.placemark.coordinate, maxDistance: 50)
        return try await pointOfInterestFinder.find()
    }
}

extension AppleMaps {
    class PointOfInterestFinder {
        // 10MB, 7 days
        static let cache = Cache(name: "PointOfInterestFinder", byteLimit: 10 * 1024 * 1024, ageLimit: 60 * 60 * 24 * 7) // 7 days

        let name: String
        let coordinate: CLLocationCoordinate2D
        let maxDistance: CLLocationDistance

        private (set) var cachedMapItem: MKMapItem? {
            get {
                return Self.cache.object(forKey: cacheKey) as? MKMapItem
            }

            set {
                Self.cache.setObject(newValue, forKey: cacheKey)
            }
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

        func find() async throws -> MKMapItem? {
            if let cachedMapItem = cachedMapItem {
                return cachedMapItem
            }

            let response = try await MKLocalSearch(request: request).start()

            if let mapItem = response.mapItems.first, isClose(mapItem) {
                cachedMapItem = mapItem
                return mapItem
            } else {
                return nil
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
