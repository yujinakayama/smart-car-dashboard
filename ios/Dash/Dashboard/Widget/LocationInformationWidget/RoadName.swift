//
//  RoadName.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/06/30.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation

class RoadName: Equatable {
    let road: OpenCage.Road?
    let address: OpenCage.Address?

    static func == (lhs: RoadName, rhs: RoadName) -> Bool {
        guard let lhsRoad = lhs.road, let rhsRoad = rhs.road else { return false }

        if let lhsPopularName = lhs.popularName {
            return lhsPopularName == rhs.popularName
        }

        if let lhsIdentifier = lhsRoad.identifier {
            return lhsIdentifier == rhsRoad.identifier
        }

        return lhsRoad.roadType == rhsRoad.roadType && lhsRoad.routeNumber == rhsRoad.routeNumber
    }

    init(place: OpenCage.Place) {
        road = place.road
        address = place.address
    }

    var popularName: String? {
        return popularNames.first
    }

    var popularNames: [String] {
        guard let road = road else { return [] }

        let popularNames = road.popularNames.map { $0.covertFullwidthAlphanumericsToHalfwidth() }

        guard let routeNumber = road.routeNumber else { return popularNames }

        // Some roads have popular name only with route number (e.g. Popular name "123" for 国道123号),
        // which is redundant and meaningless.
        let redundantNames = [String(routeNumber), canonicalRoadName].compactMap { $0 }
        return popularNames.filter { !redundantNames.contains($0) }
    }

    var canonicalRoadName: String? {
        guard let road = road else { return nil }

        if let roadIdentifier = road.identifier {
            return roadIdentifier
        }

        guard let routeNumber = road.routeNumber else { return nil }

        switch road.roadType {
        case .trunk:
            return "国道\(routeNumber)号"
        case .primary, .secondary, .tertiary:
            // TODO: Roads having route number are mostly 都道府県道,
            //   but some 市道 that are considered 主要地方道 also have route number (e.g. 横浜市道環状2号).
            //   Handle those cases with the database: https://www.mlit.go.jp/notice/noticedata/sgml/1993/23015010/23015010.html
            let prefecture = address?.prefecture ?? "都道府県"
            return "\(prefecture)道\(routeNumber)号"
        default:
            return nil
        }
    }

    var unnumberedRouteName: String? {
        guard let road = road else { return nil }

        switch road.roadType {
        case .trunk:
            return "国道"
        case .primary, .secondary:
            let prefecture = address?.prefecture ?? "都道府県"
            return "\(prefecture)道"
        case .tertiary:
            let city = address?.city ?? "市町村"
            return "\(city)道"
        case .residential, .livingStreet:
            return "生活道路"
        case .track:
            return "農道・林道"
        default:
            return "一般道路"
        }
    }

    var constructionType: ConstructionType {
        guard let popularName = popularName else {
            return .road
        }

        if popularName.hasSuffix("トンネル") {
            return .tunnel
        }

        if popularName.hasSuffix("橋") || popularName.hasSuffix("ブリッジ") {
            return .bridge
        }

        return .road
    }
}

extension RoadName {
    enum ConstructionType {
        case road
        case bridge
        case tunnel
        case unknown
    }
}
