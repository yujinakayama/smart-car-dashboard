//
//  Vehicle.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/09.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

extension Notification.Name {
    static let VehicleDidConnect = Notification.Name("VehicleDidConnect")
    static let VehicleDidDisconnect = Notification.Name("VehicleDidDisconnect")
}

class Vehicle: NSObject {
    static let `default` = Vehicle()

    let etcDeviceManager = ETCDeviceManager()

    private lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.pausesLocationUpdatesAutomatically = false
        return locationManager
    }()

    var isMoving: Bool {
        let lastSpeedInKilometersPerHour = lastSpeed * 3600 / 1000
        return lastSpeedInKilometersPerHour >= 5
    }

    private var lastSpeed: CLLocationSpeed = 0

    override init() {
        super.init()

        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(self, selector: #selector(firebaseAuthenticationDidUpdateVehicleID), name: .FirebaseAuthenticationDidChangeVehicleID, object: nil)

        notificationCenter.addObserver(forName: .ETCDeviceManagerDidConnect, object: nil, queue: .main) { [weak self] (notification) in
            guard let self = self else { return }
            self.startTrackingSpeed()
            notificationCenter.post(name: .VehicleDidConnect, object: self)
        }

        notificationCenter.addObserver(forName: .ETCDeviceManagerDidDisconnect, object: nil, queue: .main) { [weak self] (notification) in
            guard let self = self else { return }
            self.stopTrackingSpeed()
            notificationCenter.post(name: .VehicleDidDisconnect, object: self)
        }
    }

    var isConnected: Bool {
        return etcDeviceManager.isConnected
    }

    func connect() {
        if Defaults.shared.isConnectionWithVehicleEnabled {
            etcDeviceManager.connect()
        }
    }

    @objc func firebaseAuthenticationDidUpdateVehicleID() {
        if let vehicleID = Firebase.shared.authentication.vehicleID {
            etcDeviceManager.database = ETCDatabase(vehicleID: vehicleID)
        } else {
            etcDeviceManager.database = nil
        }
    }

    private func startTrackingSpeed() {
        if !isConnected { return }

        logger.info()

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func stopTrackingSpeed() {
        logger.info()
        locationManager.stopUpdatingLocation()
        lastSpeed = 0
    }
}

extension Vehicle: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info(manager.authorizationStatus.rawValue)

        guard isConnected else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last,
              lastLocation.speedAccuracy >= 0
        else { return }

        lastSpeed = lastLocation.speed
    }
}
