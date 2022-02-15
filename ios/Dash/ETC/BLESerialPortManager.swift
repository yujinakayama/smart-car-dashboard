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

    // https://qiita.com/shu223/items/f67f1b0fb1840cf0bd63#トラブル2-接続に失敗する
    private var discoveredPeripherals: [CBPeripheral] = []

    private var serialPorts: [CBPeripheral: SerialPort] = [:]

    init(delegate: SerialPortManagerDelegate) {
        self.delegate = delegate
        super.init()
    }

    func startDiscovery() {
        #if targetEnvironment(simulator)
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        //     guard let self = self else { return }
        //     let serialPort = MockSerialPort()
        //     self.delegate?.serialPortManager(self, didFindSerialPort: serialPort)
        // }
        #else
        _ = centralManager // Invokes centralManagerDidUpdateState()
        #endif
    }

    private func findCurrentlyConnectedPeripheralOrStartScanning() {
        logger.info()

        if let peripheral = currentlyConnectedPeripheral {
            didDiscoverPeripheral(peripheral)
        } else {
            startScanning()
        }
    }

    private var currentlyConnectedPeripheral: CBPeripheral? {
        // The list of connected peripherals can include those that other apps have connected.
        // You need to connect these peripherals locally using the connect(_:options:) method before using them.
        let peripherals = centralManager.retrieveConnectedPeripherals(withServices: [BLESerialPort.serviceUUID])
        return peripherals.first
    }

    private func didDiscoverPeripheral(_ peripheral: CBPeripheral) {
        discoveredPeripherals.append(peripheral)

        if peripheral.state == .connected {
            Task {
                await discoverCharacteristicsAndNotify(peripheral: peripheral)
            }
        } else {
            centralManager.connect(peripheral, options: nil)
        }
    }

    private func discoverCharacteristicsAndNotify(peripheral: CBPeripheral) async {
        do {
            let discovery = BLECharacteristicsDiscovery(peripheral: peripheral)
            let characteristics = try await discovery.discoverCharacteristics(in: BLESerialPort.serviceUUID)
            let serialPort = try BLESerialPort(peripheral: peripheral, characteristics: characteristics)
            serialPorts[peripheral] = serialPort
            delegate?.serialPortManager(self, didFindSerialPort: serialPort)
        } catch {
            logger.error(error)
        }
    }

    private func startScanning() {
        logger.info()
        centralManager.scanForPeripherals(withServices: [BLESerialPort.serviceUUID], options: nil)
    }
}

extension BLESerialPortManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info(centralManager.state.rawValue)

        if centralManager.state == .poweredOn {
            findCurrentlyConnectedPeripheralOrStartScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        logger.info((peripheral, advertisementData, RSSI))
        centralManager.stopScan()
        didDiscoverPeripheral(peripheral)
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

        if let serialPort = serialPorts[peripheral] {
            delegate?.serialPortManager(self, didLoseSerialPort: serialPort)
            serialPorts.removeValue(forKey: peripheral)
        }

        centralManager.connect(peripheral, options: nil)
    }
}
