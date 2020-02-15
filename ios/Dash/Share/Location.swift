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

    let address: Address
    let coordinate: Coordinate
    let name: String?
    let url: URL
    let websiteURL: URL?
    let creationDate: Date?

    lazy var formattedAddress = address.format()

    func open() {
        if Defaults.shared.snapReceivedLocationToPointOfInterest {
            findPointOfInterest() { (pointOfInterest) in
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

    private func findPointOfInterest(completionHandler: @escaping (MKMapItem?) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.region = MKCoordinateRegion(center: coordinate.clLocationCoordinate2D, latitudinalMeters: 20, longitudinalMeters: 20)

        MKLocalSearch(request: request).start { (response, error) in
            completionHandler(response?.mapItems.first)
        }
    }

    private func openDirectionsInMaps(destination: MKMapItem) {
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate.clLocationCoordinate2D)

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        return mapItem
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
            if components.last?.last?.isNumber ?? false && component.first?.isNumber ?? false {
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
