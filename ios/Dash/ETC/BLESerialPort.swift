//
//  UARTDevice.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/30.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreBluetooth

fileprivate func hexString(_ data: Data) -> String {
    return data.map { String(format: "%02X", $0) }.joined(separator: " ")
}

enum BLESerialPortError: Error {
    case txCharacteristicNotFound
    case rxCharacteristicNotFound
}

class BLESerialPort: NSObject, SerialPort, BLERemotePeripheralDelegate, CBPeripheralDelegate {
    static let serviceUUID          = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let txCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let rxCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    let peripheral: BLERemotePeripheral

    weak var delegate: SerialPortDelegate?

    var isAvailable: Bool {
        return peripheral.isConnected
    }

    var txCharacteristic: CBCharacteristic
    var rxCharacteristic: CBCharacteristic

    init(peripheral: BLERemotePeripheral, characteristics: [CBCharacteristic]) throws {
        self.peripheral = peripheral

        guard let txCharacteristic = characteristics.first(where: { $0.uuid == BLESerialPort.txCharacteristicUUID }) else {
            throw BLESerialPortError.txCharacteristicNotFound
        }

        self.txCharacteristic = txCharacteristic
        peripheral.peripheral.setNotifyValue(true, for: txCharacteristic)

        guard let rxCharacteristic = characteristics.first(where: { $0.uuid == BLESerialPort.rxCharacteristicUUID }) else {
            throw BLESerialPortError.rxCharacteristicNotFound
        }

        self.rxCharacteristic = rxCharacteristic

        super.init()

        peripheral.delegate = self
    }

    func transmit(_ data: Data) {
        logger.verbose(hexString(data))
        peripheral.peripheral.writeValue(data, for: rxCharacteristic, type: .withoutResponse)
    }

    func peripheral(_ peripheral: BLERemotePeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else { return }

        logger.verbose(hexString(value))

        if characteristic == txCharacteristic && error == nil {
            delegate?.serialPort(self, didReceiveData: value)
        }
    }
}
