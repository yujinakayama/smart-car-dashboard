//
//  ETCDeviceManager.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/29.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol ETCDeviceManagerDelegate: NSObjectProtocol {
    func deviceManager(_ deviceManager: ETCDeviceManager, didConnectToDevice deviceConnection: ETCDeviceConnection)
    func deviceManager(_ deviceManager: ETCDeviceManager, didDisconnectToDevice deviceConnection: ETCDeviceConnection)
}

class ETCDeviceManager: NSObject, BLERemotePeripheralManagerDelegate {
    weak var delegate: ETCDeviceManagerDelegate?

    lazy var peripheralManager: BLERemotePeripheralManager = {
        let peripheralManager = BLERemotePeripheralManager(delegate: self, serviceUUID: BLESerialPort.serviceUUID)
        peripheralManager.delegate = self
        return peripheralManager
    }()

    private var connections = [BLERemotePeripheral: ETCDeviceConnection]()

    init(delegate: ETCDeviceManagerDelegate) {
        self.delegate = delegate
        super.init()
    }

    func startDiscovering() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let serialPort = MockSerialPort()
            let deviceConnection = ETCDeviceConnection(serialPort: serialPort)
            self.delegate?.deviceManager(self, didConnectToDevice: deviceConnection)
        }
        #else
        _ = peripheralManager
        #endif
    }

    // MARK: BLERemotePeripheralManagerDelegate

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didUpdateAvailability available: Bool) {
        logger.info(available)

        if (available) {
            peripheralManager.startDiscovering()
        }
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didDiscoverPeripheral peripheral: BLERemotePeripheral) {
        logger.info(peripheral)
        peripheralManager.stopDiscovering()
        peripheralManager.connect(to: peripheral)
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didConnectToPeripheral peripheral: BLERemotePeripheral) {
        logger.info(peripheral)
        let serialPort = BLESerialPort(peripheral: peripheral)
        let deviceConnection = ETCDeviceConnection(serialPort: serialPort)
        connections[peripheral] = deviceConnection
        delegate?.deviceManager(self, didConnectToDevice: deviceConnection)
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didFailToConnectToPeripheral peripheral: BLERemotePeripheral, error: Error?) {
        logger.info((peripheral, error))
        peripheralManager.connect(to: peripheral)
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didDisconnectToPeripheral peripheral: BLERemotePeripheral, error: Error?) {
        logger.info((peripheral, error))

        if let deviceConnection = connections[peripheral] {
            delegate?.deviceManager(self, didDisconnectToDevice: deviceConnection)
            connections.removeValue(forKey: peripheral)
        }

        peripheralManager.connect(to: peripheral)
    }
}
