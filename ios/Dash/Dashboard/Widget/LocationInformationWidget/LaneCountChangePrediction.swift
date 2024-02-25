//
//  LaneCountChangePrediction.swift
//  Dash
//
//  Created by Yuji Nakayama on 2024/02/25.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation
import MapboxCoreNavigation

enum LaneCountPrediction {
    case noChangeAtLeast(currentLaneCount: UInt?, minimumDistance: CLLocationDistance)
    case nextChangeContinuesFixedLength(newLaneCount: UInt?, distance: CLLocationDistance, length: CLLocationDistance)
    case nextChangeContinuesAtLeast(newLaneCount: UInt?, distance: CLLocationDistance, minimumLength: CLLocationDistance)
}

func findNextLaneCountChange(in path: RoadPath, from initialPosition: RoadGraph.Position) -> LaneCountPrediction {
    assert(path.firstEdge.identifier == initialPosition.edgeIdentifier)

    var accumulatedDistance: CLLocationDistance = 0
    var previousLaneCount = path.first?.oneSideLaneCount

    var distanceToNextChange: CLLocationDistance? = nil
    var newLaneCount: UInt? = nil
    var lengthOfNextChange: CLLocationDistance? = nil

    for (index, road) in path.enumerated() {
        if road.oneSideLaneCount != previousLaneCount {
            if distanceToNextChange == nil {
                distanceToNextChange = accumulatedDistance
                newLaneCount = road.oneSideLaneCount
            } else if let distanceToNextLaneCountChange = distanceToNextChange {
                lengthOfNextChange = accumulatedDistance - distanceToNextLaneCountChange
                break
            }
        }

        previousLaneCount = road.oneSideLaneCount

        if index == 0 {
            accumulatedDistance += road.length * (1 - initialPosition.fractionFromStart)
        } else {
            accumulatedDistance += road.length
        }
    }

    if let distanceToNextChange = distanceToNextChange {
        if let lengthOfNextChange = lengthOfNextChange {
            return .nextChangeContinuesFixedLength(
                newLaneCount: newLaneCount,
                distance: distanceToNextChange,
                length: lengthOfNextChange
            )
        } else {
            return .nextChangeContinuesAtLeast(
                newLaneCount: newLaneCount,
                distance: distanceToNextChange,
                minimumLength: accumulatedDistance - distanceToNextChange
            )
        }
    } else {
        return .noChangeAtLeast(currentLaneCount: previousLaneCount, minimumDistance: accumulatedDistance)
    }
}
