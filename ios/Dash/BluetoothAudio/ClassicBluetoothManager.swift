/*
 This file is part of BeeTee Project. It is subject to the license terms in the LICENSE file found in the top-level directory of this distribution and at https://github.com/michaeldorner/BeeTee/blob/master/LICENSE. No part of BeeTee Project, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the LICENSE file.
 */

import Foundation

extension Notification.Name {
    static let BluetoothPowerChanged            = Notification.Name("BluetoothPowerChangedNotification")
    static let BluetoothAvailabilityChanged     = Notification.Name("BluetoothAvailabilityChangedNotification")
    static let BluetoothDeviceDiscovered        = Notification.Name("BluetoothDeviceDiscoveredNotification")
    static let BluetoothDeviceRemoved           = Notification.Name("BluetoothDeviceRemovedNotification")
    static let BluetoothConnectabilityChanged   = Notification.Name("BluetoothConnectabilityChangedNotification")
    static let BluetoothDeviceUpdated           = Notification.Name("BluetoothDeviceUpdatedNotification")
    static let BluetoothDiscoveryStateChanged   = Notification.Name("BluetoothDiscoveryStateChangedNotification")
    static let BluetoothDeviceConnectSuccess    = Notification.Name("BluetoothDeviceConnectSuccessNotification")
    static let BluetoothConnectionStatusChanged = Notification.Name("BluetoothConnectionStatusChangedNotification")
    static let BluetoothDeviceDisconnectSuccess = Notification.Name("BluetoothDeviceDisconnectSuccessNotification")
}

public protocol ClassicBluetoothManagerDelegate: NSObjectProtocol {
    func classicBluetoothManagerDidChangeAvailability(_ manager: ClassicBluetoothManager)
    func classicBluetoothManager(_ manager: ClassicBluetoothManager, didConnectToDevice device: ClassicBluetoothDevice)
}

public class ClassicBluetoothManager {
    public weak var delegate: ClassicBluetoothManagerDelegate? = nil

    private let bluetoothManagerHandler = BluetoothManagerHandler.sharedInstance()!

    private let latestNotificationHistory = LatestNotificationHistory()

    public var pairedDevices: [ClassicBluetoothDevice] {
        return bluetoothManagerHandler.pairedDevices().map { ClassicBluetoothDevice(device: $0) }
    }

    public var isAvailable: Bool {
        return bluetoothManagerHandler.available()
    }

    public var isConnectable: Bool {
        return bluetoothManagerHandler.connectable()
    }

    public init() {
        addNotificationObservers()
    }

    private func addNotificationObservers() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(self, selector: #selector(sendMessageToDelegateWithThrottle), name: .BluetoothAvailabilityChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(sendMessageToDelegateWithThrottle), name: .BluetoothDeviceConnectSuccess, object: nil)
    }

    @objc private func sendMessageToDelegateWithThrottle(notification: Notification) {
        if !latestNotificationHistory.contains(where: { $0.name == notification.name }) {
            sendMessageToDelegate(notification: notification)
        }

        latestNotificationHistory.append(notification)
    }

    private func sendMessageToDelegate(notification: Notification) {
        switch notification.name {
        case .BluetoothAvailabilityChanged:
            delegate?.classicBluetoothManagerDidChangeAvailability(self)
        case .BluetoothDeviceConnectSuccess:
            let device = BluetoothDeviceHandler(notification: notification)!
            delegate?.classicBluetoothManager(self, didConnectToDevice: ClassicBluetoothDevice(device: device))
        default:
            break
        }
    }

    public static func debugLowLevel() {
        print("This is a dirty C hack and only for demonstration and deep debugging, but not for production.") // credits to http://stackoverflow.com/a/3738387/1864294
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        nil,
                                        { (_, _, name, _, _) in
                                            guard let name = name else { return }
                                            let n = name.rawValue as String
                                            if n.hasPrefix("B") { // notice only notification they are associated with the BluetoothManager.framework
                                               print("Received notification: \(name)")
                                            }
                                        },
                                        nil,
                                        nil,
                                        .deliverImmediately)
    }
}

extension ClassicBluetoothManager {
    class LatestNotificationHistory {
        let dropOutTimeInterval: TimeInterval = 0.1

        private var notifications: [Notification] = []

        func append(_ notification: Notification) {
            notifications.append(notification)

            Timer.scheduledTimer(withTimeInterval: dropOutTimeInterval, repeats: false) { [weak self] (timer) in
                guard let self = self else { return }
                self.notifications.removeFirst()
            }
        }

        func contains(where predicate: (Notification) -> Bool) -> Bool {
            return notifications.contains(where: predicate)
        }
    }
}
