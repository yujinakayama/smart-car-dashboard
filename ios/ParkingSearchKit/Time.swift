//
//  Time.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2022/01/26.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation

struct Time {
    static let min = Time(timeIntervalSinceMidnight: 0)
    static let max = Time(timeIntervalSinceMidnight: 60 * 60 * 24)

    var timeIntervalSinceMidnight: TimeInterval

    init(timeIntervalSinceMidnight: TimeInterval) {
        self.timeIntervalSinceMidnight = timeIntervalSinceMidnight
    }

    init(hour: Int, minute: Int) {
        timeIntervalSinceMidnight = TimeInterval(hour * 3600 + minute * 60)
    }

    var hour: Int {
        return Int(timeIntervalSinceMidnight / 3600)
    }

    var minute: Int {
        return Int(timeIntervalSinceMidnight) % 3600 / 60
    }
}

extension Time: Strideable {
    typealias Stride = TimeInterval

    func advanced(by n: Stride) -> Self {
        return Self(timeIntervalSinceMidnight: timeIntervalSinceMidnight + n)
    }

    func distance(to other: Self) -> Stride {
        return other.timeIntervalSinceMidnight - timeIntervalSinceMidnight
    }
}

extension Date {
    var time: Time {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: self)
        return Time(hour: components.hour!, minute: components.minute!)
    }
}
