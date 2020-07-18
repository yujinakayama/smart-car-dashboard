//
//  BluetoothAudioDevice.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/16.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import MediaPlayer

class BluetoothAudioDevice: NSObject, ClassicBluetoothManagerDelegate {
    let bluetoothManager = ClassicBluetoothManager()

    let autoPlayDelay: TimeInterval = 3

    let audioDeviceName = "Olasonic NA-BTR1"

    var audioDevice: ClassicBluetoothDevice? {
        return bluetoothManager.pairedDevices.first { $0.name == audioDeviceName }
    }

    override init() {
        super.init()
        bluetoothManager.delegate = self
    }

    func classicBluetoothManagerDidChangeAvailability(_ beeTee: ClassicBluetoothManager) {
        logger.debug(beeTee.isAvailable)
    }

    func connectIfPossible() {
        guard bluetoothManager.isConnectable else { return }
        guard let audioDevice = audioDevice, !audioDevice.isConnected else { return }
        audioDevice.connect()
    }

    func classicBluetoothManager(_ manager: ClassicBluetoothManager, didConnectToDevice device: ClassicBluetoothDevice) {
        Timer.scheduledTimer(timeInterval: autoPlayDelay, target: self, selector: #selector(startPlayingMusic), userInfo: nil, repeats: false)
    }

    @objc func startPlayingMusic() {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.skipToBeginning()
        musicPlayer.play()
    }
}
