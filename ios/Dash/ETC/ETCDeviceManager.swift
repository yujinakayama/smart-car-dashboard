//
//  ETCDevice.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let ETCDeviceManagerDidConnect = Notification.Name("ETCDeviceManagerDidConnect")
    static let ETCDeviceManagerDidDisconnect = Notification.Name("ETCDeviceManagerDidDisconnect")
    static let ETCDeviceManagerDidDetectCardInsertion = Notification.Name("ETCDeviceManagerDidDetectCardInsertion") // Physically inserted by human
    static let ETCDeviceManagerDidDetectCardEjection = Notification.Name("ETCDeviceManagerDidDetectCardEjection") // Physically ejected by human
    static let ETCDeviceManagerDidUpdateCurrentCard = Notification.Name("ETCDeviceManagerDidUpdateCurrentCard")
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
            notificationCenter.post(name: .ETCDeviceManagerDidUpdateCurrentCard, object: self)

            if shouldNotifyOfCardInsertionOrEjection {
                if oldValue == nil, let insertedCard = currentCard {
                    notificationCenter.post(name: .ETCDeviceManagerDidDetectCardInsertion, object: self)
                    UserNotificationCenter.shared.requestDelivery(ETCCardInsertionNotification(insertedCard: insertedCard))
                } else if oldValue != nil && currentCard == nil {
                    notificationCenter.post(name: .ETCDeviceManagerDidDetectCardEjection, object: self)
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

    private var lastPendingGateEntranceDate: Date? {
        get {
            if let date = Defaults.shared.lastPendingETCGateEntranceDate,
               date.distance(to: Date()) < 24 * 60 * 60
            {
                return date
            } else {
                return nil
            }
        }

        set {
            Defaults.shared.lastPendingETCGateEntranceDate = newValue
        }
    }


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
        notificationCenter.post(name: .ETCDeviceManagerDidDisconnect, object: self)
    }

    // MARK: - ETCDeviceConnectionDelegate

    func connectionDidEstablish(_ connection: ETCDeviceConnection) {
        justConnected = true
        notificationCenter.post(name: .ETCDeviceManagerDidConnect, object: self)

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
        case is ETCMessageFromDevice.GateEntranceNotification:
            if lastPendingGateEntranceDate == nil {
                lastPendingGateEntranceDate = Date()
            }
            UserNotificationCenter.shared.requestDelivery(TollgatePassingThroughNotification())
        case is ETCMessageFromDevice.GateExitNotification:
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
        guard var payment = response.payment else { return }

        if justReceivedPaymentNotification {
            justReceivedPaymentNotification = false

            // When received GateEntranceNotification and PaymentNotification at a same tollbooth,
            // payment.exitDate tends to be 1-3 seconds earlier than lastPendingGateEntranceDate.
            if let lastPendingGateEntranceDate = lastPendingGateEntranceDate,
               lastPendingGateEntranceDate < payment.exitDate
            {
                payment.entranceDate = lastPendingGateEntranceDate
            }

            lastPendingGateEntranceDate = nil

            UserNotificationCenter.shared.requestDelivery(PaymentNotification(payment: payment))
        }

        if let database = database, let currentCard = currentCard {
            let payment = payment

            Task {
                if !(try await database.hasSaved(payment)) {
                    try database.save(payment, for: currentCard)
                    connection?.send(ETCMessageToDevice.nextPaymentRecordRequest)
                }
            }
        }
    }
}
