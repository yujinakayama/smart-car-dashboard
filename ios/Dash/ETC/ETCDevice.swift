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
    static let ETCDeviceDidFinishDataStorePreparation = Notification.Name("ETCDeviceDidFinishDataStorePreparation")
    static let ETCDeviceDidConnect = Notification.Name("ETCDeviceDidConnect")
    static let ETCDeviceDidDisconnect = Notification.Name("ETCDeviceDidDisconnect")
    static let ETCDeviceDidDetectCardInsertion = Notification.Name("ETCDeviceDidDetectCardInsertion") // Physically inserted by human
    static let ETCDeviceDidDetectCardEjection = Notification.Name("ETCDeviceDidDetectCardEjection") // Physically ejected by human
}

class ETCDevice: NSObject, SerialPortManagerDelegate, ETCDeviceConnectionDelegate {
    static let cardUUIDNamespace = UUID(uuidString: "AE12B12B-2DD8-4FAB-9AD3-67FB3A15E12C")!

    let dataStore = ETCDataStore(name: "Dash")
    var serialPortManager: BLESerialPortManager?
    var connection: ETCDeviceConnection?

    var isConnected: Bool {
        return connection?.isEstablished ?? false
    }

    @objc dynamic var currentCard: ETCCardManagedObject? {
        didSet {
            dataStore.currentCard = currentCard

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

    func startPreparation() {
        dataStore.loadPersistantStores { [unowned self] (persistentStoreDescription, error) in
            logger.debug(persistentStoreDescription)

            if let error = error {
                logger.severe(error)
                fatalError()
            }

            self.notificationCenter.post(name: .ETCDeviceDidFinishDataStorePreparation, object: self)

            self.setupSerialPortManager()
        }
    }

    func setupSerialPortManager() {
        let serialPortManager = BLESerialPortManager(delegate: self)
        serialPortManager.startDiscovery()
        self.serialPortManager = serialPortManager
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

        connection.send(ETCMessageToDevice.cardExistenceRequest)
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
        let cardUUID = UUID(version: .v5, namespace: ETCDevice.cardUUIDNamespace, name: cardData)

        guard let connection = connection else { return }

        dataStore.performBackgroundTask { [unowned self] (context) in
            do {
                let card = try self.dataStore.findOrInsertCard(uuid: cardUUID, in: context)
                try context.save()
                self.currentCard = card
                connection.send(ETCMessageToDevice.initialPaymentRecordRequest)
            } catch {
                logger.error(error)
            }
        }
    }

    func handlePaymentRecordResponse(_ response: ETCMessageFromDevice.PaymentRecordResponse) {
        guard let payment = response.payment else { return }

        if justReceivedPaymentNotification {
            justReceivedPaymentNotification = false
            UserNotificationCenter.shared.requestDelivery(PaymentNotification(payment: payment))
        }

        guard let connection = connection else { return }

        dataStore.performBackgroundTask { [unowned self] (context) in
            do {
                if try self.dataStore.checkExistence(of: payment, in: context) {
                    return
                }

                try self.dataStore.insert(payment: payment, into: context)
                try context.save()
                connection.send(ETCMessageToDevice.nextPaymentRecordRequest)
            } catch {
                logger.error(error)
            }
        }
    }
}
