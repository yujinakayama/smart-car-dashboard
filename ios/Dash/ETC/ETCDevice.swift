//
//  ETCDevice.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreData

extension Notification.Name {
    static let ETCDeviceDidFinishDatabasePreparation = Notification.Name("ETCDeviceDidFinishDatabasePreparation")
    static let ETCDeviceDidConnect = Notification.Name("ETCDeviceDidConnect")
    static let ETCDeviceDidDetectCardInsertion = Notification.Name("ETCDeviceDidDetectCardInsertion")
    static let ETCDeviceDidDetectCardEjection = Notification.Name("ETCDeviceDidDetectCardEjection")
}

class ETCDevice: NSObject, SerialPortManagerDelegate, ETCDeviceConnectionDelegate {
    static let cardUUIDNamespace = UUID(uuidString: "AE12B12B-2DD8-4FAB-9AD3-67FB3A15E12C")!

    let database = ETCPaymentDatabase(name: "Dash")
    var serialPortManager: SerialPortManager?
    var connection: ETCDeviceConnection?

    var isConnected: Bool {
        return connection?.isAvailable ?? false
    }

    var currentCard: ETCCardManagedObject? {
        didSet {
            database.currentCard = currentCard
        }
    }

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

    func startPreparation() {
        database.loadPersistantStores { [unowned self] (persistentStoreDescription, error) in
            logger.debug(persistentStoreDescription)

            if let error = error {
                logger.severe(error)
                fatalError()
            }

            self.notificationCenter.post(name: .ETCDeviceDidFinishDatabasePreparation, object: self)

            self.setupSerialPortManager()
        }
    }

    func setupSerialPortManager() {
        serialPortManager = SerialPortManager(delegate: self)
        serialPortManager!.startDiscovering()
    }

    // MARK: - ETCSerialPortManagerDelegate

    func serialPortManager(_ serialPortManager: SerialPortManager, didFindSerialPort serialPort: SerialPort) {
        self.connection = ETCDeviceConnection(serialPort: serialPort)
        connection!.delegate = self
        connection!.startPreparation()
    }

    func serialPortManager(_ serialPortManager: SerialPortManager, didLoseSerialPort serialPort: SerialPort) {
        self.connection = nil
    }

    // MARK: - ETCDeviceConnectionDelegate

    func deviceConnectionDidFinishPreparation(_ connection: ETCDeviceConnection, error: Error?) {
        notificationCenter.post(name: .ETCDeviceDidConnect, object: self)
        try! connection.send(ETCMessageToDevice.cardExistenceRequest)
    }

    func deviceConnection(_ connection: ETCDeviceConnection, didReceiveMessage message: ETCMessageFromDeviceProtocol) {
        switch message {
        case is ETCMessageFromDevice.CardExistenceResponse:
            try! connection.send(ETCMessageToDevice.uniqueCardDataRequest)
        case let response as ETCMessageFromDevice.UniqueCardDataResponse:
            handleUniqueCardDataResponse(response)
        case is ETCMessageFromDevice.CardNonExistenceResponse:
            currentCard = nil
        case is ETCMessageFromDevice.InitialPaymentRecordExistenceResponse:
            try! connection.send(ETCMessageToDevice.initialPaymentRecordRequest)
        case let response as ETCMessageFromDevice.PaymentRecordResponse:
            handlePaymentRecordResponse(response)
        case is ETCMessageFromDevice.GateEntranceNotification, is ETCMessageFromDevice.GateExitNotification:
            UserNotificationCenter.shared.requestDelivery(TollgatePassingThroughNotification())
        case is ETCMessageFromDevice.PaymentNotification:
            justReceivedPaymentNotification = true
            try! connection.send(ETCMessageToDevice.initialPaymentRecordRequest)
        case is ETCMessageFromDevice.CardEjectionNotification:
            currentCard = nil
            notificationCenter.post(name: .ETCDeviceDidDetectCardEjection, object: self)
        default:
            break
        }
    }

    // MARK: - Internal

    func handleUniqueCardDataResponse(_ response: ETCMessageFromDevice.UniqueCardDataResponse) {
        let cardData = Data(response.payloadBytes)
        let cardUUID = UUID(version: .v5, namespace: ETCDevice.cardUUIDNamespace, name: cardData)

        database.performBackgroundTask { [unowned self] (context) in
            let card = try! self.database.findOrInsertCard(uuid: cardUUID, in: context)
            try! context.save()
            self.currentCard = card
            self.notificationCenter.post(name: .ETCDeviceDidDetectCardInsertion, object: self)
            try! self.connection!.send(ETCMessageToDevice.initialPaymentRecordRequest)
        }
    }

    func handlePaymentRecordResponse(_ response: ETCMessageFromDevice.PaymentRecordResponse) {
        guard let payment = response.payment else { return }

        if justReceivedPaymentNotification {
            justReceivedPaymentNotification = false
            UserNotificationCenter.shared.requestDelivery(PaymentNotification(payment: payment))
        }

        database.performBackgroundTask { [unowned self] (context) in
            let managedObject = try! self.database.insert(payment: payment, unlessExistsIn: context)
            if managedObject != nil {
                try! context.save()
                try! self.connection!.send(ETCMessageToDevice.nextPaymentRecordRequest)
            }
        }
    }
}
