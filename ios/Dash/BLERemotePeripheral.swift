//
//  BLEPeripheral.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/29.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BLERemotePeripheralDelegate: NSObjectProtocol {
    func peripheral(_ peripheral: BLERemotePeripheral, didDiscoverCharacteristics characteristics: [CBCharacteristic], error: Error?)
    func peripheral(_ peripheral: BLERemotePeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
}

class BLERemotePeripheral: NSObject, CBPeripheralDelegate {
    let peripheral: CBPeripheral

    weak var delegate: BLERemotePeripheralDelegate?

    let serviceUUID: CBUUID

    var isConnected = false

    var services: [CBService]? {
        return peripheral.services
    }

    init(_ peripheral: CBPeripheral, serviceUUID: CBUUID) {
        self.peripheral = peripheral
        self.serviceUUID = serviceUUID
        super.init()
        self.peripheral.delegate = self
    }

    func startDiscoveringCharacteristics() {
        logger.verbose()
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logger.verbose(error)

        let targetService = peripheral.services?.first(where: { (service) -> Bool in
            service.uuid == serviceUUID
        })

        if let targetService = targetService {
            peripheral.discoverCharacteristics(nil, for: targetService)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        logger.verbose(error)

        if service.uuid == serviceUUID {
            delegate?.peripheral(self, didDiscoverCharacteristics: service.characteristics!, error: error)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        logger.verbose(error)
        delegate?.peripheral(self, didUpdateValueFor: characteristic, error: error)
    }
}
