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

class Location: InboxItemProtocol {
    var firebaseDocument: DocumentReference?
    var identifier: String!

    let address: Address
    let categories: [PointOfInterestCategory]
    let coordinate: CLLocationCoordinate2D
    let name: String?
    let url: URL
    let websiteURL: URL?
    let creationDate: Date?
    var hasBeenOpened: Bool

    lazy var formattedAddress = address.format()

    var title: String? {
        return name
    }

    func open(from viewController: UIViewController) async {
        await openDirectionsInMaps()
    }

    func openDirectionsInMaps() async {
        await AppleMaps.shared.openDirections(
            to: mapItem,
            snappingToPointOfInterest: shouldBeSnappedToPointOfInterestInAppleMaps
        )
    }

    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        return mapItem
    }

    private var shouldBeSnappedToPointOfInterestInAppleMaps: Bool {
        guard Defaults.shared.snapLocationToPointOfInterest else {
            return false
        }

        return categories.allSatisfy { !$0.requiresAccurateCoordinate }
    }

    var googleMapsDirectionsURL: URL {
        // https://developers.google.com/maps/documentation/urls/get-started#directions-action
        var components = URLComponents(string: "https://www.google.com/maps/dir/?api=1")!
        components.queryItems?.append(URLQueryItem(name: "destination", value: "\(coordinate.latitude),\(coordinate.longitude)"))
        components.queryItems?.append(URLQueryItem(name: "travelmode", value: "driving"))
        return components.url!
    }

    var yahooCarNaviURL: URL {
        // https://note.com/yahoo_carnavi/n/n1d6b819a816c
        var components = URLComponents(string: "yjcarnavi://navi/select")!

        components.queryItems = [
            URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
            URLQueryItem(name: "lon", value: "\(coordinate.longitude)"),
            URLQueryItem(name: "name", value: name)
        ]

        return components.url!
    }
}

extension Location: Equatable, Hashable {
    static func == (lhs: Location, rhs: Location) -> Bool {
        return lhs.coordinate == rhs.coordinate && lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(name)
    }
}

extension Location {
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
}
