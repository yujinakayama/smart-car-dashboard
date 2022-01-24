//
//  Parking.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/01/24.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

public protocol ParkingProtocol {
    var availability: Availability? { get }
    var capacityDescription: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
    var distance: CLLocationDistance { get }
    var isClosedNow: Bool? { get }
    var name: String { get }
    var openingHoursDescription: String? { get }
    var price: Int? { get }
    var priceDescription: String? { get }
    var rank: Int? { get }
    var reservation: Reservation? { get }
}

extension ParkingProtocol {
    public typealias Availability = PPPark.Availability
    public typealias Reservation = PPPark.Reservation
}
