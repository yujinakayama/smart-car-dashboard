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
    func peripheral(_ peripheral: BLERemotePeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
}

class BLERemotePeripheral: NSObject, CBPeripheralDelegate {
    let peripheral: CBPeripheral

    weak var delegate: BLERemotePeripheralDelegate?

    let serviceUUID: CBUUID

    var isConnected = false

    private var characteristicsDiscoveryContinuation: CheckedContinuation<[CBCharacteristic], Error>?

    init(_ peripheral: CBPeripheral, serviceUUID: CBUUID) {
        self.peripheral = peripheral
        self.serviceUUID = serviceUUID
        super.init()
        self.peripheral.delegate = self
    }

    func discoverCharacteristics() async throws -> [CBCharacteristic] {
        logger.verbose()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CBCharacteristic], Error>) in
            self.characteristicsDiscoveryContinuation = continuation
            peripheral.discoverServices([serviceUUID])
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logger.verbose(error)

        if let targetService = peripheral.services?.first(where: { $0.uuid == serviceUUID }) {
            peripheral.discoverCharacteristics(nil, for: targetService)
        } else {
            characteristicsDiscoveryContinuation?.resume(throwing: BLERemotePeripheralError.serviceNotFound)
            characteristicsDiscoveryContinuation = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        logger.verbose(error)

        guard service.uuid == serviceUUID else { return }

        guard let continuation = characteristicsDiscoveryContinuation else { return }
        characteristicsDiscoveryContinuation = nil

        if let error = error {
            continuation.resume(throwing: error)
            return
        }

        continuation.resume(returning: service.characteristics ?? [])
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        logger.verbose(error)
        delegate?.peripheral(self, didUpdateValueFor: characteristic, error: error)
    }
}

enum BLERemotePeripheralError: Error {
    case serviceNotFound
}
