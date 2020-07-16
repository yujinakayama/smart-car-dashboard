//
//  BluetoothAudioDevice.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/16.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

class BluetoothAudioDevice: NSObject, BeeTeeDelegate {
    let beeTee = BeeTee()

    let audioDeviceName = "Olasonic NA-BTR1"

    override init() {
        super.init()
        beeTee.delegate = self
    }

    func beeTeeDidChangeAvailability(_ beeTee: BeeTee) {
        logger.debug(beeTee.isAvailable)
        connectIfPossible()
    }

    func connectIfPossible() {
        guard beeTee.isConnectable else { return }
        guard let audioDevice = audioDevice else { return }
        audioDevice.connect()
    }

    var audioDevice: BeeTeeDevice? {
        return beeTee.pairedDevices.first { $0.name == audioDeviceName }
    }
}
