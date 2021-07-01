//
//  VehicleMovement.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/01.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

class VehicleMovement {
    private var locations: [CLLocation] = []

    let dropOutTimeInterval: TimeInterval = 5

    // 25km/h
    let maxTurnSpeed: CLLocationSpeed = 25 * (1000 / (60 * 60))

    let minTurnAngle: CLLocationDirection = 50

    func record(_ location: CLLocation) {
        locations.append(location)

        while let oldestLocation = locations.first, oldestLocation.timestamp.distance(to: location.timestamp) > dropOutTimeInterval {
            locations.removeFirst()
        }
    }

    func reset() {
        locations = []
    }

    var isEstimatedToHaveJustTurned: Bool {
        guard let averageSpeed = averageSpeed, let angleDelta = angleDelta else { return false }
        return averageSpeed <= maxTurnSpeed && angleDelta >= minTurnAngle
    }

    var averageSpeed: CLLocationSpeed? {
        guard !locations.isEmpty else { return nil }

        return locations.reduce(CLLocationSpeed(0)) { (averageSpeed, location) in
            averageSpeed + location.speed / Double(locations.count)
        }
    }

    var angleDelta: CLLocationDirection? {
        guard let firstLocation = locations.first, let lastLocation = locations.last else { return nil }
        return angleDelta(firstLocation.course, lastLocation.course)
    }

    private func angleDelta(_ a: CLLocationDirection, _ b: CLLocationDirection) -> CLLocationDirection {
        let delta = abs(b - a).truncatingRemainder(dividingBy: 360)
        return delta > 180 ? 360 - delta : delta
    }
}
