//
//  LocationTracker.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/11/21.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MusicKit

class LocationTracker: NSObject {
    static let shared = LocationTracker()

    // horizontalAccuracy returns fixed value 65.0 in reinforced concrete buildings, which is unstable
    static let unreliableHorizontalAccuracy: CLLocationAccuracy = 65

    var currentTrack: Track?

    var isTracking: Bool {
        return currentTrack != nil
    }

    private lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 3
        return locationManager
    }()

    func startTracking() {
        if isTracking { return }

        logger.info()

        currentTrack = Track()

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            actuallyStartTracking()
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func actuallyStartTracking() {
        locationManager.startUpdatingLocation()
        NotificationCenter.default.post(name: .LocationTrackerDidStartTracking, object: self)
    }

    func stopTracking() {
        guard isTracking else { return }

        logger.info()

        locationManager.stopUpdatingLocation()
        currentTrack = nil

        NotificationCenter.default.post(name: .LocationTrackerDidStopTracking, object: self)
    }

    private func considersLocationAccurate(_ location: CLLocation) -> Bool {
        return location.horizontalAccuracy < Self.unreliableHorizontalAccuracy
            && location.speedAccuracy >= 0
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info(manager.authorizationStatus.rawValue)

        guard isTracking else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            actuallyStartTracking()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentTrack = currentTrack else { return }
        let accurateLocations = locations.filter { considersLocationAccurate($0) }
        if accurateLocations.isEmpty { return }
        currentTrack.append(accurateLocations)

        NotificationCenter.default.post(name: .LocationTrackerDidUpdateCurrentTrack, object: self)
    }
}

extension LocationTracker {
    class Track {
        var coordinates: [CLLocationCoordinate2D] = {
            var array: [CLLocationCoordinate2D] = []
            array.reserveCapacity(1000)
            return array
        }()

        func append(_ locations: [CLLocation]) {
            let coordinates = locations.map { $0.coordinate }
            self.coordinates.append(contentsOf: coordinates)
        }
    }
}

extension Notification.Name {
    static let LocationTrackerDidStartTracking = Notification.Name("LocationTrackerDidStartTracking")
    static let LocationTrackerDidStopTracking = Notification.Name("LocationTrackerDidStopTracking")
    static let LocationTrackerDidUpdateCurrentTrack = Notification.Name("LocationTrackerDidUpdateCurrentTrack")
}
