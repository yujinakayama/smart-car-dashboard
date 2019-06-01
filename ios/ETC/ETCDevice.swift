//
//  ETCDevice.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol ETCDeviceDelegate: NSObjectProtocol {
    func deviceDidFinishPreparation(_ device: ETCDevice, error: Error?)
}

enum ETCDeviceError: Error {
    case messageCannotBeSentBeforePreliminaryHandshake
}

// Using NSObject intead of struct for KVO
class ETCDeviceAttributes: NSObject {
    @objc dynamic var deviceName: String?
}

class ETCDevice: NSObject, UARTDeviceDelegate {
    let uartDevice: UARTDevice

    weak var delegate: ETCDeviceDelegate?

    let attributes = ETCDeviceAttributes()

    var hasCompletedPreparation = false

    init(uartDevice: UARTDevice) {
        self.uartDevice = uartDevice
        super.init()
        uartDevice.delegate = self
    }

    func startPreparation() {
        uartDevice.startPreparation()
    }

    func send(_ message: ETCSendableMessage) throws {
        if !hasCompletedPreparation && message.requiresPreliminaryHandshake {
            throw ETCDeviceError.messageCannotBeSentBeforePreliminaryHandshake
        }

        try uartDevice.write(message.data)
    }

    private func handleReceivedData(_ data: Data) {
        print("\(#function): \(data)")

        var matchingResult: (message: ETCReceivedMessage, unconsumedData: Data)?

        _ = ReceivedMessage.types.first { (type) in
            if let result = type.makeReceivedMessageIfMatches(data: data) {
                matchingResult = result
                return true
            } else {
                return false
            }
        }

        if let matchingResult = matchingResult {
            handleReceivedMessage(matchingResult.message)
            if !matchingResult.unconsumedData.isEmpty {
                handleReceivedData(matchingResult.unconsumedData)
            }
        } else {
            let message = ReceivedMessage.Unknown(data: data)
            handleReceivedMessage(message)
        }
    }

    private func handleReceivedMessage(_ message: ETCReceivedMessage) {
        switch message {
        case let deviceNameResponse as ReceivedMessage.DeviceNameResponse:
            attributes.deviceName = deviceNameResponse.deviceName
        default:
            break
        }

        print("Received message: \(message)")

        if message.requiresAcknowledgement {
            try! send(SendableMessage.acknowledgement)

            if !hasCompletedPreparation && message is ReceivedMessage.HandshakeRequest {
                hasCompletedPreparation = true
                delegate?.deviceDidFinishPreparation(self, error: nil)
            }
        }
    }

    // MARK: UARTDeviceDelegate

    func deviceDidFinishPreparation(_ device: UARTDevice, error: Error?) {
        if error == nil {
            try! send(SendableMessage.handshakeRequest)
        } else {
            delegate?.deviceDidFinishPreparation(self, error: error)
        }
    }

    func device(_ device: UARTDevice, didReceiveData data: Data) {
        handleReceivedData(data)
    }
}
