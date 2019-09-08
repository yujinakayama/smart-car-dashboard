//
//  Defaults.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/09/08.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit

struct Defaults {
    static var shared = Defaults()

    private let userDefaults = UserDefaults.standard

    private struct Key {
        static let mapType = "mapType"
    }

    var mapType: MKMapType? {
        get {
            let integer = userDefaults.integer(forKey: Key.mapType)
            return MKMapType(rawValue: UInt(integer))
        }

        set {
            userDefaults.set(newValue?.rawValue, forKey: Key.mapType)
        }
    }
}
