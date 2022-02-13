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

    let etcDeviceManager = ETCDeviceManager()

    init() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(self, selector: #selector(firebaseAuthenticationDidUpdateVehicleID), name: .FirebaseAuthenticationDidChangeVehicleID, object: nil)

        notificationCenter.addObserver(forName: .ETCDeviceDidConnect, object: nil, queue: .main) { (notification) in
            notificationCenter.post(name: .VehicleDidConnect, object: self)
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDisconnect, object: nil, queue: .main) { (notification) in
            notificationCenter.post(name: .VehicleDidDisconnect, object: self)
        }
    }

    var isConnected: Bool {
        return etcDeviceManager.isConnected
    }

    func connect() {
        if Defaults.shared.isETCIntegrationEnabled {
            etcDeviceManager.connect()
        }
    }

    @objc func firebaseAuthenticationDidUpdateVehicleID() {
        guard Defaults.shared.isETCIntegrationEnabled else { return }

        if let vehicleID = Firebase.shared.authentication.vehicleID {
            etcDeviceManager.database = ETCDatabase(vehicleID: vehicleID)
        } else {
            etcDeviceManager.database = nil
        }
    }
}

extension Notification.Name {
    static let VehicleDidConnect = Notification.Name("VehicleDidConnect")
    static let VehicleDidDisconnect = Notification.Name("VehicleDidDisconnect")
}
