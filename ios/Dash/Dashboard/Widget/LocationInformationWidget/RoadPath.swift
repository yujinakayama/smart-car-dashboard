//
//  RoadPath.swift
//  Dash
//
//  Created by Yuji Nakayama on 2024/02/25.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import Foundation
import MapboxCoreNavigation

struct RoadPath: Sequence, IteratorProtocol {
    let roadGraph: RoadGraph
    let firstEdge: RoadGraph.Edge
    private var currentEdge: RoadGraph.Edge?

    init(roadGraph: RoadGraph, firstEdge: RoadGraph.Edge) {
        self.roadGraph = roadGraph
        self.firstEdge = firstEdge
        self.currentEdge = firstEdge
    }

    var first: Road? {
        guard let metadata = roadGraph.edgeMetadata(edgeIdentifier: firstEdge.identifier) else {
            return nil
        }

        return Road(edge: firstEdge, metadata: metadata)
    }

    mutating func next() -> Road? {
        guard let edge = currentEdge,
              let metadata = roadGraph.edgeMetadata(edgeIdentifier: edge.identifier)
        else {
            return nil
        }

        let road = Road(edge: edge, metadata: metadata)
        currentEdge = edge.outletEdges.max(by: { $0.probability < $1.probability })
        return road
    }
}
