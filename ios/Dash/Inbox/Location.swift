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

class Location: SharedItemProtocol {
    var firebaseDocument: DocumentReference?
    var identifier: String!

    let address: Address
    let coordinate: Coordinate
    let name: String?
    let url: URL
    let websiteURL: URL?
    let creationDate: Date?
    var hasBeenOpened: Bool

    lazy var formattedAddress = address.format()

    func open() {
        markAsOpened()

        if Defaults.shared.snapReceivedLocationToPointOfInterest {
            findCorrespondingPointOfInterest() { (pointOfInterest) in
                if let pointOfInterest = pointOfInterest {
                    self.openDirectionsInMaps(destination: pointOfInterest)
                } else {
                    self.openDirectionsInMaps(destination: self.mapItem)
                }
            }
        } else {
            openDirectionsInMaps(destination: mapItem)
        }
    }

    private func findCorrespondingPointOfInterest(completionHandler: @escaping (MKMapItem?) -> Void) {
        guard let name = name else {
            completionHandler(nil)
            return
        }

        let finder = PointOfInterestFinder(name: name, coordinate: coordinate.clLocationCoordinate2D, maxDistance: 50)
        finder.findPointOfInterest(completionHandler: completionHandler)
    }

    private func openDirectionsInMaps(destination: MKMapItem) {
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
            MKLaunchOptionsMapTypeKey: Defaults.shared.mapTypeForDirections?.rawValue ?? MKMapType.standard
        ])
    }

    private var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate.clLocationCoordinate2D)

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        return mapItem
    }

    class PointOfInterestFinder {
        let name: String
        let coordinate: CLLocationCoordinate2D
        let maxDistance: CLLocationDistance

        init(name: String, coordinate: CLLocationCoordinate2D, maxDistance: CLLocationDistance) {
            self.name = name
            self.coordinate = coordinate
            self.maxDistance = maxDistance
        }

        func findPointOfInterest(completionHandler: @escaping (MKMapItem?) -> Void) {
            MKLocalSearch(request: request).start { (response, error) in
                guard let pointOfInterest = response?.mapItems.first else {
                    completionHandler(nil)
                    return
                }

                if self.isClose(pointOfInterest) {
                    completionHandler(pointOfInterest)
                } else {
                    completionHandler(nil)
                }
            }
        }

        private var request: MKLocalSearch.Request {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = name
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: maxDistance, longitudinalMeters: maxDistance)
            return request
        }

        private func isClose(_ pointOfInterest: MKMapItem) -> Bool {
            guard let pointOfInterestLocation = pointOfInterest.placemark.location else {
                return false
            }

            print(pointOfInterestLocation.distance(from: location))

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

        return components.reduce(into: [] as [String]) { (components, component) in
            guard let lastComponent = components.last else {
                components.append(component)
                return
            }

            if lastComponent.last?.isNumber ?? false && component.first?.isNumber ?? false {
                components.append("-")
            } else {
                components.append(" ")
            }
            components.append(component)
        }.joined()
    }
}

struct Coordinate: Decodable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees

    var clLocationCoordinate2D: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
