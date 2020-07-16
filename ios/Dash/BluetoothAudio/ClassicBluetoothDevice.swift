/*
 This file is part of BeeTee Project. It is subject to the license terms in the LICENSE file found in the top-level directory of this distribution and at https://github.com/michaeldorner/BeeTee/blob/master/LICENSE. No part of BeeTee Project, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the LICENSE file.
 */

import Foundation


public class ClassicBluetoothDevice: Hashable, CustomStringConvertible {
    let device: BluetoothDeviceHandler
    let detectingDate: Date

    convenience init(notification: Notification) {
        let device = BluetoothDeviceHandler(notification: notification)!
        self.init(device: device)
    }
    
    init(device: BluetoothDeviceHandler, detectingDate: Date = Date()) {
        self.device = device
        self.detectingDate = detectingDate
    }

    var name: String {
        return device.name
    }

    var address: String {
        return device.address
    }

    var majorClass: UInt {
        return device.majorClass
    }

    var minorCass: UInt {
        return device.minorClass
    }

    var type: Int {
        return device.type
    }

    var supportsBatteryLevel: Bool {
        return device.supportsBatteryLevel
    }

    var isConnected: Bool {
        return device.isConnected
    }

    public var description: String {
        return "\(name) (\(address)) @ \(detectingDate))"
    }

    public func connect() {
        device.connect()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(address)
    }

    public static func ==(lhs: ClassicBluetoothDevice, rhs: ClassicBluetoothDevice) -> Bool {
        return lhs.address == rhs.address
    }
}
