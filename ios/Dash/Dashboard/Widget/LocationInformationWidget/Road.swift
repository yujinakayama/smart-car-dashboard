//
//  RoadName.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/06/30.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MapboxCoreNavigation
import MapboxDirections

class Road: Equatable {
    static let nameComponentPattern = try! NSRegularExpression(pattern: "[^\\(\\)（）]+")

    let edge: RoadGraph.Edge.Metadata
    let placemark: CLPlacemark

    static func == (lhs: Road, rhs: Road) -> Bool {
        if let lhsPopularName = lhs.popularName {
            return lhsPopularName == rhs.popularName
        }

        if let lhsIdentifier = lhs.identifier {
            return lhsIdentifier == rhs.identifier
        }

        return lhs.roadClass == rhs.roadClass && lhs.routeNumber == rhs.routeNumber
    }

    init(edge: RoadGraph.Edge.Metadata, placemark: CLPlacemark) {
        self.edge = edge
        self.placemark = placemark
    }

    private var names: [String] {
        return edge.names.filter { $0.shield == nil }.map { $0.text }
    }

    private var shield: RoadShield? {
        for name in edge.names {
            if let shield = name.shield {
                return shield
            }
        }
        return nil
    }

    var roadClass: MapboxStreetsRoadClass {
        return edge.mapboxStreetsRoadClass
    }

    var routeNumber: Int? {
        guard let reference = shield?.displayRef else {
            return nil
        }
        return Int(reference)
    }

    var identifier: String? {
        guard let reference = shield?.displayRef else {
            return nil
        }

        if Int(reference) == nil {
            return reference
        } else {
            return nil
        }
    }

    var popularName: String? {
        return popularNames.first
    }

    var popularNames: [String] {
        let names = names.map { (name) -> [String] in
            let name = name.covertFullwidthAlphanumericsToHalfwidth()
            return Self.nameComponentPattern.matches(in: name).map { name[$0.range] }
        }.joined()

        return Array(names)
    }

    var canonicalRoadName: String? {
        if let identifier = identifier {
            return identifier
        }

        guard let routeNumber = routeNumber else { return nil }

        switch roadClass {
        case .trunk:
            return "国道\(routeNumber)号"
        case .primary, .secondary, .tertiary:
            // TODO: Roads having route number are mostly 都道府県道,
            //   but some 市道 that are considered 主要地方道 also have route number (e.g. 横浜市道環状2号).
            //   Handle those cases with the database: https://www.mlit.go.jp/notice/noticedata/sgml/1993/23015010/23015010.html
            let prefectureType = prefecture?.suffix ?? "都道府県"
            return "\(prefectureType)道\(routeNumber)号"
        default:
            return nil
        }
    }

    var unnumberedRouteName: String? {
        switch roadClass {
        case .motorway:
            return "自動専用道路"
        case .trunk:
            return "国道"
        case .primary, .secondary:
            let prefectureType = prefecture?.suffix ?? "都道府県"
            return "\(prefectureType)道"
        case .tertiary:
            return "\(municipality ?? "市町村")道"
        case .track:
            return "農道・林道"
        case .service:
            return "通路"
        case .motorwayLink:
            return "IC•JCT連絡路"
        case .trunkLink:
            return "国道連絡路"
        case .primaryLink, .secondaryLink:
            let prefectureType = prefecture?.suffix ?? "都道府県"
            return "\(prefectureType)道連絡路"
        case .tertiaryLink:
            return "\(municipality ?? "市町村")道連絡路"
        default:
            return "一般道路"
        }
    }

    var address: [String] {
        return [
            placemark.administrativeArea,
            placemark.locality,
            placemark.subLocality
        ].compactMap { $0 }
    }

    var prefecture: Prefecture? {
        guard let regionCode = edge.regionCode else {
            return nil
        }
        return prefecturesByRegionCode[regionCode]
    }

    var municipality: String? {
        guard let locality = placemark.locality else { return nil }

        if let match = try? /(.+市).+区/.wholeMatch(in: locality) {
            return String(match.output.1)
        } else {
            return locality
        }
    }
}

// https://ja.wikipedia.org/wiki/ISO_3166-2:JP
let prefecturesByRegionCode: [String: Prefecture] = [
    "01": .hokkaido,
    "02": .aomori,
    "03": .iwate,
    "04": .miyagi,
    "05": .akita,
    "06": .yamagata,
    "07": .fukushima,
    "08": .ibaraki,
    "09": .tochigi,
    "10": .gunma,
    "11": .saitama,
    "12": .chiba,
    "13": .tokyo,
    "14": .kanagawa,
    "15": .niigata,
    "16": .toyama,
    "17": .ishikawa,
    "18": .fukui,
    "19": .yamanashi,
    "20": .nagano,
    "21": .gifu,
    "22": .shizuoka,
    "23": .aichi,
    "24": .mie,
    "25": .shiga,
    "26": .kyoto,
    "27": .osaka,
    "28": .hyogo,
    "29": .nara,
    "30": .wakayama,
    "31": .tottori,
    "32": .shimane,
    "33": .okayama,
    "34": .hiroshima,
    "35": .yamaguchi,
    "36": .tokushima,
    "37": .kagawa,
    "38": .ehime,
    "39": .kochi,
    "40": .fukuoka,
    "41": .saga,
    "42": .nagasaki,
    "43": .kumamoto,
    "44": .oita,
    "45": .miyazaki,
    "46": .kagoshima,
    "47": .okinawa,
]

enum Prefecture: String {
    case hokkaido = "北海道"
    case aomori = "青森県"
    case iwate = "岩手県"
    case miyagi = "宮城県"
    case akita = "秋田県"
    case yamagata = "山形県"
    case fukushima = "福島県"
    case ibaraki = "茨城県"
    case tochigi = "栃木県"
    case gunma = "群馬県"
    case saitama = "埼玉県"
    case chiba = "千葉県"
    case tokyo = "東京都"
    case kanagawa = "神奈川県"
    case niigata = "新潟県"
    case toyama = "富山県"
    case ishikawa = "石川県"
    case fukui = "福井県"
    case yamanashi = "山梨県"
    case nagano = "長野県"
    case gifu = "岐阜県"
    case shizuoka = "静岡県"
    case aichi = "愛知県"
    case mie = "三重県"
    case shiga = "滋賀県"
    case kyoto = "京都府"
    case osaka = "大阪府"
    case hyogo = "兵庫県"
    case nara = "奈良県"
    case wakayama = "和歌山県"
    case tottori = "鳥取県"
    case shimane = "島根県"
    case okayama = "岡山県"
    case hiroshima = "広島県"
    case yamaguchi = "山口県"
    case tokushima = "徳島県"
    case kagawa = "香川県"
    case ehime = "愛媛県"
    case kochi = "高知県"
    case fukuoka = "福岡県"
    case saga = "佐賀県"
    case nagasaki = "長崎県"
    case kumamoto = "熊本県"
    case oita = "大分県"
    case miyazaki = "宮崎県"
    case kagoshima = "鹿児島県"
    case okinawa = "沖縄県"

    var suffix: String {
        return String(rawValue.last!)
    }
}

