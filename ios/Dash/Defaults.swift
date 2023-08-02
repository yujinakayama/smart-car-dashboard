//
//  Defaults.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/09/08.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapKit
import FloatingViewKit
import CoreMotion
import simd
import XCGLogger

class Defaults {
    static var shared = Defaults()

    private let userDefaults = UserDefaults.standard

    private enum Key: String {
        case connectionWithVehicle
        case lastBackgroundEntranceTime
        case floatingWidgetPositionInRearviewWidget
        case locationInformationWidgetMode
        case mapTypeForETCRoute
        case automaticallyOpensUnopenedLocationWhenAppIsOpened
        case snapLocationToPointOfInterest
        case automaticallySearchParkingsWhenLocationIsAutomaticallyOpened
        case showTrackOnMaps
        case preferredMaxDistanceFromDestinationToParking
        case mainETCCardUUID
        case lastPendingETCGateEntranceDate
        case policyOfMostInterestingLandmarkDetection
        case forwardAngleOfMostInterestingLandmarkDetection
        case referenceAccelerationForGForceMeter
        case unitOfGForceMeterScale
        case pointerScalingBaseForVerticalAccelerationForGForceMeter
        case currentValueRatioForSmoothingInGForceMeter
        case showPeaksInGForceMeter
        case peakAngleResolutionForGForceMeter
        case peakExpirationDurationForGForceMeter
        case speedSensitiveVolumeControlEnabled
        case additionalVolumeAt120KilometersPerHour
        case minimumSpeedInKilometersPerHourForAdditionalVolume
        case logLevel
        case clearCachesOnNextLaunch
        case clearFirestoreOfflineCacheOnNextLaunch
    }

    init() {
        loadDefaultValues()
        userDefaults.removeObject(forKey: Key.mapTypeForETCRoute.rawValue)
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

    private func bool(for key: Key) -> Bool {
        return userDefaults.bool(forKey: key.rawValue)
    }

    private func set(_ value: Bool, for key: Key) {
        userDefaults.setValue(value, forKey: key.rawValue)
    }

    private func integer(for key: Key) -> Int {
        return userDefaults.integer(forKey: key.rawValue)
    }

    private func set(_ value: Int, for key: Key) {
        userDefaults.setValue(value, forKey: key.rawValue)
    }

    private func float(for key: Key) -> Float {
        return userDefaults.float(forKey: key.rawValue)
    }

    private func set(_ value: Float, for key: Key) {
        userDefaults.setValue(value, forKey: key.rawValue)
    }

    private func double(for key: Key) -> Double {
        return userDefaults.double(forKey: key.rawValue)
    }

    private func set(_ value: Double, for key: Key) {
        userDefaults.setValue(value, forKey: key.rawValue)
    }

    private func string(for key: Key) -> String? {
        return userDefaults.string(forKey: key.rawValue)
    }

    private func data(for key: Key) -> Data? {
        return userDefaults.data(forKey: key.rawValue)
    }

    private func object(for key: Key) -> Any? {
        return userDefaults.object(forKey: key.rawValue)
    }

    private func set(_ value: Any?, for key: Key) {
        userDefaults.setValue(value, forKey: key.rawValue)
    }
}

extension Defaults {
    var isConnectionWithVehicleEnabled: Bool {
        get {
            return bool(for: .connectionWithVehicle)
        }
    }

    var lastBackgroundEntranceTime: Date {
        get {
            let timeInterval = double(for: .lastBackgroundEntranceTime)
            return Date(timeIntervalSinceReferenceDate: timeInterval)
        }

        set {
            set(newValue.timeIntervalSinceReferenceDate, for: .lastBackgroundEntranceTime)
        }
    }

    var automaticallyOpensUnopenedLocationWhenAppIsOpened: Bool {
        get {
            return bool(for: .automaticallyOpensUnopenedLocationWhenAppIsOpened)
        }
    }

    var snapLocationToPointOfInterest: Bool {
        get {
            return bool(for: .snapLocationToPointOfInterest)
        }
    }

    var showTrackOnMaps: Bool {
        get {
            return bool(for: .showTrackOnMaps)
        }
    }

    var automaticallySearchParkingsWhenLocationIsAutomaticallyOpened: Bool {
        get {
            return bool(for: .automaticallySearchParkingsWhenLocationIsAutomaticallyOpened)
        }
    }

    var preferredMaxDistanceFromDestinationToParking: CLLocationDistance {
        get {
            return double(for: .preferredMaxDistanceFromDestinationToParking)
        }

        set {
            set(newValue, for: .preferredMaxDistanceFromDestinationToParking)
        }
    }

    var mainETCCardUUID: UUID? {
        get {
            if let string = string(for: .mainETCCardUUID) {
                return UUID(uuidString: string)
            } else {
                return nil
            }
        }

        set {
            set(newValue?.uuidString, for: .mainETCCardUUID)
        }
    }

    var lastPendingETCGateEntranceDate: Date? {
        get {
            return object(for: .lastPendingETCGateEntranceDate) as? Date
        }

        set {
            set(newValue, for: .lastPendingETCGateEntranceDate)
        }
    }

    var floatingWidgetPositionInRearviewWidget: FloatingPosition {
        get {
            let rawValue = integer(for: .floatingWidgetPositionInRearviewWidget)
            return .init(rawValue: rawValue) ?? .bottomLeft
        }

        set {
            set(newValue.rawValue, for: .floatingWidgetPositionInRearviewWidget)
        }
    }
    
    var locationInformationWidgetMode: LocationInformationWidgetViewController.LocationMode {
        get {
            let rawValue = integer(for: .locationInformationWidgetMode)
            return .init(rawValue: rawValue) ?? .address
        }

        set {
            set(newValue.rawValue, for: .locationInformationWidgetMode)
        }
    }

    var policyOfMostInterestingLandmarkDetection: LandmarkTracker.Policy {
        get {
            let rawValue = string(for: .policyOfMostInterestingLandmarkDetection)

            switch rawValue {
            case "nearest":
                return .nearest
            case "onlyForward":
                let forwardAngle = double(for: .forwardAngleOfMostInterestingLandmarkDetection)
                return .onlyForward(forwardAngle: forwardAngle)
            default:
                return .nearest
            }
        }

        set {
            set(newValue.description, for: .policyOfMostInterestingLandmarkDetection)

            if case .onlyForward(let forwardAngle) = newValue {
                set(forwardAngle, for: .forwardAngleOfMostInterestingLandmarkDetection)
            }
        }
    }
    
    var referenceAccelerationForGForceMeter: CMAcceleration? {
        get {
            guard let data = data(for: .referenceAccelerationForGForceMeter) else { return nil }
            guard let vector = try? JSONDecoder().decode(simd_double3.self, from: data) else { return nil }
            return CMAcceleration(vector)
        }

        set {
            var data: Data?

            if let acceleration = newValue {
                let vector = simd_double3(acceleration)
                data = try? JSONEncoder().encode(vector)
            }

            set(data, for: .referenceAccelerationForGForceMeter)
        }
    }

    var unitOfGForceMeterScale: CGFloat {
        get {
            return CGFloat(float(for: .unitOfGForceMeterScale))
        }
    }

    var pointerScalingBaseForVerticalAccelerationForGForceMeter: CGFloat? {
        get {
            let float = float(for: .pointerScalingBaseForVerticalAccelerationForGForceMeter)

            if float == 1 {
                return nil
            } else {
                return CGFloat(float)
            }
        }
    }

    var currentValueRatioForSmoothingInGForceMeter: Double {
        get {
            return double(for: .currentValueRatioForSmoothingInGForceMeter)
        }
    }

    var showPeaksInGForceMeter: Bool {
        get {
            return bool(for: Key.showPeaksInGForceMeter)
        }
    }

    var peakAngleResolutionForGForceMeter: Int {
        get {
            return integer(for: .peakAngleResolutionForGForceMeter)
        }
    }

    var peakExpirationDurationForGForceMeter: TimeInterval {
        get {
            return double(for: .peakExpirationDurationForGForceMeter)
        }
    }

    var isSpeedSensitiveVolumeControlEnabled: Bool {
        get {
            return bool(for: .speedSensitiveVolumeControlEnabled)
        }
    }

    var additonalVolumePerOneMeterPerSecond: Float {
        get {
            let additionalVolumeAt120KilometersPerHour = double(for: .additionalVolumeAt120KilometersPerHour)
            let speedDeltaInKilometersPerHour = 120 - double(for: .minimumSpeedInKilometersPerHourForAdditionalVolume)
            return Float(additionalVolumeAt120KilometersPerHour / speedDeltaInKilometersPerHour / 1000 * 60 * 60)
        }
    }

    var minimumSpeedForAdditionalVolume: CLLocationSpeed {
        get {
            let minimumSpeedInKilometersPerHourForAdditionalVolume = double(for: .minimumSpeedInKilometersPerHourForAdditionalVolume)
            return minimumSpeedInKilometersPerHourForAdditionalVolume * 1000 / (60 * 60)
        }
    }

    var logLevel: XCGLogger.Level {
        get {
            return XCGLogger.Level(rawValue: integer(for: .logLevel)) ?? .info
        }
    }

    var clearCachesOnNextLaunch: Bool {
        get {
            return bool(for: .clearCachesOnNextLaunch)
        }

        set {
            set(newValue, for: .clearCachesOnNextLaunch)
        }
    }
    
    var clearFirestoreOfflineCacheOnNextLaunch: Bool {
        get {
            return bool(for: .clearFirestoreOfflineCacheOnNextLaunch)
        }

        set {
            set(newValue, for: .clearFirestoreOfflineCacheOnNextLaunch)
        }
    }
}
