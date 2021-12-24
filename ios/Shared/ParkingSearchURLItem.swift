//
//  ParkingSearchURLItem.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/06/02.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit

struct ParkingSearchURLItem {
    static let scheme = "dash"

    static let host = "parkingSearch"

    enum QueryParameterName: String {
        case name
        case latitude
        case longitude
        case appleMapsURL
    }

    var url: URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = Self.scheme
        urlComponents.host = Self.host

        urlComponents.queryItems = [
            URLQueryItem(name: QueryParameterName.name.rawValue, value: mapItem.name),
            URLQueryItem(name: QueryParameterName.latitude.rawValue, value: String(mapItem.placemark.coordinate.latitude)),
            URLQueryItem(name: QueryParameterName.longitude.rawValue, value: String(mapItem.placemark.coordinate.longitude)),
        ]

        return urlComponents.url!
    }

    var mapItem: MKMapItem

    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
    }

    init?(url: URL) {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
        guard urlComponents.scheme == Self.scheme, urlComponents.host == Self.host else { return nil }

        let query = Query(urlComponents: urlComponents)

        if let latitude = query.double(for: QueryParameterName.latitude.rawValue),
           let longitude = query.double(for: QueryParameterName.longitude.rawValue)
        {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let placemark = MKPlacemark(coordinate: coordinate)

            mapItem = MKMapItem(placemark: placemark)
            mapItem.name = query.string(for: QueryParameterName.name.rawValue)

            return
        }

        if let appleMapsURLString = query.string(for: QueryParameterName.appleMapsURL.rawValue),
           let appleMapsQuery = Query(urlString: appleMapsURLString),
           let llParameter = appleMapsQuery.string(for: "ll")
        {
            let latitudeLongitude = llParameter.components(separatedBy: ",").map { Double($0) }

            guard let latitude = latitudeLongitude.first?.flatMap({ $0 }),
                  let longitude = latitudeLongitude.last?.flatMap({ $0 })
            else { return nil }

            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let placemark = MKPlacemark(coordinate: coordinate)

            mapItem = MKMapItem(placemark: placemark)
            mapItem.name = appleMapsQuery.string(for: "q")

            return
        }

        return nil
    }

    class Query {
        let items: [URLQueryItem]

        lazy var dictionary: [String: String?] = {
            var dictionary: [String: String?] = [:]

            for item in items {
                dictionary[item.name] = item.value
            }

            return dictionary
        }()

        convenience init?(url: URL) {
            guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            self.init(urlComponents: urlComponents)
        }

        convenience init?(urlString: String) {
            guard let urlComponents = URLComponents(string: urlString) else { return nil }
            self.init(urlComponents: urlComponents)
        }

        init(urlComponents: URLComponents) {
            self.items = urlComponents.queryItems ?? []
        }

        func double(for key: String) -> Double? {
            guard let stringValue = dictionary[key]?.map({ $0 }) else { return nil }
            return Double(stringValue)
        }

        func string(for key: String) -> String? {
            return dictionary[key]?.map({ $0 })
        }

    }
}
