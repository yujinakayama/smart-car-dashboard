//
//  ETCDevice.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol ETCDeviceConnectionDelegate: NSObjectProtocol {
    func connectionDidEstablish(_ connection: ETCDeviceConnection)
    func connection(_ connection: ETCDeviceConnection, didReceiveMessage message: ETCMessageFromDeviceProtocol)
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

    var isEstablished: Bool {
        return handshakeStatus == .complete
    }

    private var handshakeStatus = ETCDeviceConnectionHandshakeStatus.incomplete
    private let handshakeTimeoutTimeInterval: TimeInterval = 1
    private var handshakeTimeoutTimer: Timer?

    private var hasCompletedHandshakeOnce = false
    private var pendingMessagesToSend: [ETCMessageToDeviceProtocol] = []

    init(serialPort: SerialPort) {
        self.serialPort = serialPort
        super.init()
        serialPort.delegate = self
    }

    func start() {
        startHandshake()
    }

    private func startHandshake() {
        logger.info()

        handshakeStatus = .trying

        onHandshakeTimeout { [weak self] in
            guard let self = self else { return }

            if self.handshakeStatus == .trying {
                logger.info("Handshake timed out")
                self.handshakeStatus = .incomplete
            }
        }

        send(ETCMessageToDevice.handshakeRequest)
    }

    private func onHandshakeTimeout(timeoutHandler: @escaping () -> Void) {
        let timer = Timer(timeInterval: handshakeTimeoutTimeInterval, repeats: false) { [weak self] (timer) in
            guard let self = self else { return }
            self.handshakeTimeoutTimer = nil
            timeoutHandler()
        }

        RunLoop.main.add(timer, forMode: .common)

        handshakeTimeoutTimer = timer
    }

    private func completeHandshake() {
        logger.info()

        handshakeStatus = .complete
        handshakeTimeoutTimer?.invalidate()
        handshakeTimeoutTimer = nil

        if (!hasCompletedHandshakeOnce) {
            delegate?.connectionDidEstablish(self)
            hasCompletedHandshakeOnce = true
        }

        sendPendingMessages()
    }

    func send(_ message: ETCMessageToDeviceProtocol) {
        logger.debug(message)

        if !message.requiresPreliminaryHandshake || handshakeStatus == .complete {
            serialPort.transmit(message.data)
        } else {
            logger.debug("Enqueueing the message to pending message list since handshake is not yet completed")
            pendingMessagesToSend.append(message)
        }
    }

    private func sendPendingMessages() {
        for message in pendingMessagesToSend {
            logger.debug("Sending pending message")
            send(message)
        }

        pendingMessagesToSend.removeAll()
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
            send(ETCMessageToDevice.acknowledgement)

            if handshakeStatus != .complete && message is ETCMessageFromDevice.HandshakeRequest {
                completeHandshake()
            }
        }

        if !(message is ETCMessageFromDevice.Unknown) {
            delegate?.connection(self, didReceiveMessage: message)
        }
    }

    // MARK: SerialPortDelegate

    func serialPort(_ device: SerialPort, didReceiveData data: Data) {
        handleReceivedData(data)
    }
}
