//
//  InboxLocation.swift
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

class InboxLocation: InboxItemProtocol, FullLocation {
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
}

extension InboxLocation: Equatable, Hashable {
    static func == (lhs: InboxLocation, rhs: InboxLocation) -> Bool {
        return lhs.coordinate == rhs.coordinate && lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(name)
    }
}