//
//  ETCMessageTests.swift
//  DashTests
//
//  Created by Yuji Nakayama on 2019/06/18.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import XCTest

class ETCMessageTests: XCTestCase {
    func testMakeMockMessage() {
        XCTAssertEqual(try! ETCMessageFromDevice.HandshakeAcknowledgement.makeMockMessage().bytes, [0xF0, 0x0D])
        XCTAssertEqual(try! ETCMessageFromDevice.HandshakeRequest.makeMockMessage().bytes, [0x01, 0xC2, 0x30, 0x46, 0x32, 0x0D])
    }
}
