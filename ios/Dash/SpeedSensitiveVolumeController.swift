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
        locationManager.pausesLocationUpdatesAutomatically = false
        return locationManager
    }()

    var isStarted = false

    var additonalValuePerOneMeterPerSecond: Float
    var minimumSpeedForAdditionalVolume: CLLocationSpeed

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

    init(additonalValuePerOneMeterPerSecond: Float, minimumSpeedForAdditionalVolume: CLLocationSpeed) {
        self.additonalValuePerOneMeterPerSecond = additonalValuePerOneMeterPerSecond
        self.minimumSpeedForAdditionalVolume = minimumSpeedForAdditionalVolume
        super.init()
        volume.delegate = self
    }

    func start() {
        logger.info()

        isStarted = true

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            actuallyStart()
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func actuallyStart() {
        locationManager.startUpdatingLocation()
        volume.startObserving()
    }

    func stop(resetToBaseValue: Bool) {
        logger.info()

        volume.stopObserving()
        locationManager.stopUpdatingLocation()

        baseValue = nil
        lastSpeed = nil
    }

    func updateVolume(speed: CLLocationSpeed) {
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
        var effectiveSpeed = (speed - minimumSpeedForAdditionalVolume)

        if effectiveSpeed < 0 {
            effectiveSpeed = 0
        }

        return additonalValuePerOneMeterPerSecond * Float(effectiveSpeed)
    }
}

extension SpeedSensitiveVolumeController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info(manager.authorizationStatus.rawValue)

        guard isStarted else { return  }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            actuallyStart()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isStarted, let location = locations.last, location.speedAccuracy >= 0 else { return }
        updateVolume(speed: location.speed)
    }
}

extension SpeedSensitiveVolumeController: SystemAudioVolumeDelegate {
    func systemAudioVolumeDidDetectChangeByOthers(_ systemAudioVolume: SystemAudioVolume) {
        guard let speed = lastSpeed else { return }
        baseValue = calculateBaseValue(speed: speed)
    }
}
