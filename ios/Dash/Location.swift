//
//  Location.swift
//  Dash
//
//  Created by Yuji Nakayama on 2023/07/24.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import MapKit

enum Location {
    case full(FullLocation)
    case partial(PartialLocation)
    
    var categories: [PointOfInterestCategory] {
        switch self {
        case .full(let location):
            return location.categories
        case .partial(let location):
            return location.categories
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .full(let location):
            return location.coordinate
        case .partial(let location):
            return location.coordinate
        }
    }

    var mapItem: MKMapItem {
        switch self {
        case .full(let location):
            return location.mapItem
        case .partial(let location):
            return location.mapItem
        }
    }

    var name: String? {
        switch self {
        case .full(let location):
            return location.name
        case .partial(let location):
            return location.name
        }
    }

    func openDirectionsInMaps() async {
        switch self {
        case .full(let location):
            await location.openDirectionsInMaps()
        case .partial(let location):
            await location.openDirectionsInMaps()
        }
    }

    func markAsOpened(_ value: Bool) {
        switch self {
        case .full(let location):
            location.markAsOpened(value)
        case .partial(let location):
            location.markAsOpened(value)
        }
    }
}

protocol FullLocation {
    var address: Address { get }
    var categories: [PointOfInterestCategory] { get }
    var coordinate: CLLocationCoordinate2D { get }
    var mapItem: MKMapItem { get }
    var name: String? { get }
    var websiteURL: URL? { get }

    func openDirectionsInMaps() async
    func markAsOpened(_ value: Bool)
}

protocol PartialLocation {
    var categories: [PointOfInterestCategory] { get }
    var coordinate: CLLocationCoordinate2D { get }
    var mapItem: MKMapItem { get }
    var name: String? { get }
    
    var fullLocation: FullLocation { get async throws }
    
    func openDirectionsInMaps() async
    func markAsOpened(_ value: Bool)
}

struct Address: Decodable {
    var country: String?
    var prefecture: String?
    var distinct: String?
    var locality: String?
    var subLocality: String?
    var houseNumber: String?
    
    func format() -> String? {
        let components = [
            prefecture,
            distinct,
            locality,
            subLocality,
            houseNumber
        ].compactMap { $0 }
        
        guard !components.isEmpty else { return nil }
        
        return components.reduce(into: [] as [String]) { (components, currentComponent) in
            guard let previousComponent = components.last else {
                components.append(currentComponent)
                return
            }
            
            if previousComponent.last?.isNumber ?? false && currentComponent.first?.isNumber ?? false {
                components.append("-")
            } else {
                components.append(" ")
            }
            
            components.append(currentComponent)
        }.joined()
    }
}

