//
//  Location.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit

struct Location: SharedItemProtocol, Decodable {
    enum CodingKeys: String, CodingKey {
        case coordinate
        case name
        case url
        case webpageURL
    }

    enum CoordinateCodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    let coordinate: CLLocationCoordinate2D
    let name: String?
    let url: URL
    let webpageURL: URL?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        url = try values.decode(URL.self, forKey: .url)
        webpageURL = try values.decodeIfPresent(URL.self, forKey: .webpageURL)

        let coordinateValues = try values.nestedContainer(keyedBy: CoordinateCodingKeys.self, forKey: .coordinate)
        coordinate = CLLocationCoordinate2D(
            latitude: try coordinateValues.decode(Double.self, forKey: .latitude),
            longitude: try coordinateValues.decode(Double.self, forKey: .longitude)
        )
    }

    func open() {
        if Defaults.shared.snapReceivedLocationToPointOfInterest {
            findPointOfInterest() { (pointOfInterest) in
                if let pointOfInterest = pointOfInterest {
                    self.openDirectionsInMaps(destination: pointOfInterest)
                } else {
                    self.openDirectionsInMaps(destination: self.mapItem)
                }
            }
        } else {
            openDirectionsInMaps(destination: mapItem)
        }
    }

    private func findPointOfInterest(completionHandler: @escaping (MKMapItem?) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 20, longitudinalMeters: 20)

        MKLocalSearch(request: request).start { (response, error) in
            completionHandler(response?.mapItems.first)
        }
    }

    private func openDirectionsInMaps(destination: MKMapItem) {
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        return mapItem
    }
}
