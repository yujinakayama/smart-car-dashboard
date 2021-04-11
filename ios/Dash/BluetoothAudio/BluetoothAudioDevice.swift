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
        logger.info(beeTee.isAvailable)
    }

    func connectIfPossible() {
        guard bluetoothManager.isConnectable else { return }
        guard let audioDevice = audioDevice, !audioDevice.isConnected else { return }
        audioDevice.connect()
    }

    func classicBluetoothManager(_ manager: ClassicBluetoothManager, didConnectToDevice device: ClassicBluetoothDevice) {
        logger.info(device.name)
        Timer.scheduledTimer(timeInterval: autoPlayDelay, target: self, selector: #selector(startPlayingMusic), userInfo: nil, repeats: false)
    }

    @objc func startPlayingMusic() {
        if !isPlayingLiveItem && !isProbablyPlayingRadio {
            musicPlayer.skipToBeginning()
        }

        musicPlayer.play()
    }

    var musicPlayer: MPMusicPlayerController {
        return MPMusicPlayerController.systemMusicPlayer
    }

    var isPlayingLiveItem: Bool {
        return musicPlayer.currentPlaybackTime.isNaN
    }

    var isProbablyPlayingRadio: Bool {
        guard let nowPlayingItem = musicPlayer.nowPlayingItem else { return false }
        return nowPlayingItem.mediaType.rawValue == 0 || nowPlayingItem.playbackDuration == 0
    }
}
