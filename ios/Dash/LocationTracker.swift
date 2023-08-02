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
import UIKit
import CacheKit
import SwiftCBOR

class LocationTracker: NSObject {
    static let shared = LocationTracker()

    // horizontalAccuracy returns fixed value 65.0 in reinforced concrete buildings, which is unstable
    private static let unreliableHorizontalAccuracy: CLLocationAccuracy = 65

    private static let currentTrackCacheKey = "currentTrack"

    var currentTrack: Track?

    var isTracking: Bool {
        return currentTrack != nil
    }

    private lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 3
        locationManager.pausesLocationUpdatesAutomatically = false
        return locationManager
    }()

    static let cache = Cache(name: "LocationTracker", byteLimit: 50 * 1024 * 1024, ageLimit: 24 * 60 * 60)

    override init() {
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }

    func startTracking() {
        if isTracking { return }

        logger.info()

        currentTrack = restoreCurrentTrackFromCache() ?? Track()

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

    @objc private func applicationWillTerminate() {
        saveCurrentTrackToCache()
    }

    private func saveCurrentTrackToCache() {
        guard let currentTrack = currentTrack,
              let data = try? CodableCBOREncoder().encode(currentTrack) as NSData
        else { return }

        Self.cache.setObject(data, forKey: Self.currentTrackCacheKey)
    }

    private func restoreCurrentTrackFromCache() -> Track? {
        guard let data = Self.cache.object(forKey: Self.currentTrackCacheKey) as? Data else { return nil }
        Self.cache.removeObject(forKey: Self.currentTrackCacheKey)
        return try? CodableCBORDecoder().decode(Track.self, from: data)
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
    class Track: Codable {
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
