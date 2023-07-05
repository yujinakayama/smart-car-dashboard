//
//  RoadTracker.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/01.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MapboxCoreNavigation

extension Notification.Name {
    static let RoadTrackerDidUpdateCurrentLocation = Notification.Name("RoadTrackerDidUpdateCurrentLocation")
    static let RoadTrackerDidUpdateCurrentRoad = Notification.Name("RoadTrackerDidUpdateCurrentRoad")
}

class RoadTracker: NSObject, CLLocationManagerDelegate {
    static let shared = RoadTracker()

    private lazy var passiveLocationManager: PassiveLocationManager = {
        let passiveLocationManager = PassiveLocationManager()
        passiveLocationManager.delegate = self
        return passiveLocationManager
    }()

    private let electronicHorizonOptions = ElectronicHorizonOptions(
        length: 1000,
        expansionLevel: 0,
        branchLength: 100,
        minTimeDeltaBetweenUpdates: nil
    )

    private var coreLocationManager: CLLocationManager {
        return passiveLocationManager.systemLocationManager
    }

    private var roadGraph: RoadGraph {
        return passiveLocationManager.roadGraph
    }

    private var geocoder = CLGeocoder()

    var isTracking = false

    var currentRoad: Road?
    var currentLocation: CLLocation?
    private var currentPlacemark: CLPlacemark?

    private var observerIdentifiers = Set<ObjectIdentifier>()

    override init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(electronicHorizonDidUpdatePosition),
            name: .electronicHorizonDidUpdatePosition,
            object: nil
        )
    }

    func registerObserver(_ observer: AnyObject) {
        logger.info()
        observerIdentifiers.insert(ObjectIdentifier(observer))
        print(observerIdentifiers)
        startTrackingIfNeeded()
    }

    func unregisterObserver(_ observer: AnyObject) {
        logger.info()
        observerIdentifiers.remove(ObjectIdentifier(observer))
        print(observerIdentifiers)

        if observerIdentifiers.isEmpty {
            stopTrackingIfNeeded()
        }
    }

    private func startTrackingIfNeeded() {
        guard !isTracking else { return }

        logger.info()

        isTracking = true

        switch coreLocationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            DispatchQueue.main.async {
                self.coreLocationManager.startUpdatingLocation()
                self.passiveLocationManager.startUpdatingElectronicHorizon(with: self.electronicHorizonOptions)
            }
        default:
            coreLocationManager.requestWhenInUseAuthorization()
        }
    }

    private func stopTrackingIfNeeded() {
        guard isTracking else { return }

        logger.info()

        isTracking = false
        coreLocationManager.stopUpdatingLocation()
        passiveLocationManager.stopUpdatingElectronicHorizon()
        currentRoad = nil
        currentLocation = nil
        currentPlacemark = nil
    }

    @objc func electronicHorizonDidUpdatePosition(_ notification: Notification) {
        guard isTracking,
              let edge = notification.userInfo?[RoadGraph.NotificationUserInfoKey.treeKey] as? RoadGraph.Edge,
              let edgeMetadata = roadGraph.edgeMetadata(edgeIdentifier: edge.identifier)
        else { return }

        Task {
            await updateCurrentRoad(edgeMetadata)
        }
    }

    func updateCurrentRoad(_ edge: RoadGraph.Edge.Metadata) async {
        let shouldUpdateCurrentPlacemarkNow =
            currentPlacemark == nil ||
            // When just entered service road, perform geocoding request for the location name
            (edge.mapboxStreetsRoadClass == .service && currentRoad?.edge.mapboxStreetsRoadClass != .service)

        if shouldUpdateCurrentPlacemarkNow, let currentLocation = currentLocation {
            logger.debug("Updating currentPlacemark due to road update; before: \(currentPlacemark?.name ?? "")")
            await performReverseGeocoding(for: currentLocation)
            logger.debug("Updating currentPlacemark due to road update; after: \(currentPlacemark?.name ?? "")")
        }
        
        guard let currentPlacemark = currentPlacemark else { return }
        
        let road = Road(edge: edge, placemark: currentPlacemark)
        currentRoad = road

        NotificationCenter.default.post(name: .RoadTrackerDidUpdateCurrentRoad, object: self, userInfo: [
            NotificationKeys.road: road
        ])
    }
    
    private func performReverseGeocoding(for location: CLLocation) async {
        let locale = Locale(identifier: "ja_JP")

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: locale)
            currentPlacemark = placemarks.first
        } catch {
            logger.error(error)
        }
    }

    private func shouldPerformReverseGeocoding(for location: CLLocation) -> Bool {
        guard isTracking else {
            return false
        }

        guard let lastLocation = currentPlacemark?.location else {
            return true
        }

        if Date() > lastLocation.timestamp + 30 {
            return true
        }

        return location.distance(from: lastLocation) > 250
    }
}

extension RoadTracker: PassiveLocationManagerDelegate {
    func passiveLocationManagerDidChangeAuthorization(_ manager: MapboxCoreNavigation.PassiveLocationManager) {
        logger.info(coreLocationManager.authorizationStatus.rawValue)

        guard isTracking else { return }

        switch coreLocationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            self.passiveLocationManager.startUpdatingLocation()
            passiveLocationManager.startUpdatingElectronicHorizon(with: electronicHorizonOptions)
        default:
            break
        }
    }

    func passiveLocationManager(_ manager: MapboxCoreNavigation.PassiveLocationManager, didUpdateLocation location: CLLocation, rawLocation: CLLocation) {
        guard isTracking else { return }

        currentLocation = location

        NotificationCenter.default.post(name: .RoadTrackerDidUpdateCurrentLocation, object: self, userInfo: [
            NotificationKeys.location: location
        ])

        if shouldPerformReverseGeocoding(for: location) {
            Task {
                await performReverseGeocoding(for: location)
            }
        }
    }

    func passiveLocationManager(_ manager: MapboxCoreNavigation.PassiveLocationManager, didUpdateHeading newHeading: CLHeading) {
    }

    func passiveLocationManager(_ manager: MapboxCoreNavigation.PassiveLocationManager, didFailWithError error: Error) {
        logger.error(error)
    }
}

extension RoadTracker {
    struct NotificationKeys {
        static let road = "RoadTracker-road"
        static let location = "RoadTracker-location"
    }
}
