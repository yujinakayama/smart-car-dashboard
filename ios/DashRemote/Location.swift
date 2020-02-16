//
//  Location.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/02/16.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import MapKit

class Location {
    let coordinate: CLLocationCoordinate2D
    let name: String?

    init(coordinate: CLLocationCoordinate2D, name: String?) {
        self.coordinate = coordinate
        self.name = name
    }

    func mapItem(completionHandler: @escaping (Result<MKMapItem, Error>) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let locale = Locale(identifier: "ja_JP")

        CLGeocoder().reverseGeocodeLocation(location, preferredLocale: locale) { (placemarks, error) in
            if let error = error {
                completionHandler(.failure(error))
                return
            }

            guard let placemark = placemarks?.first else {
                abort()
            }

            let mapItem = MKMapItem(placemark: MKPlacemark(placemark: placemark))
            mapItem.name = self.name
            completionHandler(.success(mapItem))
        }
    }

    var appleMapsURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!

        var queryItems = [URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)")]

        if let name = name {
            queryItems.append(URLQueryItem(name: "q", value: name))
        }

        components.queryItems = queryItems

        return components.url!
    }
}
