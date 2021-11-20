//
//  GetCurrentAudioOutputTypeIntentHandler.swift
//  IntentsExtension
//
//  Created by Yuji Nakayama on 2021/11/20.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import AVFAudio

class GetCurrentAudioOutputTypeIntentHandler: NSObject, GetCurrentAudioOutputTypeIntentHandling {
    func handle(intent: GetCurrentAudioOutputTypeIntent) async -> GetCurrentAudioOutputTypeIntentResponse {
        guard let audioOutputPort = AVAudioSession.sharedInstance().currentRoute.outputs.first else {
            return GetCurrentAudioOutputTypeIntentResponse(code: .failure, userActivity: nil)
        }

        let response = GetCurrentAudioOutputTypeIntentResponse(code: .success, userActivity: nil)
        response.audioOutputType = AudioOutputType(audioOutputPort.portType)
        return response
    }
}

fileprivate extension AudioOutputType {
    init(_ port: AVAudioSession.Port) {
        switch port {
        case .airPlay:
            self = .airPlay
        case .bluetoothA2DP:
            self = .bluetoothA2DP
        case .bluetoothLE:
            self = .bluetoothLE
        case .builtInReceiver:
            self = .builtInReceiver
        case .builtInSpeaker:
            self = .builtInSpeaker
        case .HDMI:
            self = .hdmi
        case .headphones:
            self = .headphones
        case .lineOut:
            self = .lineOut
        case .AVB:
            self = .avb
        case .bluetoothHFP:
            self = .bluetoothHFP
        case .displayPort:
            self = .displayPort
        case .carAudio:
            self = .carAudio
        case .fireWire:
            self = .fireWire
        case .PCI:
            self = .pci
        case .thunderbolt:
            self = .thunderbolt
        case .usbAudio:
            self = .usbAudio
        case .virtual:
            self = .virtual
        default:
            self = .unknown
        }
    }
}
