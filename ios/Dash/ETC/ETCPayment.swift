//
//  ETCPayment.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/03.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestoreSwift

struct ETCPayment: Codable {
    static let uuidNamespace = UUID(uuidString: "5EDBF18B-7031-4B90-92E3-6E67360A2472")!
    static let dateFormatter = ISO8601DateFormatter()

    var amount: Int
    var entranceDate: Date?
    var exitDate: Date
    var entranceTollboothID: String
    var exitTollboothID: String
    var vehicleClassification: VehicleClassification

    var uuid: UUID {
        // Do not include entranceDate to factor of the UUID
        // since payment data provided from ETC devices don't have it
        let data = [
            String(amount),
            Self.dateFormatter.string(from: exitDate),
            entranceTollboothID,
            exitTollboothID,
            String(vehicleClassification.rawValue)
        ].joined(separator: "|").data(using: .utf8)!

        return UUID(version: .v5, namespace: Self.uuidNamespace, name: data)
    }

    var entranceTollbooth: ETCTollbooth? {
        return ETCTollbooth.findTollbooth(id: entranceTollboothID)
    }

    var exitTollbooth: ETCTollbooth? {
        return ETCTollbooth.findTollbooth(id: exitTollboothID)
    }
}

extension ETCPayment {
    // https://global.c-nexco.co.jp/en/navi/classifying/
    enum VehicleClassification: Int, Codable {
        case light      = 5
        case standard   = 1
        case midSize    = 4
        case oversized  = 2
        case extraLarge = 3
    }
}
