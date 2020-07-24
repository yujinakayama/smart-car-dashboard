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
    case hybrid

    init?(_ mapType: MKMapType) {
        switch mapType {
        case .standard:
            self = .standard
        case .hybrid:
            self = .hybrid
        default:
            return nil
        }
    }

    var mapType: MKMapType {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        }
    }
}
