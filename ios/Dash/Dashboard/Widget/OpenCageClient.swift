//
//  OpenCageClient.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/25.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

class OpenCageClient {
    let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D, completionHandler: @escaping (Result<Location, Error>) -> Void) {
        var urlComponents = URLComponents(string: "https://api.opencagedata.com/geocode/v1/json")!

        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "language", value: "native"),
            URLQueryItem(name: "no_annotations", value: "1"),
            URLQueryItem(name: "roadinfo", value: "1"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let task = URLSession.shared.dataTask(with: urlComponents.url!) { (data, response, error) in
            if let error = error {
                completionHandler(.failure(error))
                return
            }

            let result = Result<Location, Error>(catching: {
                let response = try JSONDecoder().decode(ReverseGeocodingResponse.self, from: data!)
                let address = response.results.first?.components
                let road = response.results.first?.annotations.roadinfo
                return (address: address, road: road)
            })

            completionHandler(result)
        }

        task.resume()
    }
}

extension OpenCageClient {
    typealias Location = (address: Address?, road: Road?)

    struct ReverseGeocodingResponse: Decodable {
        let results: [ReverseGeocodingResult]
    }

    struct ReverseGeocodingResult: Decodable {
        let annotations: ReverseGeocodingAnnotation
        let components: Address
    }

    struct ReverseGeocodingAnnotation: Decodable {
        let roadinfo: Road
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
        let popularName: String?
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

            if let popularName = try values.decodeIfPresent(String.self, forKey: .popularName), popularName != "unnamed road" {
                self.popularName = popularName
            } else {
                popularName = nil
            }

            numberOfLanes = try values.decodeIfPresent(Int.self, forKey: .numberOfLanes)

            do {
                routeNumber = try values.decodeIfPresent(Int.self, forKey: .roadReference)
                identifier = nil
            } catch {
                routeNumber = nil
                identifier = try? values.decodeIfPresent(String.self, forKey: .roadReference)
            }

            roadType = try values.decodeIfPresent(RoadType.self, forKey: .roadType)
            speedLimit = try values.decodeIfPresent(Int.self, forKey: .speedLimit)
            speedUnit = try values.decodeIfPresent(SpeedUnit.self, forKey: .speedUnit)
            surfaceType = try values.decodeIfPresent(String.self, forKey: .surfaceType)
        }
    }

    enum TrafficSide: String, Decodable {
        case leftHand = "left"
        case rightHand = "right"
    }

    // https://qiita.com/nyampire/items/7fa6efd944086aea820e
    enum RoadType: String, Decodable {
        case motorway // 高速道路
        case trunk // 国道
        case primary // 都道府県道
        case secondary // 都道府県道
        case tertiary // 市町村道
        case unclassified
        case residential
        case service
        case track
    }

    enum SpeedUnit: String, Decodable {
        case kilometersPerHour = "km/h"
        case milesPerHour = "mph"
    }

    struct Address: Decodable {
        let country: String?
        let postcode: String?
        private let state: String?
        let city: String?
        let suburb: String?
        let neighbourhood: String?

        var prefecture: String? {
            if let state = state {
                return state
            }

            // OpenCage doesn't return "東京都" for `state` property
            if let postcode = postcode, postcode.starts(with: "1") {
                return "東京都"
            }

            return nil
        }
    }
}
