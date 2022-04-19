//
//  OpenCage.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/25.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

class OpenCage {
    let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> Place {
        var urlComponents = URLComponents(string: "https://api.opencagedata.com/geocode/v1/json")!

        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "language", value: "native"),
            URLQueryItem(name: "no_annotations", value: "1"),
            URLQueryItem(name: "roadinfo", value: "1"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let (data, _) = try await urlSession.data(from: urlComponents.url!)

        let response = try JSONDecoder().decode(ReverseGeocodingResponse.self, from: data)
        let result = response.results.first!

        let address = result.components
        let region = result.bounds
        let road = result.annotations.roadinfo

        return (address: address, region: region, road: road)
    }

    private lazy var urlSession = URLSession(configuration: urlSessionConfiguration)

    private lazy var urlSessionConfiguration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.urlCache = nil
        return configuration
    }()

}

extension OpenCage {
    typealias Place = (address: Address, region: Region, road: Road?)

    struct ReverseGeocodingResponse: Decodable {
        let results: [ReverseGeocodingResult]
    }

    struct ReverseGeocodingResult: Decodable {
        enum CodingKeys: String, CodingKey {
            case annotations
            case bounds
            case components
        }

        let annotations: ReverseGeocodingAnnotation
        let bounds: Region
        let components: Address

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            annotations = try values.decode(ReverseGeocodingAnnotation.self, forKey: .annotations)
            bounds = try values.decode(Region.self, forKey: .bounds)
            components = try values.decode(Address.self, forKey: .components)
        }
    }

    struct ReverseGeocodingAnnotation: Decodable {
        static let nationWideRoadKeys = Set<Road.CodingKeys>([.trafficSide, .speedUnit])

        enum CodingKeys: String, CodingKey {
            case roadinfo
        }

        let roadinfo: Road?

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            let roadValues = try values.nestedContainer(keyedBy: Road.CodingKeys.self, forKey: .roadinfo)

            // OpenCage returns `drive_on` and `speed_in` values even in the sea
            if !Set(roadValues.allKeys).subtracting(Self.nationWideRoadKeys).isEmpty {
                roadinfo = try values.decode(Road.self, forKey: .roadinfo)
            } else {
                roadinfo = nil
            }
        }
    }

    struct Road: Decodable {
        enum CodingKeys: String, CodingKey {
            case trafficSide = "drive_on"
            case isOneWay = "oneway"
            case isTollRoad = "toll"
            case popularName = "road"
            case numberOfLanes = "lanes"
            case roadReference = "road_reference"
            case roadType = "road_type"
            case speedLimit = "maxspeed"
            case speedUnit = "speed_in"
            case surfaceType = "surface"
        }

        let trafficSide: TrafficSide?
        let isOneWay: Bool?
        let isTollRoad: Bool?
        let popularNames: [String]
        let numberOfLanes: Int?
        let routeNumber: Int? // e.g. 1 for Route 1
        let identifier: String? // e.g. "E1" for Tomei Expressway
        let roadType: RoadType?
        let speedLimit: Int?
        let speedUnit: SpeedUnit?
        let surfaceType: String?

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            trafficSide = try values.decodeIfPresent(TrafficSide.self, forKey: .trafficSide)
            isOneWay = try values.decodeIfPresent(String.self, forKey: .isOneWay).map { $0 == "yes" }
            isTollRoad = try values.decodeIfPresent(String.self, forKey: .isTollRoad).map { $0 == "yes" }

            if let popularNameText = try values.decodeIfPresent(String.self, forKey: .popularName), popularNameText != "unnamed road" {
                // Some roads have popular name property containing multiple names (e.g. "目黒通り;東京都道312号白金台町等々力線")
                popularNames = popularNameText.split(separator: ";").map { String($0) }
            } else {
                popularNames = []
            }

            numberOfLanes = try values.decodeIfPresent(Int.self, forKey: .numberOfLanes)

            if let referenceText = try? values.decodeIfPresent(String.self, forKey: .roadReference) {
                let references = referenceText.split(separator: ";").map({ String($0) })
                routeNumber = references.first { Int($0) != nil }.map { Int($0)! }
                identifier = references.first { Int($0) == nil }
            } else {
                identifier = nil
                routeNumber = nil
            }

            roadType = try? values.decodeIfPresent(RoadType.self, forKey: .roadType)
            speedLimit = try values.decodeIfPresent(Int.self, forKey: .speedLimit)
            speedUnit = try values.decodeIfPresent(SpeedUnit.self, forKey: .speedUnit)
            surfaceType = try values.decodeIfPresent(String.self, forKey: .surfaceType)
        }
    }

    enum TrafficSide: String, Decodable {
        case leftHand = "left"
        case rightHand = "right"
    }

    // https://wiki.openstreetmap.org/wiki/JA:Key:highway
    // https://qiita.com/nyampire/items/7fa6efd944086aea820e
    enum RoadType: String, Decodable {
        case motorway // 高速道路
        case trunk // 国道
        case primary // 主要地方道 (mostly 都道府県道 but some 市道 are included such as 横浜市道環状2号; mostly 2-digits route number)
        case secondary // 一般都道府県道 (3-digits route number)
        case tertiary // Mostly 市町村道 having popular name, but some 都道府県道 are included such as 東京都道441号線, which is a 特例都道
        case unclassified
        case residential
        case livingStreet = "living_street"
        case service
        case track
        case pedestrian
    }

    enum SpeedUnit: String, Decodable {
        case kilometersPerHour = "km/h"
        case milesPerHour = "mph"
    }

    struct Region: Decodable {
        static let earthCircumference: CLLocationDistance = 40000 * 1000
        static let degreesPerMeter: CLLocationDistance = 360 / earthCircumference

        enum CodingKeys: String, CodingKey {
            case northeast
            case southwest
        }

        let northeast: CLLocationCoordinate2D
        let southwest: CLLocationCoordinate2D

        let latitudeRange: ClosedRange<CLLocationDegrees>
        let longitudeRange: ClosedRange<CLLocationDegrees>

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            let northeast = try decodeCoordinate(from: values, forKey: .northeast)
            let southwest = try decodeCoordinate(from: values, forKey: .southwest)

            self.init(northeast: northeast, southwest: southwest)
        }

        init(northeast: CLLocationCoordinate2D, southwest: CLLocationCoordinate2D) {
            self.northeast = northeast
            self.southwest = southwest
            latitudeRange = southwest.latitude...northeast.latitude
            longitudeRange = southwest.longitude...northeast.longitude
        }

        func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
            return latitudeRange.contains(coordinate.latitude) && longitudeRange.contains(coordinate.longitude)
        }

        func extended(by distance: CLLocationDistance) -> Region {
            let newNortheast = CLLocationCoordinate2D(
                latitude: northeast.latitude + latitudeDelta(for: distance),
                longitude: northeast.longitude + longitudeDelta(for: distance, at: northeast)
            )

            let newSouthwest = CLLocationCoordinate2D(
                latitude: southwest.latitude - latitudeDelta(for: distance),
                longitude: southwest.longitude - longitudeDelta(for: distance, at: southwest)
            )

            return Region(
                northeast: newNortheast,
                southwest: newSouthwest
            )
        }

        private func latitudeDelta(for meters: CLLocationDistance) -> CLLocationDegrees {
            return meters * Self.degreesPerMeter
        }

        private func longitudeDelta(for meters: CLLocationDistance, at coordinate: CLLocationCoordinate2D) -> CLLocationDegrees {
            return meters * Self.degreesPerMeter / cos(coordinate.latitude * .pi / 180)
        }
    }

    // https://github.com/OpenCageData/address-formatting/blob/c379c9f/conf/components.yaml
    struct Address: Decodable {
        static let prefectureTypes = ["都", "道", "府", "県"]

        let country: String?
        let postcode: String?
        let state: String?
        let province: String?
        let city: String?
        let city_block: String?
        let county: String?
        let town: String?
        let suburb: String?
        let neighbourhood: String?
        let quarter: String?

        // 35.63755713321449, 139.7048284895448
        // "city"=>"目黒区",
        // "neighbourhood"=>"中目黒四丁目",

        // 36.05906586478792, 138.349589583782
        // "county"=>"南佐久郡",
        // "province"=>"長野県",
        // "state"=>"長野県",
        // "town"=>"佐久穂町",

        // 35.628379512272765, 139.79711613490383
        // "city"=>"江東区",
        // "city_block"=>"有明3",
        // "quarter"=>"有明",

        // 35.680786103826414, 139.75836050256484
        // "city"=>"千代田区",
        // "neighbourhood"=>"丸の内1",
        // "quarter"=>"皇居外苑",
        // "suburb"=>"神田",

        // 35.533175370219716, 139.69416757984942
        // "city"=>"川崎市",
        // "neighbourhood"=>"中幸町三丁目",
        // "province"=>"神奈川県",
        // "state"=>"神奈川県",
        // "suburb"=>"幸区",

        // https://github.com/OpenCageData/address-formatting/blob/c379c9f/conf/countries/worldwide.yaml#L1116-L1124
        var components: [String] {
            return [
                prefecture,
                city, county, town,
                [suburb, city_block, quarter].first { $0 != nil } ?? nil,
                neighbourhood
            ].compactMap { $0 }
        }

        var prefecture: String? {
            if let prefecture = state ?? province {
                return prefecture
            }

            // OpenCage doesn't return "東京都" for `state` property
            if let postcode = postcode, postcode.starts(with: "1") {
                return "東京都"
            }

            return nil
        }

        var prefectureType: String? {
            guard let lastCharacter = prefecture?.last else { return nil }

            let lastCharacterString = String(lastCharacter)

            if Self.prefectureTypes.contains(lastCharacterString) {
                return lastCharacterString
            } else {
                return nil
            }
        }
    }
}

fileprivate func decodeCoordinate<SuperKey: CodingKey>(from superContainer: KeyedDecodingContainer<SuperKey>, forKey superKey: SuperKey) throws -> CLLocationCoordinate2D {
    let container = try superContainer.nestedContainer(keyedBy: CoordinateCodingKeys.self, forKey: superKey)

    let latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
    let longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
}

fileprivate enum CoordinateCodingKeys: String, CodingKey {
    case latitude = "lat"
    case longitude = "lng"
}
