//
//  Defaults.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/09/08.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit
import CoreMotion
import simd

struct Defaults {
    static var shared = Defaults()

    private let userDefaults = UserDefaults.standard

    private struct Key {
        static let mapTypeForETCRoute = "mapTypeForETCRoute"
        static let mapTypeForDirections = "mapTypeForDirections"
        static let automaticallyOpenUnopenedLocationWhenAppIsOpened = "automaticallyOpenUnopenedLocationWhenAppIsOpened"
        static let snapLocationToPointOfInterest = "snapLocationToPointOfInterest"
        static let mainETCCardUUID = "mainETCCardUUID"
        static let referenceAccelerationForGForceMeter = "referenceAccelerationForGForceMeter"
        static let unitOfGForceMeterScale = "unitOfGForceMeterScale"
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

    var automaticallyOpenUnopenedLocationWhenAppIsOpened: Bool {
        get {
            return userDefaults.bool(forKey: Key.automaticallyOpenUnopenedLocationWhenAppIsOpened)
        }
    }

    var snapLocationToPointOfInterest: Bool {
        get {
            return userDefaults.bool(forKey: Key.snapLocationToPointOfInterest)
        }
    }

    var mainETCCardUUID: UUID? {
        get {
            if let string = userDefaults.string(forKey: Key.mainETCCardUUID) {
                return UUID(uuidString: string)
            } else {
                return nil
            }
        }

        set {
            userDefaults.set(newValue?.uuidString, forKey: Key.mainETCCardUUID)
        }
    }

    var referenceAccelerationForGForceMeter: CMAcceleration? {
        get {
            guard let data = userDefaults.data(forKey: Key.referenceAccelerationForGForceMeter) else { return nil }
            guard let vector = try? JSONDecoder().decode(simd_double3.self, from: data) else { return nil }
            return CMAcceleration(vector)
        }

        set {
            var data: Data?

            if let acceleration = newValue {
                let vector = simd_double3(acceleration)
                data = try? JSONEncoder().encode(vector)
            }

            userDefaults.set(data, forKey: Key.referenceAccelerationForGForceMeter)
        }
    }

    var unitOfGForceMeterScale: CGFloat {
        get {
            return CGFloat(userDefaults.float(forKey: Key.unitOfGForceMeterScale))
        }
    }

    var verboseLogging: Bool {
        get {
            return userDefaults.bool(forKey: Key.verboseLogging)
        }
    }
}
