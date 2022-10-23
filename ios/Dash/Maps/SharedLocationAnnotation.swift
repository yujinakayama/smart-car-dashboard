//
//  SharedLocationAnnotation.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/22.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import MapKit

class SharedLocationAnnotation: NSObject, PointOfInterestAnnotation {
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

    var categories: [PointOfInterestCategory] {
        return location.categories
    }

    var mapItem: MKMapItem {
        return location.mapItem
    }

    func markAsOpened(_ value: Bool) {
        location.markAsOpened(value)
    }

    func openDirectionsInMaps() async {
        await location.openDirectionsInMaps()
    }
}
