//
//  RoadTracker.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/01.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

protocol RoadTrackerDelegate: NSObjectProtocol {
    func roadTracker(_ roadTracker: RoadTracker, didUpdateCurrentLocation location: CLLocation)
    func roadTracker(_ roadTracker: RoadTracker, didUpdateCurrentPlace place: OpenCage.Place, for location: CLLocation, with reason: RoadTracker.UpdateReason)
}

class RoadTracker: NSObject, CLLocationManagerDelegate {
    weak var delegate: RoadTrackerDelegate?

    private lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        return locationManager
    }()

    private lazy var openCage: OpenCage = {
        let path = Bundle.main.path(forResource: "opencage_api_key", ofType: "txt")!
        let apiKey = try! String(contentsOfFile: path)
        return OpenCage(apiKey: apiKey)
    }()

    var isTracking = false

    // horizontalAccuracy returns fixed value 65.0 in reinforced concrete buildings, which is unstable
    static let unreliableLocationAccuracy: CLLocationAccuracy = 65

    // https://opencagedata.com/pricing
    static let maximumRequestCountPerDay = 2500

    // 34.56 seconds
    static var fixedUpdateInterval: TimeInterval = TimeInterval((60 * 60 * 24) / maximumRequestCountPerDay)

    static let minimumMovementDistanceForIntervalUpdate: CLLocationDistance = 10

    private var currentRequestTask: Task<Void, Never>?

    var currentPlace: OpenCage.Place? {
        didSet {
            currentRegion = currentPlace?.region.extended(by: Self.regionExtensionDistance)
        }
    }

    private var currentRegion: OpenCage.Region?

    // We should extend original regions to avoid too frequent boundary detection caused by GPS errors
    // especially on roads running through north to south, or east to west, which tend to have very narrow region.
    static let regionExtensionDistance: CLLocationDistance = 5

    private var lastRequestLocation: CLLocation?

    private let vehicleMovement = VehicleMovement()

    func startTracking() {
        logger.info()

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            DispatchQueue.main.async {
                self.locationManager.startUpdatingLocation()
            }
            isTracking = true
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func stopTracking() {
        logger.info()

        locationManager.stopUpdatingLocation()
        isTracking = false

        currentRequestTask?.cancel()
        currentRequestTask = nil
        currentPlace = nil
        lastRequestLocation = nil
        vehicleMovement.reset()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info(manager.authorizationStatus.rawValue)

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            isTracking = true
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logger.debug()

        guard let location = locations.last else { return }

        delegate?.roadTracker(self, didUpdateCurrentLocation: location)

        performRequestIfNeeded(for: location)
    }

    func considersLocationAccurate(_ location: CLLocation) -> Bool {
        return location.horizontalAccuracy < Self.unreliableLocationAccuracy
    }

    private func performRequestIfNeeded(for location: CLLocation) {
        vehicleMovement.record(location)

        // Avoid parallel requests
        guard currentRequestTask == nil else { return }

        let isLocationAccurate = considersLocationAccurate(location)

        // If we have moved out from the region of the previous road, update.
        if isLocationAccurate,
           let currentRegion = currentRegion, let lastRequestLocation = lastRequestLocation,
           currentRegion.contains(lastRequestLocation.coordinate), !currentRegion.contains(location.coordinate)
        {
            performRequest(for: location, reason: .outOfRegion)
            return
        }

        // Even if we are still considered to be inside of the region of the current road,
        // update in a fixed interval because:
        // * The region is rectangular but actual road is not
        // * The current road may be wrong
        if let lastRequestLocation = lastRequestLocation {
            if location.timestamp >= lastRequestLocation.timestamp + Self.fixedUpdateInterval,
               location.distance(from: lastRequestLocation) >= Self.minimumMovementDistanceForIntervalUpdate
            {
                performRequest(for: location, reason: .interval)
                return
            }
        } else {
            performRequest(for: location, reason: .initial)
            return
        }

        // If we turned at an intersection, update
        if isLocationAccurate, vehicleMovement.isEstimatedToHaveJustTurned {
            vehicleMovement.reset()

            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                self.performRequest(for: self.locationManager.location ?? location, reason: .turn)
            }

            return
        }
    }

    private func performRequest(for location: CLLocation, reason: UpdateReason) {
        currentRequestTask = Task {
            let place: OpenCage.Place

            do {
                place = try await openCage.reverseGeocode(coordinate: location.coordinate)
            } catch {
                logger.error(error)
                return
            }

            logger.debug(place)

            currentPlace = place
            lastRequestLocation = location
            delegate?.roadTracker(self, didUpdateCurrentPlace: place, for: location, with: reason)

            currentRequestTask = nil
        }
    }
}

extension RoadTracker {
    enum LocationReliability {
        case normal
        case low
    }
}

extension RoadTracker {
    enum UpdateReason: String {
        case initial
        case interval
        case turn
        case outOfRegion

        var description: String {
            switch self {
            case .outOfRegion:
                return "Out of Region"
            default:
                return rawValue.capitalized
            }
        }
    }
}
