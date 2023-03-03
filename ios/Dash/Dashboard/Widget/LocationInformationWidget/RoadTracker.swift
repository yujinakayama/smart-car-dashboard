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

protocol RoadTrackerDelegate: NSObjectProtocol {
    func roadTracker(_ roadTracker: RoadTracker, didUpdateCurrentLocation location: CLLocation)
    func roadTracker(_ roadTracker: RoadTracker, didUpdateCurrentRoad road: Road)
}

class RoadTracker: NSObject, CLLocationManagerDelegate {
    weak var delegate: RoadTrackerDelegate?

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

    private var currentPlacemark: CLPlacemark?

    // horizontalAccuracy returns fixed value 65.0 in reinforced concrete buildings, which is unstable
    static let unreliableLocationAccuracy: CLLocationAccuracy = 65

    override init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(electronicHorizonDidUpdatePosition),
            name: .electronicHorizonDidUpdatePosition,
            object: nil
        )
    }

    func startTracking() {
        logger.info()

        isTracking = true

        switch coreLocationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            DispatchQueue.main.async {
                self.passiveLocationManager.startUpdatingLocation()
                self.passiveLocationManager.startUpdatingElectronicHorizon(with: self.electronicHorizonOptions)
            }
        default:
            coreLocationManager.requestWhenInUseAuthorization()
        }
    }

    func stopTracking() {
        logger.info()
        passiveLocationManager.stopUpdatingElectronicHorizon()
        isTracking = false
    }

    func considersLocationAccurate(_ location: CLLocation) -> Bool {
        return location.horizontalAccuracy < Self.unreliableLocationAccuracy
    }

    @objc func electronicHorizonDidUpdatePosition(_ notification: Notification) {
        guard let edge = notification.userInfo?[RoadGraph.NotificationUserInfoKey.treeKey] as? RoadGraph.Edge,
              let edgeMetadata = roadGraph.edgeMetadata(edgeIdentifier: edge.identifier),
              let currentPlacemark = currentPlacemark
        else { return }

        let road = Road(edge: edgeMetadata, placemark: currentPlacemark)
        delegate?.roadTracker(self, didUpdateCurrentRoad: road)
    }

    private func reverseGeocode(for location: CLLocation) {
        guard shouldRequestGeocoding(for: location) else {return }

        let locale = Locale(identifier: "ja_JP")

        geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { [weak self] (placemarks, error) in
            guard let self = self, self.isTracking else { return }

            if let error = error {
                logger.error(error)
                return
            }

            guard let placemark = placemarks?.first else { return }
            self.currentPlacemark = placemark
        }
    }

    private func shouldRequestGeocoding(for location: CLLocation) -> Bool {
        guard let lastLocation = currentPlacemark?.location else {
            return true
        }

        if Date() > lastLocation.timestamp + 30 {
            return true
        }

        return location.distance(from: lastLocation) > 500
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
        delegate?.roadTracker(self, didUpdateCurrentLocation: location)
        reverseGeocode(for: location)
    }

    func passiveLocationManager(_ manager: MapboxCoreNavigation.PassiveLocationManager, didUpdateHeading newHeading: CLHeading) {
    }

    func passiveLocationManager(_ manager: MapboxCoreNavigation.PassiveLocationManager, didFailWithError error: Error) {
        logger.error(error)
    }
}
