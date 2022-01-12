//
//  Vehicle.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/09.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

class Vehicle {
    static let `default` = Vehicle()

    let etcDevice = ETCDevice()

    init() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(forName: .ETCDeviceDidConnect, object: nil, queue: .main) { (notification) in
            notificationCenter.post(name: .VehicleDidConnect, object: self)
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDisconnect, object: nil, queue: .main) { (notification) in
            notificationCenter.post(name: .VehicleDidDisconnect, object: self)
        }
    }

    var isConnected: Bool {
        return etcDevice.isConnected
    }

    func connect() {
        if Defaults.shared.isETCIntegrationEnabled {
            etcDevice.startPreparation()
        }
    }
}

extension Notification.Name {
    static let VehicleDidConnect = Notification.Name("VehicleDidConnect")
    static let VehicleDidDisconnect = Notification.Name("VehicleDidDisconnect")
}
