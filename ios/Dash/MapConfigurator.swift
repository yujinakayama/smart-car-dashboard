//
//  MapConfigurator.swift
//  Dash
//
//  Created by Yuji Nakayama on 2023/06/03.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import MapKit

class MapConfigurator {
    let identifier: String // Used for state restoration
    let name: String
    let configuration: MKMapConfiguration
    let isPitchEnabled: Bool
    let isRotateEnabled: Bool
    let defaultPitch: CGFloat?
    
    init(identifier: String, name: String, configuration: MKMapConfiguration, isPitchEnabled: Bool = false, isRotateEnabled: Bool = false, defaultPitch: CGFloat? = nil) {
        self.identifier = identifier
        self.name = name

        self.configuration = configuration
        self.isPitchEnabled = isPitchEnabled
        self.isRotateEnabled = isRotateEnabled
        self.defaultPitch = defaultPitch
    }
    
    func configure(_ mapView: MKMapView) {
        mapView.preferredConfiguration = configuration
        mapView.isPitchEnabled = isPitchEnabled
        mapView.isRotateEnabled = isRotateEnabled
        
        if let defaultPitch = defaultPitch {
            let camera = mapView.camera
            camera.pitch = defaultPitch
            mapView.setCamera(camera, animated: true)
        }
    }
}

extension MapConfigurator {
    static let standard = MapConfigurator(
        identifier: "standard",
        name: String(localized: "Map"),
        configuration: {
            let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
            configuration.showsTraffic = true
            return configuration
        }(),
        isPitchEnabled: true
    )

    static let satellite = MapConfigurator(
        identifier: "satellite",
        name: String(localized: "Satellite"),
        configuration: MKHybridMapConfiguration(elevationStyle: .realistic),
        isPitchEnabled: true
    )
}
