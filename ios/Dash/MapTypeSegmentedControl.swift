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
    init(mapTypes: [MKMapType]) {
        super.init(frame: .zero)
        commonInit()
        self.mapTypes = mapTypes
        updateSegments()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    // For some reason IBDesignablesAgent crashes without this:
    // Dash/MapTypeSegmentedControl.swift:12: Fatal error: Use of unimplemented initializer 'init(items:)' for class 'Dash.MapTypeSegmentedControl'
    override init(items: [Any]?) {
        super.init(items: items)
        commonInit()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
    }

    private func commonInit() {
        backgroundColor = UIColor(named: "Map Type Segmented Control Background Color")
    }

    var mapTypes: [MKMapType] = [] {
        didSet {
            updateSegments()
        }
    }

    var selectedMapType: MKMapType? {
        get {
            if selectedSegmentIndex == Self.noSegment {
                return nil
            } else {
                return mapTypes[selectedSegmentIndex]
            }
        }

        set {
            if let mapType = newValue, let index = mapTypes.firstIndex(of: mapType) {
                selectedSegmentIndex = index
            } else {
                selectedSegmentIndex = Self.noSegment
            }
        }
    }

    private func updateSegments() {
        removeAllSegments()

        for (index, mapType) in mapTypes.enumerated() {
            insertSegment(withTitle: mapType.name, at: index, animated: false)
        }
    }
}

fileprivate extension MKMapType {
    var name: String? {
        switch self {
        case .standard, .mutedStandard:
            return String(localized: "Map")
        case .satellite, .hybrid, .satelliteFlyover, .hybridFlyover:
            return String(localized: "Satellite")
        default:
            return nil
        }
    }
}
