//
//  MapTypeSegmentedControl.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/09/18.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit

@IBDesignable class MapTypeSegmentedControl: UISegmentedControl {
    init() {
        super.init(frame: .zero)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        removeAllSegments()
        insertSegment(withTitle: String(localized: "Map"), at: 0, animated: false)
        insertSegment(withTitle: String(localized: "Satellite"), at: 1, animated: false)

        backgroundColor = UIColor(named: "Map Type Segmented Control Background Color")
    }

    var mapType: MKMapType {
        get {
            return Index(rawValue: selectedSegmentIndex)!.mapType
        }

        set {
            if let index = Index(mapType: newValue) {
                selectedSegmentIndex = index.rawValue
            }
        }
    }
}

extension MapTypeSegmentedControl {
    enum Index: Int {
        case standard = 0
        case hybrid

        init?(mapType: MKMapType) {
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
}
