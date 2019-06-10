//
//  ETCUsageTests.swift
//  ETCTests
//
//  Created by Yuji Nakayama on 2019/06/03.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import XCTest

class ETCUsageTests: XCTestCase {
    func testUsage() {
        let usage =  ETCUsage(
            entranceRoadNumber: 12,
            entranceTollboothNumber: 137,
            exitRoadNumber: 12,
            exitTollboothNumber: 585,
            year: 2019,
            month: 5,
            day: 31,
            hour: 1,
            minute: 23,
            second: 56,
            vehicleType: 1,
            fee: 650
        )

        XCTAssertEqual(usage.entranceTollbooth?.road.name, "首都高速道路")
        XCTAssertEqual(usage.entranceTollbooth?.road.abbreviatedName, "首都高")
        XCTAssertEqual(usage.entranceTollbooth?.road.routeName, "中央環状線")
        XCTAssertEqual(usage.entranceTollbooth?.name, "五反田")
        XCTAssertEqual(usage.exitTollbooth?.road.name, "首都高速道路")
        XCTAssertEqual(usage.exitTollbooth?.name, "台場")
        XCTAssertEqual(iso8601(usage.date!), "2019-05-31T01:23:56+09:00")
    }

    func testTollbooth() {
        var tollbooth: Tollbooth?

        tollbooth = Tollbooth.findTollbooth(roadNumber: 4, tollboothNumber: 49)
        XCTAssertEqual(tollbooth?.name, "茅ヶ崎JCT")
        XCTAssertEqual(tollbooth?.road.name, "首都圏中央連絡自動車道")
        XCTAssertEqual(tollbooth?.road.abbreviatedName, "圏央道")
        XCTAssertEqual(tollbooth?.road.routeName, nil)
    }

    func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
}
