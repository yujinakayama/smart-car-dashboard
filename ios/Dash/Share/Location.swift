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

struct Location: SharedItemProtocol {
    var firebaseDocument: DocumentReference?

    let coordinate: Coordinate
    let name: String?
    let url: URL
    let websiteURL: URL?
    let creationDate: Date?

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

struct Coordinate: Decodable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees

    var clLocationCoordinate2D: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
