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
    func roadTracker(_ roadTracker: RoadTracker, didUpdateCurrentEdge edge: RoadGraph.Edge.Metadata)
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

    var isTracking = false

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
              let edgeMetadata = roadGraph.edgeMetadata(edgeIdentifier: edge.identifier)
        else { return }

        delegate?.roadTracker(self, didUpdateCurrentEdge: edgeMetadata)
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
    }

    func passiveLocationManager(_ manager: MapboxCoreNavigation.PassiveLocationManager, didUpdateHeading newHeading: CLHeading) {
    }

    func passiveLocationManager(_ manager: MapboxCoreNavigation.PassiveLocationManager, didFailWithError error: Error) {
        logger.error(error)
    }
}
