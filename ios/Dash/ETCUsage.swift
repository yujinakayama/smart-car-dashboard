//
//  ETCUsage.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/03.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

class ETCUsage: NSObject {
    var entranceRoadNumber: Int?
    var entranceTollboothNumber: Int?
    var exitRoadNumber: Int?
    var exitTollboothNumber: Int?
    var year: Int?
    var month: Int?
    var day: Int?
    var hour: Int?
    var minute: Int?
    var second: Int?
    var vehicleClassification: VehicleClassification?
    var paymentAmount: Int?

    var entranceTollbooth: Tollbooth? {
        return Tollbooth.findTollbooth(roadNumber: entranceRoadNumber, tollboothNumber: entranceTollboothNumber)
    }

    var exitTollbooth: Tollbooth? {
        return Tollbooth.findTollbooth(roadNumber: exitRoadNumber, tollboothNumber: exitTollboothNumber)
    }

    var date: Date? {
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: .gregorian)
        dateComponents.timeZone = TimeZone(identifier: "Asia/Tokyo")
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = second
        return dateComponents.date
    }

    init(
        entranceRoadNumber: Int?,
        entranceTollboothNumber: Int?,
        exitRoadNumber: Int?,
        exitTollboothNumber: Int?,
        year: Int?,
        month: Int?,
        day: Int?,
        hour: Int?,
        minute: Int?,
        second: Int?,
        vehicleClassification: VehicleClassification?,
        paymentAmount: Int?
    ) {
        self.entranceRoadNumber = entranceRoadNumber
        self.entranceTollboothNumber = entranceTollboothNumber
        self.exitRoadNumber = exitRoadNumber
        self.exitTollboothNumber = exitTollboothNumber
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.vehicleClassification = vehicleClassification
        self.paymentAmount = paymentAmount
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let usage = object as? ETCUsage else { return false }
        guard date != nil && usage.date != nil else { return false }
        return date == usage.date
    }
}

struct Tollbooth: Equatable {
    static var all: [Identifier: Tollbooth] = {
        var tollbooths: [Identifier: Tollbooth] = [:]

        loadCSV().forEach({ (values) in
            let tollbooth = makeTollbooth(values: values)
            if let tollbooth = tollbooth {
                tollbooths[tollbooth.identifier] = tollbooth
            }
        })

        return tollbooths
    }()

    static func findTollbooth(roadNumber: Int?, tollboothNumber: Int?) -> Tollbooth? {
        guard roadNumber != nil && tollboothNumber != nil else { return nil }
        let identifier = Identifier(roadNumber: roadNumber!, tollboothNumber: tollboothNumber!)
        return all[identifier]
    }

    private static func makeTollbooth(values: [String]) -> Tollbooth? {
        let roadNumber = Int(values[0])
        let tollboothNumber = Int(values[1])

        if roadNumber == nil || tollboothNumber == nil {
            return nil
        }

        let identifier = Identifier(roadNumber: roadNumber!, tollboothNumber: tollboothNumber!)
        let road = Road(name: values[2], routeName: values[3].isEmpty ? nil : values[3])
        let tollboothName = values[4]

        return Tollbooth(identifier: identifier, road: road, name: tollboothName)
    }

    static func loadCSV() -> [[String]] {
        let url = Bundle.main.url(forResource: "japan_etc_tollbooths", withExtension: "csv")!
        let csv = try! String(contentsOf: url)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        let listOfValues = lines.map { (line) in
            return line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
        }
        return listOfValues
    }

    let identifier: Identifier
    let road: Road
    let name: String

    init(identifier: Identifier, road: Road, name: String) {
        self.identifier = identifier
        self.road = road
        self.name = name
    }
}

extension Tollbooth {
    struct Identifier: Hashable {
        let roadNumber: Int
        let tollboothNumber: Int
    }
}

struct Road: Equatable {
    static let irregularAbbreviations = [
        "東名高速道路": "東名",
        "新東名高速道路": "新東名",
        "名神高速道路": "名神",
        "新名神高速道路": "新名神",
        "首都高速道路": "首都高",
        "首都圏中央連絡自動車道": "圏央道",
        "東京湾アクアライン": "アクアライン",
        "東京湾アクアライン連絡道": "アクア連絡道",
        "名古屋第二環状自動車道": "名二環",
    ]

    let name: String
    let routeName: String?

    var abbreviatedName: String {
        if let irregularAbbreviation = Road.irregularAbbreviations[name] {
            return irregularAbbreviation
        } else {
            return regularAbbreviation
        }
    }

    init(name: String, routeName: String? = nil) {
        self.name = name
        self.routeName = routeName
    }

    private var regularAbbreviation: String {
        var abbreviation = name

        if abbreviation.starts(with: "第") {
            abbreviation = abbreviation.replacingOccurrences(of: "高速道路|自動車道|道路", with: "", options: .regularExpression)
        }

        abbreviation = abbreviation
            .replacingOccurrences(of: "高速道路", with: "高速")
            .replacingOccurrences(of: "自動車道", with: "道")
            .replacingOccurrences(of: "道路", with: "道")
            .replacingOccurrences(of: "有料", with: "")

        return abbreviation
    }
}

// https://global.c-nexco.co.jp/en/navi/classifying/
enum VehicleClassification: Int {
    case light      = 5
    case standard   = 1
    case midSize    = 4
    case oversized  = 2
    case extraLarge = 3
}
