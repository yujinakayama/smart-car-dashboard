//
//  BluetoothAudioDevice.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/16.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

class BluetoothAudioDevice: NSObject, ClassicBluetoothManagerDelegate {
    let bluetoothManager = ClassicBluetoothManager()

    let audioDeviceName = "Olasonic NA-BTR1"

    override init() {
        super.init()
        bluetoothManager.delegate = self
    }

    func classicBluetoothManagerDidChangeAvailability(_ beeTee: ClassicBluetoothManager) {
        logger.debug(beeTee.isAvailable)
        connectIfPossible()
    }

    func connectIfPossible() {
        guard bluetoothManager.isConnectable else { return }
        guard let audioDevice = audioDevice else { return }
        audioDevice.connect()
    }

    var audioDevice: ClassicBluetoothDevice? {
        return bluetoothManager.pairedDevices.first { $0.name == audioDeviceName }
    }
}
