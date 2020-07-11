//
//  Vehicle.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/09.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

class Vehicle {
    let etcDevice = ETCDevice()
    let bluetoothAudioDevice = BluetoothAudioDevice()

    var isEngineStarted: Bool {
        return etcDevice.isConnected
    }

    func connect() {
        etcDevice.startPreparation()
    }
}
