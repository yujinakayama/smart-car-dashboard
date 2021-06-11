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
    let bluetoothAudioDevice = BluetoothAudioDevice()

    init() {
        addNotificationObserver()
    }

    private func addNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(etcDeviceDidConnect), name: .ETCDeviceDidConnect, object: nil)
    }

    func connect() {
        if Defaults.shared.isETCIntegrationEnabled {
            etcDevice.startPreparation()
        }
    }

    @objc func etcDeviceDidConnect() {
        logger.info()
        bluetoothAudioDevice.connectIfPossible()
    }
}
