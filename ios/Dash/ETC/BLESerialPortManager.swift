//
//  ETCserialPortManager.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/29.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol SerialPortManagerDelegate: NSObjectProtocol {
    func serialPortManager(_ serialPortManager: BLESerialPortManager, didFindSerialPort serialPort: SerialPort)
    func serialPortManager(_ serialPortManager: BLESerialPortManager, didLoseSerialPort serialPort: SerialPort)
}

class BLESerialPortManager: NSObject {
    weak var delegate: SerialPortManagerDelegate?

    private lazy var centralManager = CBCentralManager(delegate: self, queue: nil)

    private var connectedSerialPorts = [CBPeripheral: SerialPort]()

    init(delegate: SerialPortManagerDelegate) {
        self.delegate = delegate
        super.init()
    }

    func startDiscovery() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let serialPort = MockSerialPort()
            self.delegate?.serialPortManager(self, didFindSerialPort: serialPort)
        }
        #else
        _ = centralManager // Invokes centralManagerDidUpdateState()
        #endif
    }

    private func findCurrentlyConnectedPeripheralOrStartScanning() {
        logger.info()

        if let peripheral = currentlyConnectedPeripheral {
            Task {
                await discoverCharacteristicsAndNotify(peripheral: peripheral)
            }
        } else {
            startScanning()
        }
    }

    private var currentlyConnectedPeripheral: CBPeripheral? {
        let peripherals = centralManager.retrieveConnectedPeripherals(withServices: [BLESerialPort.serviceUUID])
        return peripherals.first
    }

    private func startScanning() {
        logger.info()
        centralManager.scanForPeripherals(withServices: [BLESerialPort.serviceUUID], options: nil)
    }

    private func discoverCharacteristicsAndNotify(peripheral: CBPeripheral) async {
        do {
            let discovery = BLECharacteristicsDiscovery(peripheral: peripheral)
            let characteristics = try await discovery.discoverCharacteristics(in: BLESerialPort.serviceUUID)
            let serialPort = try BLESerialPort(peripheral: peripheral, characteristics: characteristics)
            connectedSerialPorts[peripheral] = serialPort
            delegate?.serialPortManager(self, didFindSerialPort: serialPort)
        } catch {
            logger.error(error)
        }
    }
}

extension BLESerialPortManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info(centralManager.state)

        if centralManager.state == .poweredOn {
            findCurrentlyConnectedPeripheralOrStartScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        logger.info((peripheral, advertisementData, RSSI))

        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info(peripheral)

        Task {
            await discoverCharacteristicsAndNotify(peripheral: peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.info((peripheral, error))
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info((peripheral, error))

        if let serialPort = connectedSerialPorts[peripheral] {
            delegate?.serialPortManager(self, didLoseSerialPort: serialPort)
            connectedSerialPorts.removeValue(forKey: peripheral)
        }

        centralManager.connect(peripheral, options: nil)
    }
}
