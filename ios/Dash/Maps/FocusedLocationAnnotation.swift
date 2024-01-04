//
//  FocusedLocationAnnotation.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/22.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import MapKit

class FocusedLocationAnnotation: NSObject, PointOfInterestAnnotation {
    let location: Location

    init(_ location: Location) {
        self.location = location
        super.init()
    }
    
    var coordinate: CLLocationCoordinate2D {
        return location.coordinate
    }
    
    var title: String? {
        return location.name
    }
    
    var subtitle: String? {
        return nil
    }
}
