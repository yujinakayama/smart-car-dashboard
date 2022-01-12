//
//  AutoSoundVolumeLeveler.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/01/11.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

class SpeedSensitiveVolumeController: NSObject {
    private let volume = SystemAudioVolume()

    lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        return locationManager
    }()

    var additonalValuePerOneMeterPerSecond: Float

    var currentValue: Float {
        get {
            return volume.value
        }

        set {
            volume.setValue(newValue, withIndicator: false)
        }
    }

    var baseValue: Float?

    var lastSpeed: CLLocationSpeed?

    init(additonalValuePerOneMeterPerSecond: Float) {
        self.additonalValuePerOneMeterPerSecond = additonalValuePerOneMeterPerSecond
        super.init()
        volume.delegate = self
    }

    func start() {
        logger.info()
        volume.startObservingChangeByOthers()
        locationManager.startUpdatingLocation()
    }

    func stop() {
        logger.info()
        locationManager.stopUpdatingLocation()
    }

    func updateVolumeIfNeeded(speed: CLLocationSpeed) {
        if baseValue == nil {
            baseValue = calculateBaseValue(speed: speed)
        }

        guard let baseValue = baseValue else { return }
        let additionalValue = additionalValue(at: speed)
        currentValue = baseValue + additionalValue

        lastSpeed = speed
    }

    private func calculateBaseValue(speed: CLLocationSpeed) -> Float {
        return currentValue - additionalValue(at: speed)
    }

    private func additionalValue(at speed: CLLocationSpeed) -> Float {
        return additonalValuePerOneMeterPerSecond * Float(speed)
    }
}

extension SpeedSensitiveVolumeController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info(manager.authorizationStatus.rawValue)

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.speedAccuracy >= 0 else { return }
        updateVolumeIfNeeded(speed: location.speed)
    }
}

extension SpeedSensitiveVolumeController: SystemAudioVolumeDelegate {
    func systemAudioVolumeDidDetectChangeByOthers(_ systemAudioVolume: SystemAudioVolume) {
        guard let speed = lastSpeed else { return }
        baseValue = calculateBaseValue(speed: speed)
    }
}
