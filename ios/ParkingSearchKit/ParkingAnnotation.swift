//
//  ParkingAnnotation.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/05/05.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import MapKit

class ParkingAnnotation: NSObject, MKAnnotation {
    let parking: ParkingProtocol

    init(_ parking: ParkingProtocol) {
        self.parking = parking
        super.init()
    }

    var coordinate: CLLocationCoordinate2D {
        return parking.coordinate
    }

    var title: String? {
        if isSelected {
            return titleForCallout
        } else {
            return titleForMap
        }
    }

    private var titleForMap: String {
        if let price = parking.price {
            return "¥\(price)"
        } else if parking.isClosedNow == true {
            return "営業時間外"
        } else if let reservation = parking.reservation {
            return reservation.provider
        } else {
            return parking.normalizedName
        }
    }

    private var titleForCallout: String {
        if let price = parking.price {
            return "¥\(price)"
        } else if parking.isClosedNow == true {
            return "営業時間外"
        } else {
            return "料金不明"
        }
    }

    var subtitle: String? {
        return nil
    }

    var isSelected = false
}
