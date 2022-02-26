//
//  TokyoDatumCoordinate2D.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/02/26.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

// https://simplesimples.com/web/markup/javascript/exchange_latlng_javascript/
struct TokyoDatumCoordinate2D {
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees

    init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(
            latitude: coordinate.latitude * 1.000106961 - coordinate.longitude * 0.000017467 - 0.004602017,
            longitude: coordinate.longitude * 1.000083049 + coordinate.latitude * 0.000046047 - 0.010041046
        )
    }

    var worldGeodeticSystemCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: latitude - latitude * 0.00010695 + longitude * 0.000017464 + 0.0046017,
            longitude: longitude - latitude * 0.000046038 - longitude * 0.000083043 + 0.010040
        )
    }
}
