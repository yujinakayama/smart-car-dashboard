//
//  ParkingAnnotation.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/05/05.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import MapKit

class ParkingAnnotation: NSObject, MKAnnotation {
    let parking: Parking

    init(_ parking: Parking) {
        self.parking = parking
        super.init()
    }

    var coordinate: CLLocationCoordinate2D {
        return parking.coordinate
    }

    var title: String? {
        if let price = parking.price {
            return "¥\(price)"
        } else if parking.isClosed {
            return "営業時間外"
        } else {
            return "料金不明"
        }
    }

    var subtitle: String? {
        return parking.name
    }
}
