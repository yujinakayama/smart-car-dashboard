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
}

public class ClassicBluetoothManager {
    public weak var delegate: ClassicBluetoothManagerDelegate? = nil

    private let bluetoothManagerHandler = BluetoothManagerHandler.sharedInstance()!

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
        addNotificationObserver()
    }

    private func addNotificationObserver() {
        NotificationCenter.default.addObserver(forName: .BluetoothAvailabilityChanged, object: nil, queue: nil) { [weak self] (notification) in
            guard let self = self else { return }
            self.delegate?.classicBluetoothManagerDidChangeAvailability(self)
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
