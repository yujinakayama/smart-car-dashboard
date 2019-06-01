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
    var vehicleType: Int?
    var fee: Int?

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
}
