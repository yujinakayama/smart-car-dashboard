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

enum UARTDeviceError: Error {
    case txCharacteristicNotFound
    case rxCharacteristicNotFound
}

protocol UARTDeviceDelegate: NSObjectProtocol {
    func deviceDidFinishPreparation(_ device: UARTDevice, error: Error?)
    func device(_ device: UARTDevice, didReceiveData data: Data)
}

// TODO: Turn UARTDevice into a protocol so that we can abstract the underlying IO rather than concrete BLE
class UARTDevice: NSObject, BLERemotePeripheralDelegate, CBPeripheralDelegate {
    static let serviceUUID          = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let txCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let rxCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    let peripheral: BLERemotePeripheral

    weak var delegate: UARTDeviceDelegate?

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

    func write(_ data: Data) throws {
        guard rxCharacteristic != nil else {
            throw UARTDeviceError.rxCharacteristicNotFound
        }

        print("\(#function): \(hexString(data))")
        peripheral.peripheral.writeValue(data, for: rxCharacteristic!, type: .withoutResponse)
    }

    // MARK: BLERemotePeripheralDelegate

    func peripheral(_ peripheral: BLERemotePeripheral, didDiscoverCharacteristics characteristics: [CBCharacteristic], error: Error?) {
        print(#function)
        let txCharacteristic = characteristics.first { $0.uuid == UARTDevice.txCharacteristicUUID }
        guard txCharacteristic != nil else {
            delegate?.deviceDidFinishPreparation(self, error: UARTDeviceError.txCharacteristicNotFound)
            return
        }
        self.txCharacteristic = txCharacteristic!
        peripheral.peripheral.setNotifyValue(true, for: txCharacteristic!)

        let rxCharacteristic = characteristics.first { $0.uuid == UARTDevice.rxCharacteristicUUID }
        guard rxCharacteristic != nil else {
            delegate?.deviceDidFinishPreparation(self, error: UARTDeviceError.rxCharacteristicNotFound)
            return
        }
        self.rxCharacteristic = rxCharacteristic!

        delegate?.deviceDidFinishPreparation(self, error: nil)
    }

    // MARK: CBPeripheralDelegate

    func peripheral(_ peripheral: BLERemotePeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == txCharacteristic && error == nil {
            print("\(#function): \(hexString(characteristic.value!))")
            delegate?.device(self, didReceiveData: characteristic.value!)
        }
    }
}
