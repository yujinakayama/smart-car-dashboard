//
//  MapKitParking.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/01/25.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import MapKit

struct MapKitParking {
    static let nonCarParkingNamePattern = try! NSRegularExpression(pattern: "駐輪|二輪|オートバイ|バイク|\\bバス(駐車場|プール)$|事務[所室]$")

    var mapItem: MKMapItem
    var distance: CLLocationDistance

    init(mapItem: MKMapItem, destination: CLLocationCoordinate2D) {
        self.mapItem = mapItem
        distance = mapItem.placemark.coordinate.distance(from: destination)
    }

    var isForCars: Bool {
        let isForCars = Self.nonCarParkingNamePattern.rangeOfFirstMatch(in: name).location == NSNotFound
        logger.debug("\(isForCars) \(name)")
        return isForCars
    }

    var detailLevel: Double {
        var level: Double = 0

        if mapItem.url != nil {
            level += 10
        }

        if mapItem.phoneNumber != nil {
            level += 1
        }

        if name.isEmpty || name == "駐車場" {
            level -= 100
        }

        return level
    }
}

extension MapKitParking: ParkingProtocol {
    var coordinate: CLLocationCoordinate2D {
        return mapItem.placemark.coordinate
    }

    var name: String {
        return mapItem.name ?? ""
    }

    var availability: Availability? { return nil }
    var capacityDescription: String? { return nil }
    var isClosedNow: Bool? { return nil }
    var openingHoursDescription: String? { return nil }
    var price: Int? { return nil }
    var priceDescription: String? { return nil }
    var rank: Int? { return nil }
    var reservation: Reservation? { return nil }
}

extension MapKitParking: Hashable {
    static func == (lhs: MapKitParking, rhs: MapKitParking) -> Bool {
        return lhs.mapItem == rhs.mapItem
    }
}
