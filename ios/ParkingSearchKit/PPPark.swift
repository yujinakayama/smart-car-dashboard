//
//  PPParkClient.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/02/27.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

public class PPPark {
    let clientKey: String

    init(clientKey: String) {
        self.clientKey = clientKey
    }

    func searchParkings(around coordinate: CLLocationCoordinate2D, entranceDate: Date, exitDate: Date) async throws -> [Parking] {
        var request = URLRequest(url: URL(string: "https://api.pppark.com/search_v1.1")!)
        request.httpMethod = "POST"
        request.httpBody = requestBody(coordinate: coordinate, entranceDate: entranceDate, exitDate: exitDate)
        request.addValue("https://pppark.com/", forHTTPHeaderField: "Referer")

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(Response.self, from: data)

        if let error = response.error {
            throw error
        }

        return response.parkings ?? []
    }

    private func requestBody(coordinate: CLLocationCoordinate2D, entranceDate: Date, exitDate: Date) -> Data {
        let parameters: [String: String] = [
            "inDate": dateFormatter.string(from: entranceDate),
            "inTime": timeFormatter.string(from: entranceDate),
            "outDate": dateFormatter.string(from: exitDate),
            "outTime": timeFormatter.string(from: exitDate),
            "lat": String(coordinate.latitude),
            "lng": String(coordinate.longitude),
            "key": clientKey
        ]

        return parameters.map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)!
    }

    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

extension PPPark {
    struct Response: Decodable {
        var error: PPParkError?
        var parkings: [Parking]?

        enum CodingKeys: String, CodingKey {
            case error
            case result
        }

        enum ResultCodingKeys: String, CodingKey {
            case parkings
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            error = try values.decodeIfPresent(PPParkError.self, forKey: .error)

            if values.contains(.result) {
                let resultValues = try values.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result)
                parkings = try resultValues.decode([Parking].self, forKey: .parkings)
            }
        }
    }
}

struct PPParkError: Error, Decodable {
    var code: Int
    var message: String

    enum CodingKeys: String, CodingKey {
        case code
        case message = "str"
    }
}

extension PPPark {
    public struct Parking: ParkingProtocol, Decodable {
        public var address: String
        public var availability: Availability?
        public var capacityDescription: String?
        public var coordinate: CLLocationCoordinate2D
        public var distance: CLLocationDistance
        public var isClosedNow: Bool?
        public var name: String
        public var openingHoursDescription: String?
        public var price: Int?
        public var priceDescription: String?
        public var priceGap: Int?
        public var rank: Int?
        public var reservation: Reservation?

        enum CodingKeys: String, CodingKey {
            case address
            case availability = "fv"
            case capacityDescription = "capacity"
            case distance
            case isClosedNow = "closed"
            case lat
            case lng
            case name
            case openingHoursDescription = "openhour"
            case price
            case priceDescription = "pricestr"
            case priceGap = "pricegap"
            case rank
            case reservation = "rsv"
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            address = try values.decode(String.self, forKey: .address)
            availability = try values.decodeIfPresent(Availability.self, forKey: .availability)
            capacityDescription = try values.decodeIfPresent(String.self, forKey: .capacityDescription)
            distance = try values.decode(Double.self, forKey: .distance)
            isClosedNow = try values.decode(Int.self, forKey: .isClosedNow) != 0

            coordinate = CLLocationCoordinate2D(
                latitude: try values.decode(Double.self, forKey: .lat),
                longitude: try values.decode(Double.self, forKey: .lng)
            )

            name = try values.decode(String.self, forKey: .name)
            openingHoursDescription = try values.decodeIfPresent(String.self, forKey: .openingHoursDescription)
            price = try values.decodeIfPresent(Int.self, forKey: .price)
            priceDescription = try values.decodeIfPresent(String.self, forKey: .priceDescription)
            priceGap = try values.decodeIfPresent(Int.self, forKey: .priceGap)
            rank = try values.decodeIfPresent(Int.self, forKey: .rank)
            reservation = try values.decodeIfPresent(Reservation.self, forKey: .reservation)
        }

        public var mapItem: MKMapItem {
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = normalizedName
            return mapItem
        }
    }
}

extension PPPark {
    public struct Availability: Decodable {
        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
            return formatter
        }()

        public var lastUpdateDate: Date?
        public var status: AvailabilityStatus?

        enum CodingKeys: String, CodingKey {
            case status
            case lastUpdateDate = "last"
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            if let lastUpdateDateString = try values.decodeIfPresent(String.self, forKey: .lastUpdateDate) {
                lastUpdateDate = Self.dateFormatter.date(from: lastUpdateDateString)!
            }

            if let statusRawValue = try values.decodeIfPresent(Int.self, forKey: .status) {
                status = AvailabilityStatus(rawValue: statusRawValue) ?? .unsupported
            }
        }
    }

    public enum AvailabilityStatus: Int, Decodable {
        case unsupported = -1
        case vacant = 0
        case crowded = 1
        case full = 2
        case closed = 7
    }
}

extension PPPark {
    public struct Reservation: Decodable {
        public var provider: String
        public var status: ReservationStatus?
        public var url: URL?

        enum CodingKeys: String, CodingKey {
            case provider
            case status
            case url
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            provider = try values.decode(String.self, forKey: .provider)

            if let statusRawValue = try values.decodeIfPresent(Int.self, forKey: .status) {
                status = ReservationStatus(rawValue: statusRawValue) ?? .unsupported
            }

            url = try values.decodeIfPresent(URL.self, forKey: .url)
        }
    }

    public enum ReservationStatus: Int, Decodable {
        case unsupported = -1
        case vacant = 1
        case full = 2
        case unknown = 3
    }
}
