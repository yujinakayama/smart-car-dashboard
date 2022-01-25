//
//  Parking.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/01/24.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

public protocol ParkingProtocol {
    var availability: Availability? { get }
    var capacityDescription: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
    var distance: CLLocationDistance { get }
    var isClosedNow: Bool? { get }
    var mapItem: MKMapItem { get }
    var name: String { get }
    var openingHoursDescription: String? { get }
    var price: Int? { get }
    var priceDescription: String? { get }
    var rank: Int? { get }
    var reservation: Reservation? { get }
}

public extension ParkingProtocol {
    var normalizedName: String {
        return name
            .covertFullwidthAlphanumericsToHalfwidth()
            .convertFullwidthWhitespacesToHalfwidth()
            .replacingOccurrences(of: "三井のリパーク", with: "リパーク")
            .replacingOccurrences(of: "東急(ライフィア|ライファ)", with: "", options: [.regularExpression])
            .trimmingCharacters(in: .whitespaces)
    }

    var nameFeature: String {
        return normalizedName
            .lowercased()
            .replacingOccurrences(of: "[\\(（【《].+?[\\)）】》]", with: "", options: [.regularExpression])
            .replacingOccurrences(of: "(駐車場|パーキング|parking)", with: "", options: [.regularExpression])
            .replacingOccurrences(of: "[ ・]", with: "", options: [.regularExpression])
    }

    var numbersInName: [Int] {
        nameFeature
            .components(separatedBy: .decimalDigits.inverted).compactMap { Int($0) }
    }

    var isOnStreet: Bool {
        name.contains("パーキングメーター") || name.contains("パーキングチケット")
    }
}

extension ParkingProtocol {
    public typealias Availability = PPPark.Availability
    public typealias Reservation = PPPark.Reservation
}
