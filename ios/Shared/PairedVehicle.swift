//
//  PairedVehicle.swift
//  DashCloudKit
//
//  Created by Yuji Nakayama on 2020/10/31.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import KeychainAccess

extension Notification.Name {
    static let PairedVehicleDidChangeDefaultVehicleID = Notification.Name("PairedVehicleDidChangeDefaultVehicleID")
}

class PairedVehicle {
    enum Key: String {
        case defaultPairedVehicleID
    }

    static var defaultVehicleID: String? {
        get {
            return keychain[Key.defaultPairedVehicleID.rawValue]
        }

        set {
            if let vehicleID = newValue {
                try? keychain.set(vehicleID, key: Key.defaultPairedVehicleID.rawValue)
            } else {
                try? keychain.remove(Key.defaultPairedVehicleID.rawValue)
            }

            if newValue != defaultVehicleID {
                NotificationCenter.default.post(name: .PairedVehicleDidChangeDefaultVehicleID, object: nil)
            }
        }
    }

    static let keychain: Keychain = {
        let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as! String
        return Keychain(service: "com.yujinakayama.DashRemote", accessGroup: "\(appIdentifierPrefix)com.yujinakayama.DashRemote")
    }()
}
