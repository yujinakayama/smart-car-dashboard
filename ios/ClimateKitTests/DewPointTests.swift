//
//  ClimateKitTests.swift
//  ClimateKitTests
//
//  Created by Yuji Nakayama on 2024/01/31.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import XCTest
@testable import ClimateKit

final class DewPointTests: XCTestCase {
    func testExample() throws {
        XCTAssertEqual(dewPointAt(temperature: -10, humidity: 1), -10)
        XCTAssertEqual(dewPointAt(temperature: 0, humidity: 1), 0)
        XCTAssertEqual(dewPointAt(temperature: 10, humidity: 1), 10)

        // https://bmcnoldy.earth.miami.edu/Humidity.html

        XCTAssertEqual(dewPointAt(temperature: -5, humidity: 0.10), -32.00, accuracy: 0.1)
        XCTAssertEqual(dewPointAt(temperature: -5, humidity: 0.50), -13.83, accuracy: 0.1)

        XCTAssertEqual(dewPointAt(temperature: 5, humidity: 0.10), -24.18, accuracy: 0.1)
        XCTAssertEqual(dewPointAt(temperature: 5, humidity: 0.50), -4.57, accuracy: 0.1)

        XCTAssertEqual(dewPointAt(temperature: 20, humidity: 0.10), -12.58, accuracy: 0.1)
        XCTAssertEqual(dewPointAt(temperature: 20, humidity: 0.50), 9.26, accuracy: 0.1)

        XCTAssertEqual(dewPointAt(temperature: 35, humidity: 0.10), -1.15, accuracy: 0.1)
        XCTAssertEqual(dewPointAt(temperature: 35, humidity: 0.50), 23.03, accuracy: 0.1)
    }
}
