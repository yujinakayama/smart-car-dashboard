//
//  MKMapFeatureAnnotationExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/10/23.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import MapKit

extension MKMapFeatureAnnotation: PointOfInterestAnnotation {
    var location: Location {
        .partial(MapFeatureAnnotationLocation(annotation: self))
    }
}

class MapFeatureAnnotationLocation: PartialLocation {
    let annotation: MKMapFeatureAnnotation

    init(annotation: MKMapFeatureAnnotation) {
        self.annotation = annotation
    }

    lazy var categories: [PointOfInterestCategory] = {
        if let mapKitCategory = annotation.pointOfInterestCategory {
            return [PointOfInterestCategory(mapKitCategory) ?? .unknown]
        } else {
            return []
        }
    }()

    var coordinate: CLLocationCoordinate2D {
        annotation.coordinate
    }
    
    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = annotation.title
        return mapItem
    }
    
    var name: String? {
        annotation.title
    }
    
    var fullLocation: FullLocation {
        get async throws {
            let request = MKMapItemRequest(mapFeatureAnnotation: annotation)
            let mapItem = try await request.mapItem
            return MapItemLocation(mapItem: mapItem)
        }
    }

    func openDirectionsInMaps() async {
        await AppleMaps.shared.openDirections(to: mapItem, snappingToPointOfInterest: true)
    }

    func markAsOpened(_ value: Bool) {
        // No-op
    }
}

class MapItemLocation: FullLocation {
    let mapItem: MKMapItem
    
    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
    }

    lazy var address = Address(placemark: mapItem.placemark)
    
    lazy var categories: [PointOfInterestCategory] = {
        if let mapKitCategory = mapItem.pointOfInterestCategory {
            return [PointOfInterestCategory(mapKitCategory) ?? .unknown]
        } else {
            return []
        }
    }()
    
    var coordinate: CLLocationCoordinate2D {
        mapItem.placemark.coordinate
    }
    
    var googleMapsURL: URL? {
        return nil
    }

    var name: String? {
        mapItem.name
    }
    
    var websiteURL: URL? {
        mapItem.url
    }

    func openDirectionsInMaps() async {
        AppleMaps.shared.openDirections(to: mapItem)
    }

    func markAsOpened(_ value: Bool) {
        // No-op
    }
}

extension Address {
    init(placemark: CLPlacemark) {
        country = placemark.country
        prefecture = placemark.administrativeArea
        distinct = nil
        locality = placemark.locality
        subLocality = placemark.thoroughfare
        houseNumber = placemark.subThoroughfare
    }
}
