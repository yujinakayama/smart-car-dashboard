//
//  BLEPeripheral.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/29.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreBluetooth

class BLECharacteristicsDiscovery: NSObject {
    let peripheral: CBPeripheral

    private var continuation: CheckedContinuation<[CBCharacteristic], Error>?

    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        self.peripheral.delegate = self
    }

    func discoverCharacteristics(in serviceUUID: CBUUID) async throws -> [CBCharacteristic] {
        logger.debug()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CBCharacteristic], Error>) in
            self.continuation = continuation
            peripheral.discoverServices([serviceUUID])
        }
    }
}

extension BLECharacteristicsDiscovery: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logger.debug(error)
        guard let targetService = peripheral.services?.first else { return }
        peripheral.discoverCharacteristics(nil, for: targetService)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        logger.debug(error)

        guard let continuation = continuation else { return }
        self.continuation = nil

        if let error = error {
            continuation.resume(throwing: error)
            return
        }

        continuation.resume(returning: service.characteristics ?? [])
    }
}
