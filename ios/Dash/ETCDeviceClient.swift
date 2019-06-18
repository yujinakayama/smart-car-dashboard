//
//  ETCDevice.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol ETCDeviceClientDelegate: NSObjectProtocol {
    func deviceClientDidFinishPreparation(_ deviceClient: ETCDeviceClient, error: Error?)
    func deviceClient(_ deviceClient: ETCDeviceClient, didReceiveMessage message: ETCMessageFromDeviceProtocol)
}

enum ETCDeviceClientError: Error {
    case messageCannotBeSentBeforePreliminaryHandshake
}

// Using NSObject intead of struct for KVO
class ETCDeviceAttributes: NSObject {
    @objc dynamic var deviceName: String?
    @objc dynamic var usages: [ETCUsage] = []
}

class ETCDeviceClient: NSObject, SerialPortDelegate {
    let serialPort: SerialPort

    weak var delegate: ETCDeviceClientDelegate?

    let deviceAttributes = ETCDeviceAttributes()

    var hasCompletedPreparation = false

    init(serialPort: SerialPort) {
        self.serialPort = serialPort
        super.init()
        serialPort.delegate = self
    }

    func startPreparation() {
        serialPort.startPreparation()
    }

    private func startHandshake() {
        logger.info()
        try! send(ETCMessageFromClient.handshakeRequest)
    }

    private func completeHandshake() {
        logger.info()
        hasCompletedPreparation = true
        delegate?.deviceClientDidFinishPreparation(self, error: nil)
    }

    func send(_ message: ETCMessageFromClientProtocol) throws {
        logger.debug(message)

        if !hasCompletedPreparation && message.requiresPreliminaryHandshake {
            throw ETCDeviceClientError.messageCannotBeSentBeforePreliminaryHandshake
        }

        try serialPort.transmit(message.data)
    }

    private func handleReceivedData(_ data: Data) {
        logger.debug("\(data.count) bytes: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")

        var matchingResult: (message: ETCMessageFromDeviceProtocol, unconsumedData: Data)?

        _ = ETCMessageFromDevice.knownTypes.first { (type) in
            if let result = type.makeMessageIfMatches(data: data) {
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
            let message = ETCMessageFromDevice.Unknown(data: data)
            handleReceivedMessage(message)
        }
    }

    private func handleReceivedMessage(_ message: ETCMessageFromDeviceProtocol) {
        logger.debug(message)

        switch message {
        case let deviceNameResponse as ETCMessageFromDevice.DeviceNameResponse:
            deviceAttributes.deviceName = deviceNameResponse.deviceName
        case is ETCMessageFromDevice.InitialUsageRecordExistenceResponse:
            try! send(ETCMessageFromClient.initialUsageRecordRequest)
        case let usageRecordResponse as ETCMessageFromDevice.UsageRecordResponse:
            // TODO: ETCDeviceClient should focus only on communication and should not handle state management.
            // FIXME: Inefficient. Use Set or Core Data.
            if !deviceAttributes.usages.contains(usageRecordResponse.usage) {
                deviceAttributes.usages.append(usageRecordResponse.usage)
                deviceAttributes.usages.sort { (a, b) in a.date ?? Date.distantPast > b.date ?? Date.distantPast }
                try! send(ETCMessageFromClient.nextUsageRecordRequest)
            }
        default:
            break
        }

        if message.requiresAcknowledgement {
            try! send(ETCMessageFromClient.acknowledgement)

            if !hasCompletedPreparation && message is ETCMessageFromDevice.HandshakeRequest {
                completeHandshake()
            }
        }

        if !(message is ETCMessageFromDevice.Unknown) {
            delegate?.deviceClient(self, didReceiveMessage: message)
        }
    }

    // MARK: SerialPortDelegate

    func serialPortDidFinishPreparation(_ device: SerialPort, error: Error?) {
        logger.debug(error)

        if error == nil {
            startHandshake()
        } else {
            delegate?.deviceClientDidFinishPreparation(self, error: error)
        }
    }

    func serialPort(_ device: SerialPort, didReceiveData data: Data) {
        handleReceivedData(data)
    }
}
