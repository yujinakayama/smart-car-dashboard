//
//  MKMapFeatureAnnotationExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/10/23.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import MapKit

extension MKMapFeatureAnnotation: PointOfInterestAnnotation {
    var categories: [PointOfInterestCategory] {
        if let mapKitCategory = pointOfInterestCategory,
           let category = PointOfInterestCategory(mapKitCategory)
        {
            return [category]
        } else {
            return []
        }
    }

    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = title
        return mapItem
    }

    func markAsOpened(_ value: Bool) {
        // No-op
    }

    func openDirectionsInMaps() async {
        await AppleMaps.shared.openDirections(to: mapItem, snappingToPointOfInterest: true)
    }
}

