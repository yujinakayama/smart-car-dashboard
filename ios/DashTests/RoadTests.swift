//
//  RoadTests.swift
//  DashTests
//
//  Created by Yuji Nakayama on 2024/02/24.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import XCTest
import MapboxCoreNavigation
import MapboxDirections

final class RoadTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTomei() throws {
        // 35.515962, 139.49599
        let edge = MapboxCoreNavigation.RoadGraph.Edge.Metadata(
            heading: 229.0,
            length: 2232.0,
            roadClasses: [.toll, .motorway],
            mapboxStreetsRoadClass: MapboxDirections.MapboxStreetsRoadClass.motorway,
            speedLimit: Measurement(value: 99.999920000064, unit: .kilometersPerHour),
            speed: 22.22222222222222,
            isBridge: false,
            names: [
                MapboxCoreNavigation.RoadName(text: "E1", language: "", shield: Optional(MapboxCoreNavigation.RoadShield(baseUrl: "https://api.mapbox.com/styles/v1", displayRef: "E1", name: "default", textColor: "black"))),
                MapboxCoreNavigation.RoadName(text: "東名高速道路", language: "ja", shield: nil),
                MapboxCoreNavigation.RoadName(text: "Tomei Expressway", language: "en", shield: nil)
            ],
            laneCount: Optional(3),
            altitude: Optional(56.0),
            curvature: 1,
            countryCode: Optional("JP"),
            regionCode: Optional("14"),
            drivingSide: MapboxDirections.DrivingSide.left,
            directionality: MapboxCoreNavigation.RoadGraph.Edge.Directionality.oneWay,
            isUrban: true
        )

        let road = Road(edge: edge)
        XCTAssertEqual(road.popularName, "東名高速道路")
        XCTAssertEqual(road.canonicalName, "E1")
    }

    func testShutoExpresswayC2() throws {
        // 35.695996, 139.859849
        let edge = MapboxCoreNavigation.RoadGraph.Edge.Metadata(
            heading: 345.0,
            length: 1988.0,
            roadClasses: [.toll, .motorway],
            mapboxStreetsRoadClass: MapboxDirections.MapboxStreetsRoadClass.motorway,
            speedLimit: Measurement(value: 59.9999520000384, unit: .kilometersPerHour),
            speed: 16.666666666666668,
            isBridge: true,
            names: [
                MapboxCoreNavigation.RoadName(text: "C2", language: "", shield: Optional(MapboxCoreNavigation.RoadShield(baseUrl: "https://api.mapbox.com/styles/v1", displayRef: "C2", name: "default", textColor: "black"))),
                MapboxCoreNavigation.RoadName(text: "首都高速中央環状線", language: "ja", shield: nil),
                MapboxCoreNavigation.RoadName(text: "Central Circular Route", language: "en", shield: nil)
            ],
            laneCount: Optional(2),
            altitude: Optional(2.0),
            curvature: 1,
            countryCode: Optional("JP"),
            regionCode: Optional("13"),
            drivingSide: MapboxDirections.DrivingSide.left,
            directionality: MapboxCoreNavigation.RoadGraph.Edge.Directionality.oneWay,
            isUrban: true
        )

        let road = Road(edge: edge)
        XCTAssertEqual(road.popularName, "首都高速中央環状線")
        XCTAssertEqual(road.canonicalName, "C2")
    }


    func testRoadContainingCanonicalName() throws {
        // 38.728147, 140.636104
        let edge = MapboxCoreNavigation.RoadGraph.Edge.Metadata(
            heading: 117.0,
            length: 490.0,
            roadClasses: [],
            mapboxStreetsRoadClass: MapboxDirections.MapboxStreetsRoadClass.trunk,
            speedLimit: nil,
            speed: 12.5,
            isBridge: false,
            names: [
                MapboxCoreNavigation.RoadName(text: "47", language: "", shield: Optional(MapboxCoreNavigation.RoadShield(baseUrl: "https://api.mapbox.com/styles/v1", displayRef: "47", name: "default", textColor: "black"))),
                MapboxCoreNavigation.RoadName(text: "国道47号", language: "ja", shield: nil),
                MapboxCoreNavigation.RoadName(text: "National Highway Route 47", language: "en", shield: nil),
                MapboxCoreNavigation.RoadName(text: "一般国道47号", language: "", shield: nil)
            ],
            laneCount: Optional(1),
            altitude: Optional(296.0),
            curvature: 9,
            countryCode: Optional("JP"),
            regionCode: Optional("04"),
            drivingSide: MapboxDirections.DrivingSide.left,
            directionality: MapboxCoreNavigation.RoadGraph.Edge.Directionality.bothWays,
            isUrban: false
        )

        let road = Road(edge: edge)
        XCTAssertEqual(road.popularName, nil)
        XCTAssertEqual(road.canonicalName, "国道47号")
    }
}
