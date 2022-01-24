//
//  CLLocationCoordinate2DExtension.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/01/25.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import CoreLocation

extension CLLocationCoordinate2D {
    func distance(from other: CLLocationCoordinate2D) -> CLLocationDistance {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let otherLocation = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location.distance(from: otherLocation)
    }
}
