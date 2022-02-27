//
//  Times.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/02/26.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit

class Times {
    static func searchParkings(within region: MKCoordinateRegion) async throws -> [Parking] {
        let request = URLRequest(url: url(for: region))
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(Response.self, from: data)

        guard let parkings = response.parkings else {
            throw TimesError.unknown
        }

        return parkings
    }

    static private func url(for region: MKCoordinateRegion) -> URL {
        var components = URLComponents(string: "https://times-info.net/view/teeda.ajax?component=service_bukService&action=ajaxGetMapBukIcon")!

        let northEast = TokyoDatumCoordinate2D(region.northEast)
        let southWest = TokyoDatumCoordinate2D(region.southWest)

        components.queryItems?.append(contentsOf: [
            URLQueryItem(name: "north", value: String(northEast.latitude)),
            URLQueryItem(name: "east", value: String(northEast.longitude)),
            URLQueryItem(name: "south", value: String(southWest.latitude)),
            URLQueryItem(name: "west", value: String(southWest.longitude)),
        ])

        return components.url!
    }
}

extension Times {
    struct Response: Decodable {
        var status: String
        var parkings: [Parking]?

        enum CodingKeys: String, CodingKey {
            case status
            case value
        }

        enum ValueCodingKeys: String, CodingKey {
            case parkings = "bukList"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            status = try container.decode(String.self, forKey: .status)

            if container.contains(.value) {
                let valueContainer = try container.nestedContainer(keyedBy: ValueCodingKeys.self, forKey: .value)
                parkings = try valueContainer.decodeIfPresent([Parking].self, forKey: .parkings)
            }
        }
    }
}

enum TimesError: Error {
    case unknown
    case invalidDistanceText
}

extension Times {
    struct Parking: Decodable {
        var availability: ParkingAvailability?
        var capacity: Int?
        var coordinate: CLLocationCoordinate2D
        var distance: CLLocationDistance
        var name: String

        enum CodingKeys: String, CodingKey {
            case attributeFlags = "icon"
            case capacity = "num"
            case distance = "dist"
            case latitude = "lat"
            case longitude = "lon"
            case name
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            if let attributeFlags = try values.decodeIfPresent(Int.self, forKey: .attributeFlags) {
                let attributes = Attributes(flags: attributeFlags)
                availability = attributes.availability?.normalized
            }

            capacity = try values.decodeIfPresent(Int.self, forKey: .capacity)

            if let distance = CLLocationDistance(try values.decode(String.self, forKey: .distance)) {
                self.distance = distance
            } else {
                throw TimesError.invalidDistanceText
            }

            let tokyoDatumCoordinate = TokyoDatumCoordinate2D(
                latitude: try values.decode(Double.self, forKey: .latitude),
                longitude: try values.decode(Double.self, forKey: .longitude)
            )
            coordinate = tokyoDatumCoordinate.worldGeodeticSystemCoordinate

            name = try values.decode(String.self, forKey: .name)
        }
    }

    struct Attributes {
        var flags: Int

        var availability: Availability? {
            return Availability(rawValue: flags & 7)
        }
    }

    enum Availability: Int {
        case vacant = 0
        case crowded = 1
        case full = 2

        var normalized: ParkingAvailability {
            switch self {
            case .vacant:
                return .vacant
            case .crowded:
                return .crowded
            case .full:
                return .full
            }
        }
    }
}

extension Times.Parking: ParkingProtocol {
    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = normalizedName
        return mapItem
    }

    var isClosedNow: Bool? { return nil }
    var openingHoursDescription: String? { return nil }
    var price: Int? { return nil }
    var priceDescription: String? { return nil }
    var rank: Int? { return nil }
    var reservation: Reservation? { return nil }
}

fileprivate extension MKCoordinateRegion {
    var northEast: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: center.latitude + span.latitudeDelta,
            longitude: center.longitude + span.longitudeDelta
        )
    }

    var southWest: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: center.latitude - span.latitudeDelta,
            longitude: center.longitude - span.longitudeDelta
        )
    }
}

/*
 {
   "bukUrl": "/P13-tokyo/C102/park-detail-BUK0049046/",
   "canMoneySimulation": true,
   "dist": "65",
   "feeText": "［全日］駐車後24時間　最大料金1500円｜通常料金 / 00:00-00:00 30分 310円",
   "hasMaxFee": true,
   "hasTokuteibiFee": false,
   "holidayInfo": null,
   "holidayMax": null,
   "holidayPrice": "",
   "icon": 1,
   "is24Hour": true,
   "lat": 35.668772,
   "lon": 139.765278,
   "name": "タイムズ東急プラザ銀座",
   "no": "BUK0049046",
   "num": 174,
   "specialdayInfo": null,
   "specialdayMax": null,
   "specialdayPrice": "",
   "weekdayInfo": "全日",
   "weekdayMax": "駐車後24時間　最大料金1500円",
   "weekdayPrice": "00:00-00:00 30分 310円"
 }
 */

/*
 Reverse engineered https://times-info.net/dynamic/js/apps/info/parking/map.js?20211223

 function getIconPath(flags: number, isSmartphone: boolean): string {
   var basePath = ""

   if (isSmartphone) {
     basePath = "/sp"
   }

   var availability = 7 & flags
   var isUnbranded = 1 & (flags >>>= 3)
   var isNewlyOpened = 1 & (flags >>>= 1)
   var isRunningMorePointReturnCampaign = 1 & (flags >>>= 1)
   var isAvailableForMotorbike = 1 & (flags >>>= 1)
   var isAvailableForBicycle = 1 & (flags >>>= 1)

   flags >>>= 1;

   for (var c = [], l = 0; l < 5; l++) {
       c[l] = 1 & flags
       flags >>>= 1
   }

   var extension = "png"

   var prefix = isUnbranded ? "ipn_" : "tims_"

   var basename = undefined

   if (!isUnbranded && c[0]) {
     basename = "star_"
     extension = "gif"
   } else if (!isUnbranded && isAvailableForMotorbike && isAvailableForBicycle) {
     basename = "bikecycle_"
   } else if (!isUnbranded && isAvailableForMotorbike) {
     basename = "bike_"
   } else if (!isUnbranded && isAvailableForBicycle) {
     basename = "cycle_"
   } else if (isNewlyOpened) {
     basename = "new_"
     extension = "gif"
   } else if (isRunningMorePointReturnCampaign) {
     basename = "up_"
     extension = "gif"
   } else {
     basename = ""
   }

   return basePath + "/common/images/" + prefix + basename + ("0" + [2, 3, 4, 1, 1][availability]) + "." + extension
 }
 */
