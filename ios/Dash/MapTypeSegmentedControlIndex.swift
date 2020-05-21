//
//  MapTypeSegmentedControlIndex.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/05/22.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import MapKit

enum MapTypeSegmentedControlIndex: Int {
    case standard = 0
    case satellite

    init?(_ mapType: MKMapType) {
        switch mapType {
        case .standard:
            self = .standard
        case .satellite:
            self = .satellite
        default:
            return nil
        }
    }

    var mapType: MKMapType {
        switch self {
        case .standard:
            return .standard
        case .satellite:
            return .satellite
        }
    }
}
