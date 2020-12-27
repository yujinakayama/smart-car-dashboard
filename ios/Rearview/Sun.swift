//
//  Sun.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/11/05.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import Solar

protocol SunDelegate: NSObjectProtocol {
    func sun(_ sun: Sun, didChangeAppearance appearance: Sun.Appearance)
}

class Sun: NSObject, CLLocationManagerDelegate {
    enum Appearance {
        case day
        case night
    }

    weak var delegate: SunDelegate?

    var appearance: Appearance?

    let locationManager = CLLocationManager()
    private var location: CLLocation?

    private var appearanceChangeTimer: Timer?

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced

        NotificationCenter.default.addObserver(self, selector: #selector(update), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func startTrackingAppearance() {
        logger.info()

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func stopTrackingAppearance() {
        logger.info()
        locationManager.stopUpdatingLocation()
        appearance = nil
        location = nil
    }

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
        guard let location = locations.last else { return }
        self.location = location
        update()
    }

    @objc private func update() {
        logger.info()

        guard  let location = location else { return }
        guard let currentSolar = Solar(coordinate: location.coordinate) else { return }

        let previousAppearance = appearance
        let currentAppearance: Appearance = currentSolar.isDaytime ? .day : .night
        appearance = currentAppearance

        if currentAppearance != previousAppearance {
            delegate?.sun(self, didChangeAppearance: currentAppearance)
        }

        guard let nextAppearanceChangeDate = nextAppearanceChangeDate(at: location) else { return }
        logger.info("Next sun appearance change time: \(dateFormatter.string(from: nextAppearanceChangeDate))")
        appearanceChangeTimer?.invalidate()
        appearanceChangeTimer = Timer.scheduledTimer(
            timeInterval: nextAppearanceChangeDate.timeIntervalSinceNow,
            target: self,
            selector: #selector(update),
            userInfo: nil,
            repeats: false
        )
    }

    private func nextAppearanceChangeDate(at location: CLLocation) -> Date? {
        let currentTime = Date()

        let solars = [
            Solar(for: currentTime, coordinate: location.coordinate),
            Solar(for: currentTime + 60 * 60 * 24, coordinate: location.coordinate)
        ].compactMap { $0 }

        for solar in solars {
            if let sunrise = solar.sunrise, currentTime < sunrise {
                return sunrise
            }

            if let sunset = solar.sunset, currentTime < sunset {
                return sunset
            }
        }

        assertionFailure()
        return nil
    }
}
