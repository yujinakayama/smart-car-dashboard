//
//  ETCDevice.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let ETCDeviceDidConnect = Notification.Name("ETCDeviceDidConnect")
    static let ETCDeviceDidDisconnect = Notification.Name("ETCDeviceDidDisconnect")
    static let ETCDeviceDidDetectCardInsertion = Notification.Name("ETCDeviceDidDetectCardInsertion") // Physically inserted by human
    static let ETCDeviceDidDetectCardEjection = Notification.Name("ETCDeviceDidDetectCardEjection") // Physically ejected by human
    static let ETCDeviceDidUpdateCurrentCard = Notification.Name("ETCDeviceDidUpdateCurrentCard")
}

class ETCDeviceManager: NSObject, SerialPortManagerDelegate, ETCDeviceConnectionDelegate {
    static let cardUUIDNamespace = UUID(uuidString: "AE12B12B-2DD8-4FAB-9AD3-67FB3A15E12C")!

    @objc dynamic var database: ETCDatabase? {
        didSet {
            if database != nil, isConnected, let connection = connection {
                connection.send(ETCMessageToDevice.cardExistenceRequest)
            }
        }
    }

    lazy var serialPortManager = BLESerialPortManager(delegate: self)

    var connection: ETCDeviceConnection?

    var isConnected: Bool {
        return connection?.isEstablished ?? false
    }

    var currentCard: ETCCard? {
        didSet {
            notificationCenter.post(name: .ETCDeviceDidUpdateCurrentCard, object: self)

            if shouldNotifyOfCardInsertionOrEjection {
                if oldValue == nil, let insertedCard = currentCard {
                    notificationCenter.post(name: .ETCDeviceDidDetectCardInsertion, object: self)
                    UserNotificationCenter.shared.requestDelivery(ETCCardInsertionNotification(insertedCard: insertedCard))
                } else if oldValue != nil && currentCard == nil {
                    notificationCenter.post(name: .ETCDeviceDidDetectCardEjection, object: self)
                    UserNotificationCenter.shared.requestDelivery(ETCCardEjectionNotification())
                }

                shouldNotifyOfCardInsertionOrEjection = false
            }

            if let mainCardUUID = Defaults.shared.mainETCCardUUID, currentCard?.uuid != mainCardUUID, justConnected {
                UserNotificationCenter.shared.requestDelivery(NoMainETCCardNotification(currentCard: currentCard))
            }
        }
    }

    private var shouldNotifyOfCardInsertionOrEjection = false

    var justConnected: Bool {
        get {
            if let lastConnectionTime = lastConnectionTime {
                return Date().timeIntervalSince(lastConnectionTime) < 3
            } else {
                return false
            }
        }

        set {
            if newValue {
                lastConnectionTime = Date()
            } else {
                lastConnectionTime = nil
            }
        }
    }

    private var lastConnectionTime: Date?

    var justReceivedPaymentNotification: Bool {
        get {
            if let lastPaymentNotificationTime = lastPaymentNotificationTime {
                return Date().timeIntervalSince(lastPaymentNotificationTime) < 3
            } else {
                return false
            }
        }

        set {
            if newValue {
                lastPaymentNotificationTime = Date()
            } else {
                lastPaymentNotificationTime = nil
            }
        }
    }

    private var lastPaymentNotificationTime: Date?

    var notificationCenter: NotificationCenter {
        return NotificationCenter.default
    }

    func connect() {
        serialPortManager.startDiscovery()
    }

    // MARK: - ETCSerialPortManagerDelegate

    func serialPortManager(_ serialPortManager: BLESerialPortManager, didFindSerialPort serialPort: SerialPort) {
        let connection = ETCDeviceConnection(serialPort: serialPort)
        connection.delegate = self
        connection.start()
        self.connection = connection
    }

    func serialPortManager(_ serialPortManager: BLESerialPortManager, didLoseSerialPort serialPort: SerialPort) {
        connection = nil
        shouldNotifyOfCardInsertionOrEjection = false
        currentCard = nil
        notificationCenter.post(name: .ETCDeviceDidDisconnect, object: self)
    }

    // MARK: - ETCDeviceConnectionDelegate

    func connectionDidEstablish(_ connection: ETCDeviceConnection) {
        justConnected = true
        notificationCenter.post(name: .ETCDeviceDidConnect, object: self)

        if database != nil {
            connection.send(ETCMessageToDevice.cardExistenceRequest)
        }
    }

    func connection(_ connection: ETCDeviceConnection, didReceiveMessage message: ETCMessageFromDeviceProtocol) {
        switch message {
        case is ETCMessageFromDevice.CardExistenceResponse:
            connection.send(ETCMessageToDevice.uniqueCardDataRequest)
        case let response as ETCMessageFromDevice.UniqueCardDataResponse:
            handleUniqueCardDataResponse(response)
        case is ETCMessageFromDevice.CardNonExistenceResponse:
            currentCard = nil
        case is ETCMessageFromDevice.InitialPaymentRecordExistenceResponse:
            connection.send(ETCMessageToDevice.initialPaymentRecordRequest)
        case let response as ETCMessageFromDevice.PaymentRecordResponse:
            handlePaymentRecordResponse(response)
        case is ETCMessageFromDevice.GateEntranceNotification, is ETCMessageFromDevice.GateExitNotification:
            UserNotificationCenter.shared.requestDelivery(TollgatePassingThroughNotification())
        case is ETCMessageFromDevice.PaymentNotification:
            justReceivedPaymentNotification = true
            connection.send(ETCMessageToDevice.initialPaymentRecordRequest)
        case is ETCMessageFromDevice.CardInsertionNotification:
            shouldNotifyOfCardInsertionOrEjection = true
            connection.send(ETCMessageToDevice.cardExistenceRequest)
        case is ETCMessageFromDevice.CardEjectionNotification:
            shouldNotifyOfCardInsertionOrEjection = true
            currentCard = nil
        default:
            break
        }
    }

    // MARK: - Internal

    func handleUniqueCardDataResponse(_ response: ETCMessageFromDevice.UniqueCardDataResponse) {
        let cardData = Data(response.payloadBytes)
        let cardUUID = UUID(version: .v5, namespace: ETCDeviceManager.cardUUIDNamespace, name: cardData)

        if let database = database {
            Task {
                currentCard = try await database.findOrCreateCard(uuid: cardUUID)
                connection?.send(ETCMessageToDevice.initialPaymentRecordRequest)
            }
        }
    }

    func handlePaymentRecordResponse(_ response: ETCMessageFromDevice.PaymentRecordResponse) {
        guard let payment = response.payment else { return }

        if justReceivedPaymentNotification {
            justReceivedPaymentNotification = false
            UserNotificationCenter.shared.requestDelivery(PaymentNotification(payment: payment))
        }

        if let database = database, let currentCard = currentCard {
            Task {
                if !(try await database.hasSaved(payment)) {
                    try database.save(payment, for: currentCard)
                    connection?.send(ETCMessageToDevice.nextPaymentRecordRequest)
                }
            }
        }
    }
}
