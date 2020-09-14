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
    }

    var raspberryPiAddress: String? {
        return userDefaults.string(forKey: Key.raspberryPiAddress.rawValue)
    }
}
