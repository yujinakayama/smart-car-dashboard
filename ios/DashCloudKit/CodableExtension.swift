//
//  CLLocationCoordinate2DExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/05/21.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit

extension MKMapItem: Encodable {
    enum CodingKeys: String, CodingKey {
        case name
        case phoneNumber
        case placemark
        case pointOfInterestCategory
        case url
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(placemark, forKey: .placemark)
        try container.encode(pointOfInterestCategory?.rawValue, forKey: .pointOfInterestCategory)
        try container.encode(url?.absoluteString, forKey: .url)
    }
}

extension MKPlacemark: Encodable {
    enum CodingKeys: String, CodingKey {
        case coordinate
        case country
        case isoCountryCode
        case postalCode
        case administrativeArea
        case subAdministrativeArea
        case locality
        case subLocality
        case thoroughfare
        case subThoroughfare
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(country, forKey: .country)
        try container.encode(isoCountryCode, forKey: .isoCountryCode)
        try container.encode(postalCode, forKey: .postalCode)
        try container.encode(administrativeArea, forKey: .administrativeArea)
        try container.encode(subAdministrativeArea, forKey: .subAdministrativeArea)
        try container.encode(locality, forKey: .locality)
        try container.encode(subLocality, forKey: .subLocality)
        try container.encode(thoroughfare, forKey: .thoroughfare)
        try container.encode(subThoroughfare, forKey: .subThoroughfare)
    }
}

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public init(from decoder: Decoder) throws {
        self.init()

        let values = try decoder.container(keyedBy: CodingKeys.self)

        latitude = try values.decode(Double.self, forKey: .latitude)
        longitude = try values.decode(Double.self, forKey: .longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}
