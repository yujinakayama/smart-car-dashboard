//
//  AutoSoundVolumeLeveler.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/01/11.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MediaPlayer

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
            lastSetValue = newValue
        }
    }

    var baseValue: Float?

    private var lastSetValue: Float?

    init(additonalValuePerOneMeterPerSecond: Float) {
        self.additonalValuePerOneMeterPerSecond = additonalValuePerOneMeterPerSecond
        super.init()
    }

    func start() {
        logger.info()
        locationManager.startUpdatingLocation()
    }

    func stop() {
        logger.info()

        locationManager.stopUpdatingLocation()

        if let baseValue = baseValue {
            currentValue = baseValue
        }
    }

    func updateVolumeIfNeeded(speed: CLLocationSpeed) {
        let baseValue = resetBaseValueIfNeeded(speed: speed)
        let additionalValue = additionalValue(at: speed)
        currentValue = baseValue + additionalValue
    }

    private func resetBaseValueIfNeeded(speed: CLLocationSpeed) -> Float {
        if let baseValue = baseValue, !hasCurrentValueChangedByUser {
            return baseValue
        }

        let baseValue = currentValue - additionalValue(at: speed)
        self.baseValue = baseValue
        return baseValue
    }

    private func additionalValue(at speed: CLLocationSpeed) -> Float {
        return additonalValuePerOneMeterPerSecond * Float(speed)
    }

    var hasCurrentValueChangedByUser: Bool {
        guard let lastSetValue = lastSetValue else {
            return false
        }

        return currentValue != lastSetValue
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
        logger.info()
        guard let location = locations.last, location.speedAccuracy >= 0 else { return }
        updateVolumeIfNeeded(speed: location.speed)
    }
}

fileprivate class SystemAudioVolume {
    private let volumeView = MPVolumeView()

    init() {
        volumeView.frame = .init(x: -100, y: -100, width: 0, height: 0)
        volumeView.isHidden = true
        volumeView.isUserInteractionEnabled = false
        volumeView.setVolumeThumbImage(UIImage(), for: .normal)
        volumeView.setMinimumVolumeSliderImage(UIImage(), for: .normal)
        volumeView.setMaximumVolumeSliderImage(UIImage(), for: .normal)
    }

    deinit {
        volumeView.removeFromSuperview()
    }

    private(set) var value: Float {
        get {
            return privateVolumeSlider.value
        }

        set {
            privateVolumeSlider.value = newValue
        }
    }

    private lazy var privateVolumeSlider = volumeView.subviews.first { $0 is UISlider} as! UISlider

    func setValue(_ value: Float, withIndicator showIndicator: Bool = false) {
        setVolumeViewVisibility(!showIndicator)

        self.value = value

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setVolumeViewVisibility(false)
        }
    }

    private func setVolumeViewVisibility(_ visible: Bool) {
        if visible, volumeView.superview == nil {
            window?.addSubview(volumeView)
        }

        volumeView.isHidden = !visible
    }

    private var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes

        let foregroudScene = scenes.first { (scene) in
            scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive
        } as? UIWindowScene

        return foregroudScene?.keyWindow
    }
}
