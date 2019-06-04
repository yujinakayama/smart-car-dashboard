//
//  ETCDeviceManager.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/29.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol ETCDeviceManagerDelegate: NSObjectProtocol {
    func deviceManager(_ deviceManager: ETCDeviceManager, didConnectToDevice device: ETCDevice)
    // TODO: More error handling
}

class ETCDeviceManager: NSObject, BLERemotePeripheralManagerDelegate {
    weak var delegate: ETCDeviceManagerDelegate?

    lazy var peripheralManager: BLERemotePeripheralManager = {
        let peripheralManager = BLERemotePeripheralManager(delegate: self, serviceUUID: BLEUARTDevice.serviceUUID)
        peripheralManager.delegate = self
        return peripheralManager
    }()

    init(delegate: ETCDeviceManagerDelegate) {
        self.delegate = delegate
        super.init()
        _ = peripheralManager
    }

    // MARK: BLERemotePeripheralManagerDelegate

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didUpdateAvailability available: Bool) {
        print(#function)
        if available {
            peripheralManager.startDiscovering()
        } else {
            // TODO
        }
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didDiscoverPeripheral peripheral: BLERemotePeripheral) {
        print(#function)
        peripheralManager.stopDiscovering()
        peripheralManager.connect(to: peripheral)
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didConnectToPeripheral peripheral: BLERemotePeripheral) {
        print(#function)
        let uartDevice = BLEUARTDevice(peripheral: peripheral)
        let etcDevice = ETCDevice(uartDevice: uartDevice)
        delegate?.deviceManager(self, didConnectToDevice: etcDevice)
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didFailToConnectToPeripheral peripheral: BLERemotePeripheral, error: Error?) {
        print(#function)
        if let error = error {
            print("\(#function): \(error)")
        }

        // TODO: Better handling
        peripheralManager.connect(to: peripheral)
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didDisconnectToPeripheral peripheral: BLERemotePeripheral, error: Error?) {
        print(#function)
        if let error = error {
            print("\(#function): \(error)")
        }

        // TODO: Better handling
        peripheralManager.connect(to: peripheral)
    }
}
