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

    var txCharacteristic: CBCharacteristic?
    var rxCharacteristic: CBCharacteristic?

    init(peripheral: BLERemotePeripheral) {
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }

    func startPreparation() {
        peripheral.startDiscoveringCharacteristics()
    }

    func transmit(_ data: Data) throws {
        guard rxCharacteristic != nil else {
            throw BLESerialPortError.rxCharacteristicNotFound
        }

        print("\(#function): \(hexString(data))")
        peripheral.peripheral.writeValue(data, for: rxCharacteristic!, type: .withoutResponse)
    }

    // MARK: BLERemotePeripheralDelegate

    func peripheral(_ peripheral: BLERemotePeripheral, didDiscoverCharacteristics characteristics: [CBCharacteristic], error: Error?) {
        print(#function)
        let txCharacteristic = characteristics.first { $0.uuid == BLESerialPort.txCharacteristicUUID }
        guard txCharacteristic != nil else {
            delegate?.serialPortDidFinishPreparation(self, error: BLESerialPortError.txCharacteristicNotFound)
            return
        }
        self.txCharacteristic = txCharacteristic!
        peripheral.peripheral.setNotifyValue(true, for: txCharacteristic!)

        let rxCharacteristic = characteristics.first { $0.uuid == BLESerialPort.rxCharacteristicUUID }
        guard rxCharacteristic != nil else {
            delegate?.serialPortDidFinishPreparation(self, error: BLESerialPortError.rxCharacteristicNotFound)
            return
        }
        self.rxCharacteristic = rxCharacteristic!

        delegate?.serialPortDidFinishPreparation(self, error: nil)
    }

    // MARK: CBPeripheralDelegate

    func peripheral(_ peripheral: BLERemotePeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == txCharacteristic && error == nil {
            print("\(#function): \(hexString(characteristic.value!))")
            delegate?.serialPort(self, didReceiveData: characteristic.value!)
        }
    }
}
