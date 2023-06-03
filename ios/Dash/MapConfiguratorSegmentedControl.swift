//
//  MapConfiguratorSegmentedControl.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/09/18.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit

@IBDesignable class MapConfiguratorSegmentedControl: UISegmentedControl {
    init(configurators: [MapConfigurator]) {
        super.init(frame: .zero)
        commonInit()
        self.configurators = configurators
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

    var configurators: [MapConfigurator] = [] {
        didSet {
            updateSegments()
        }
    }

    var selectedConfigurator: MapConfigurator? {
        get {
            if selectedSegmentIndex == Self.noSegment {
                return nil
            } else {
                return configurators[selectedSegmentIndex]
            }
        }

        set {
            if let newConfigurator = newValue, let index = configurators.firstIndex(where: { $0.identifier == newConfigurator.identifier }) {
                selectedSegmentIndex = index
            } else {
                selectedSegmentIndex = Self.noSegment
            }
        }
    }

    var selectedConfiguratorIdentifier: String? {
        get {
            return selectedConfigurator?.identifier
        }

        set {
            if let newIdentifier = newValue, let index = configurators.firstIndex(where: { $0.identifier == newIdentifier }) {
                selectedSegmentIndex = index
            } else {
                selectedSegmentIndex = Self.noSegment
            }
        }
    }
    
    private func updateSegments() {
        removeAllSegments()

        for (index, configurator) in configurators.enumerated() {
            insertSegment(withTitle: configurator.name, at: index, animated: false)
        }
    }
}
