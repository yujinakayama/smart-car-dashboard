//
//  Defaults.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/09/13.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

struct Defaults {
    static var shared = Defaults()

    private let userDefaults = UserDefaults.standard

    enum Key: String {
        case raspberryPiAddress
        case cameraSensitivityMode
    }

    var raspberryPiAddress: String? {
        return userDefaults.string(forKey: Key.raspberryPiAddress.rawValue)
    }

    var cameraSensitivityMode: CameraOptionsAdjuster.SensitivityMode? {
        get {
            let integer = userDefaults.integer(forKey: Key.cameraSensitivityMode.rawValue)
            return CameraOptionsAdjuster.SensitivityMode(rawValue: integer)
        }

        set {
            userDefaults.setValue(newValue?.rawValue, forKey: Key.cameraSensitivityMode.rawValue)
        }
    }
}
