//
//  BLERemotePeripheralManager.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/29.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BLERemotePeripheralManagerDelegate: NSObjectProtocol {
    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didUpdateAvailability available: Bool)
    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didDiscoverPeripheral peripheral: BLERemotePeripheral)
    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didConnectToPeripheral peripheral: BLERemotePeripheral)
    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didFailToConnectToPeripheral peripheral: BLERemotePeripheral, error: Error?)
    func peripheralManager(_ peripheralManager: BLERemotePeripheralManager, didDisconnectToPeripheral peripheral: BLERemotePeripheral, error: Error?)
}

class BLERemotePeripheralManager: NSObject, CBCentralManagerDelegate {
    weak var delegate: BLERemotePeripheralManagerDelegate?

    let serviceUUID: CBUUID

    private lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: nil)
    }()

    private var connectingPeripherals = [CBPeripheral: BLERemotePeripheral]()

    // MARK: Initialization

    init(delegate: BLERemotePeripheralManagerDelegate, serviceUUID: CBUUID) {
        self.delegate = delegate
        self.serviceUUID = serviceUUID
        super.init()
        _ = centralManager // Invokes centralManagerDidUpdateState()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(#function)
        let availability = centralManager.state == .poweredOn
        delegate?.peripheralManager(self, didUpdateAvailability: availability)
    }

    // MARK: Peripheral Discovery

    func startDiscovering() {
        let peripheral = discoverConnectedPeripheral()

        if let peripheral = peripheral {
            didDiscover(peripheral)
        } else {
            startScanning()
        }
    }

    func stopDiscovering() {
        centralManager.stopScan()
    }

    private func discoverConnectedPeripheral() -> CBPeripheral? {
        let peripherals = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
        return peripherals.first
    }

    private func startScanning() {
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(#function)
        didDiscover(peripheral)
    }

    private func didDiscover(_ peripheral: CBPeripheral) {
        let remotePeripheral = BLERemotePeripheral(peripheral, serviceUUID: serviceUUID)
        delegate?.peripheralManager(self, didDiscoverPeripheral: remotePeripheral)
    }

    // MARK: Peripheral Connection

    func connect(to peripheral: BLERemotePeripheral) {
        connectingPeripherals[peripheral.peripheral] = peripheral
        centralManager.connect(peripheral.peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print(#function)
        let remotePeripheral = connectingPeripherals[peripheral]!
        remotePeripheral.isConnected = true
        delegate?.peripheralManager(self, didConnectToPeripheral: remotePeripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print(#function)
        let remotePeripheral = connectingPeripherals[peripheral]!
        remotePeripheral.isConnected = false
        delegate?.peripheralManager(self, didFailToConnectToPeripheral: connectingPeripherals[peripheral]!, error: error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print(#function)
        let remotePeripheral = connectingPeripherals[peripheral]!
        remotePeripheral.isConnected = false
        delegate?.peripheralManager(self, didDisconnectToPeripheral: connectingPeripherals[peripheral]!, error: error)
    }
}
