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
        static let snapLocationToPointOfInterest = "snapLocationToPointOfInterest"
        static let verboseLogging = "verboseLogging"
    }

    init() {
        loadDefaultValues()
    }

    private func loadDefaultValues() {
        let plistURL = Bundle.main.bundleURL.appendingPathComponent("Settings.bundle").appendingPathComponent("Root.plist")
        let rootDictionary = NSDictionary(contentsOf: plistURL)
        guard let preferences = rootDictionary?.object(forKey: "PreferenceSpecifiers") as? [[String: Any]] else { return }

        var defaultValues: [String: Any] = Dictionary()

        for preference in preferences {
            guard let key = preference["Key"] as? String else { continue }
            defaultValues[key] = preference["DefaultValue"]
        }

        userDefaults.register(defaults: defaultValues)
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

    var snapLocationToPointOfInterest: Bool {
        get {
            return userDefaults.bool(forKey: Key.snapLocationToPointOfInterest)
        }
    }

    var verboseLogging: Bool {
        get {
            return userDefaults.bool(forKey: Key.verboseLogging)
        }
    }
}
