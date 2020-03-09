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
        static let mapTypeForETCRoute = "mapTypeForETCRoute"
        static let mapTypeForDirections = "mapTypeForDirections"
        static let snapReceivedLocationToPointOfInterest = "snapReceivedLocationToPointOfInterest"
    }

    var mapTypeForETCRoute: MKMapType? {
        get {
            let integer = userDefaults.integer(forKey: Key.mapTypeForETCRoute)
            return MKMapType(rawValue: UInt(integer))
        }

        set {
            userDefaults.set(newValue?.rawValue, forKey: Key.mapTypeForETCRoute)
        }
    }

    var mapTypeForDirections: MKMapType? {
        get {
            let integer = userDefaults.integer(forKey: Key.mapTypeForDirections)
            return MKMapType(rawValue: UInt(integer))
        }
    }

    var snapReceivedLocationToPointOfInterest: Bool {
        get {
            return userDefaults.bool(forKey: Key.snapReceivedLocationToPointOfInterest)
        }
    }
}
