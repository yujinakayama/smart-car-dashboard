//
//  ETCserialPortManager.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/29.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol SerialPortManagerDelegate: NSObjectProtocol {
    func serialPortManager(_ serialPortManager: SerialPortManager, didFindSerialPort serialPort: SerialPort)
    func serialPortManager(_ serialPortManager: SerialPortManager, didLoseSerialPort serialPort: SerialPort)
}

class SerialPortManager: NSObject, BLERemotePeripheralManagerDelegate {
    weak var delegate: SerialPortManagerDelegate?

    lazy var peripheralManager: BLERemotePeripheralManager = {
        let peripheralManager = BLERemotePeripheralManager(delegate: self, serviceUUID: BLESerialPort.serviceUUID)
        peripheralManager.delegate = self
        return peripheralManager
    }()

    private var connectedSerialPorts = [BLERemotePeripheral: SerialPort]()

    init(delegate: SerialPortManagerDelegate) {
        self.delegate = delegate
        super.init()
    }

    func startDiscovering() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let serialPort = MockSerialPort()
            self.delegate?.serialPortManager(self, didFindSerialPort: serialPort)
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

        Task {
            do {
                let characteristics = try await peripheral.discoverCharacteristics()
                let serialPort = try BLESerialPort(peripheral: peripheral, characteristics: characteristics)
                connectedSerialPorts[peripheral] = serialPort
                delegate?.serialPortManager(self, didFindSerialPort: serialPort)
            } catch {
                logger.error(error)
            }
        }
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didFailToConnectToPeripheral peripheral: BLERemotePeripheral, error: Error?) {
        logger.info((peripheral, error))
        peripheralManager.connect(to: peripheral)
    }

    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didDisconnectToPeripheral peripheral: BLERemotePeripheral, error: Error?) {
        logger.info((peripheral, error))

        if let serialPort = connectedSerialPorts[peripheral] {
            delegate?.serialPortManager(self, didLoseSerialPort: serialPort)
            connectedSerialPorts.removeValue(forKey: peripheral)
        }

        peripheralManager.connect(to: peripheral)
    }
}
