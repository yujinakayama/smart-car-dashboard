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
            // In most cases the prefix 東急ライフィア doesn't appear in real world
            .replacingOccurrences(of: "東急(ライフィア|ライファ)", with: "", options: [.regularExpression])
            .trimmingCharacters(in: .whitespaces)
    }

    var nameFeature: String {
        return normalizedName
            // https://www.mec-p.co.jp/news/detail.php?id=111
            .replacingOccurrences(of: "三菱地所パークス|^PEN(?![A-Za-z])", with: "PARKS PARK", options: [.regularExpression])
            .replacingOccurrences(of: "[\\(（【《].+?[\\)）】》]", with: "", options: [.regularExpression])
            .replacingOccurrences(of: "(駐車場|パーキング|parking)", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "[ ・]", with: "", options: [.regularExpression])
            .lowercased()
    }

    var numbersInName: [Int] {
        nameFeature
            .components(separatedBy: .decimalDigits.inverted).compactMap { Int($0) }
    }

    var isNameUnknown: Bool {
        name.isEmpty || name == "駐車場"
    }

    var isParkingMeter: Bool {
        name.contains("パーキングメーター") || name.contains("パーキングチケット")
    }

    var isOnStreet: Bool {
        isParkingMeter
    }
}

extension ParkingProtocol {
    public typealias Availability = PPPark.Availability
    public typealias Reservation = PPPark.Reservation
}
