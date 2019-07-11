//
//  ETCUsageTests.swift
//  ETCTests
//
//  Created by Yuji Nakayama on 2019/06/03.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import XCTest

class ETCPaymentTests: XCTestCase {
    func testPayment() {
        let payment =  ETCPayment(
            entranceTollboothID: "12-137",
            exitTollboothID: "12-585",
            year: 2019,
            month: 5,
            day: 31,
            hour: 1,
            minute: 23,
            second: 56,
            vehicleClassification: VehicleClassification(rawValue: 1),
            amount: 650
        )

        XCTAssertEqual(payment.entranceTollbooth?.road.name, "首都高速道路")
        XCTAssertEqual(payment.entranceTollbooth?.road.abbreviatedName, "首都高")
        XCTAssertEqual(payment.entranceTollbooth?.road.routeName, "中央環状線")
        XCTAssertEqual(payment.entranceTollbooth?.name, "五反田")
        XCTAssertEqual(payment.exitTollbooth?.road.name, "首都高速道路")
        XCTAssertEqual(payment.exitTollbooth?.name, "台場")
        XCTAssertEqual(iso8601(payment.date!), "2019-05-31T01:23:56+09:00")
        XCTAssertEqual(payment.vehicleClassification, .standard)
    }

    func testTollbooth() {
        var tollbooth: Tollbooth?

        tollbooth = Tollbooth.findTollbooth(id: "04-049")
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
