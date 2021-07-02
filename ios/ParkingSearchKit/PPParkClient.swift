//
//  PPParkClient.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/02/27.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

class PPParkClient {
    let clientKey: String

    init(clientKey: String) {
        self.clientKey = clientKey
    }

    func searchParkings(around coordinate: CLLocationCoordinate2D, entranceDate: Date, exitDate: Date, completion: @escaping (Result<[Parking], Error>) -> Void) -> URLSessionTask {
        var request = URLRequest(url: URL(string: "https://api.pppark.com/search_v1.1")!)
        request.httpMethod = "POST"
        request.httpBody = requestBody(coordinate: coordinate, entranceDate: entranceDate, exitDate: exitDate)
        request.addValue("https://pppark.com/", forHTTPHeaderField: "Referer")

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else { return }

            var response: PPParkResponse!

            do {
                response = try JSONDecoder().decode(PPParkResponse.self, from: data)
            } catch {
                completion(.failure(error))
                return
            }

            if let parkings = response.parkings {
                completion(.success(parkings))
            } else if let error = response.error {
                completion(.failure(error))
            }
        }

        task.resume()

        return task
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

struct PPParkResponse: Decodable {
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

struct PPParkError: Error, Decodable {
    var code: Int
    var message: String

    enum CodingKeys: String, CodingKey {
        case code
        case message = "str"
    }
}

public struct Parking: Decodable {
    var address: String
    var capacityDescription: String?
    var coordinate: CLLocationCoordinate2D
    var distance: CLLocationDistance
    var vacancyInfo: VacancyInfo?
    var isClosed: Bool
    var name: String
    var openingHoursDescription: String?
    var price: Int?
    var priceDescription: String?
    var priceGap: Int?
    var rank: Int?
    var reservationInfo: ReservationInfo?

    enum CodingKeys: String, CodingKey {
        case address
        case capacityDescription = "capacity"
        case distance
        case isClosed = "closed"
        case lat
        case lng
        case name
        case openingHoursDescription = "openhour"
        case price
        case priceDescription = "pricestr"
        case priceGap = "pricegap"
        case rank
        case reservationInfo = "rsv"
        case vacancyInfo = "fv"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        address = try values.decode(String.self, forKey: .address)
        capacityDescription = try values.decodeIfPresent(String.self, forKey: .capacityDescription)
        distance = try values.decode(Double.self, forKey: .distance)
        isClosed = try values.decode(Int.self, forKey: .isClosed) != 0

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
        reservationInfo = try values.decodeIfPresent(ReservationInfo.self, forKey: .reservationInfo)
        vacancyInfo = try values.decodeIfPresent(VacancyInfo.self, forKey: .vacancyInfo)
    }
}

extension Parking {
    struct VacancyInfo: Decodable {
        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
            return formatter
        }()

        var lastUpdateDate: Date?
        var status: VacancyStatus?

        enum CodingKeys: String, CodingKey {
            case status
            case lastUpdateDate = "last"
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            if let lastUpdateDateString = try values.decodeIfPresent(String.self, forKey: .lastUpdateDate) {
                lastUpdateDate = Self.dateFormatter.date(from: lastUpdateDateString)!
            }

            if let statusRawValue = try values.decodeIfPresent(Int.self, forKey: .status) {
                status = VacancyStatus(rawValue: statusRawValue) ?? .unsupported
            }
        }
    }

    enum VacancyStatus: Int, Decodable {
        case unsupported = -1
        case vacant = 0
        case crowded = 1
        case full = 2
        case closed = 7
    }
}

extension Parking {
    struct ReservationInfo: Decodable {
        var provider: String
        var status: ReservationStatus?
        var url: URL?

        enum CodingKeys: String, CodingKey {
            case provider
            case status
            case url
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            provider = try values.decode(String.self, forKey: .provider)

            if let statusRawValue = try values.decodeIfPresent(Int.self, forKey: .status) {
                status = ReservationStatus(rawValue: statusRawValue) ?? .unsupported
            }

            url = try values.decodeIfPresent(URL.self, forKey: .url)
        }
    }

    enum ReservationStatus: Int, Decodable {
        case unsupported = -1
        case vacant = 1
        case full = 2
        case unknown = 3
    }
}
