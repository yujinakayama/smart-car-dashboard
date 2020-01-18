//
//  ETCDevice.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol ETCDeviceConnectionDelegate: NSObjectProtocol {
    func deviceConnectionDidFinishPreparation(_ deviceConnection: ETCDeviceConnection, error: Error?)
    func deviceConnection(_ deviceConnection: ETCDeviceConnection, didReceiveMessage message: ETCMessageFromDeviceProtocol)
}

enum ETCDeviceConnectionHandshakeStatus {
    case incomplete
    case trying
    case complete
}

class ETCDeviceConnection: NSObject, SerialPortDelegate {
    let serialPort: SerialPort

    weak var delegate: ETCDeviceConnectionDelegate?

    var unprocessedData = Data()

    var isAvailable: Bool {
        return serialPort.isAvailable && handshakeStatus == .complete
    }

    private var handshakeStatus = ETCDeviceConnectionHandshakeStatus.incomplete
    private let handshakeTimeoutTimeInterval: TimeInterval = 1
    private var handshakeTimeoutTimer: Timer?

    private var hasFinishedPreparationOnce = false

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

        handshakeStatus = .trying

        handshakeTimeoutTimer = Timer.scheduledTimer(withTimeInterval: handshakeTimeoutTimeInterval, repeats: false) { [weak self] (timer) in
            guard let self = self else { return }

            if self.handshakeStatus == .trying {
                logger.info("Handshake timed out")
                self.handshakeStatus = .incomplete
            }

            self.handshakeTimeoutTimer = nil
        }

        try! send(ETCMessageToDevice.handshakeRequest)
    }

    private func completeHandshake() {
        logger.info()

        handshakeStatus = .complete
        handshakeTimeoutTimer?.invalidate()
        handshakeTimeoutTimer = nil

        if (!hasFinishedPreparationOnce) {
            delegate?.deviceConnectionDidFinishPreparation(self, error: nil)
            hasFinishedPreparationOnce = true
        }
    }

    func send(_ message: ETCMessageToDeviceProtocol) throws {
        logger.debug(message)
        assert(!message.requiresPreliminaryHandshake || handshakeStatus == .complete)
        try serialPort.transmit(message.data)
    }

    private func handleReceivedData(_ data: Data) {
        logger.debug("Newly received: \(data.count) bytes (\(data.map { String(format: "%02X", $0) }.joined(separator: " ")))")

        unprocessedData += data

        logger.debug("Unprocessed data: \(unprocessedData.count) bytes (\(unprocessedData.map { String(format: "%02X", $0) }.joined(separator: " ")))")

        while let result = ETCMessageFromDevice.parse(unprocessedData) {
            unprocessedData = result.unconsumedData
            handleReceivedMessage(result.message)
        }
    }

    private func handleReceivedMessage(_ message: ETCMessageFromDeviceProtocol) {
        logger.debug(message)

        switch message {
        case is ETCMessageFromDevice.HeartBeat:
            if handshakeStatus == .incomplete {
                startHandshake()
            }
        case is ETCMessageFromDevice.CardInsertionNotification:
            // When a card is inserted, the device requires handshake again.
            // However, in this case, we don't need to request handshake from ourselves;
            // the device sends us a handshake request without asking.
            handshakeStatus = .incomplete
        default:
            break
        }

        if message.requiresAcknowledgement {
            try! send(ETCMessageToDevice.acknowledgement)

            if handshakeStatus != .complete && message is ETCMessageFromDevice.HandshakeRequest {
                completeHandshake()
            }
        }

        if !(message is ETCMessageFromDevice.Unknown) {
            delegate?.deviceConnection(self, didReceiveMessage: message)
        }
    }

    // MARK: SerialPortDelegate

    func serialPortDidFinishPreparation(_ device: SerialPort, error: Error?) {
        logger.debug(error)

        if error == nil {
            startHandshake()
        } else {
            delegate?.deviceConnectionDidFinishPreparation(self, error: error)
        }
    }

    func serialPort(_ device: SerialPort, didReceiveData data: Data) {
        handleReceivedData(data)
    }
}
