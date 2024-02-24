//
//  DrivingLocation.swift
//  Dash
//
//  Created by Yuji Nakayama on 2024/02/24.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

class DrivingLocation {
    let road: Road
    let placemark: CLPlacemark

    lazy var address = Address(placemark: placemark)

    init(road: Road, placemark: CLPlacemark) {
        self.road = road
        self.placemark = placemark
    }

    var popularName: String? {
        if road.roadClass == .service {
            return placemark.name
        } else {
            return road.popularName
        }
    }

    var canonicalRoadName: String? {
        return road.canonicalName
    }

    var unnumberedRouteName: String? {
        switch road.roadClass {
        case .motorway:
            return "自動車専用道路"
        case .trunk, .trunkLink:
            return "国道"
        case .primary, .secondary, .primaryLink, .secondaryLink:
            return "\(road.prefecture?.name ?? "都道府県")道"
        case .tertiary, .tertiaryLink:
            return "\(address.municipality ?? "市町村")道"
        case .track:
            return "農道・林道"
        case .service:
            return "通路"
        case .motorwayLink:
            return "IC•JCT連絡路"
        default:
            return "一般道路"
        }
    }
}

extension DrivingLocation {
    struct Address {
        var placemark: CLPlacemark

        var prefecture: String? {
            return placemark.administrativeArea
        }

        var commandery: String? {
            return placemark.subAdministrativeArea
        }

        var municipality: String?

        var ward: String?

        var town: String? {
            return placemark.subLocality
        }

        var components: [String] {
            return [
                prefecture,
                commandery,
                municipality,
                ward,
                town
            ].compactMap { $0 }
        }

        init(placemark: CLPlacemark) {
            self.placemark = placemark
            parseLocality()
        }

        private mutating func parseLocality() {
            guard var locality = placemark.locality else { return }

            if let commandery = commandery {
                locality.trimPrefix(commandery)
            }

            if let match = try? /(.+市)(.+区)/.wholeMatch(in: locality) {
                municipality = String(match.output.1)
                ward = String(match.output.2)
            } else {
                municipality = locality
            }
        }
    }
}
