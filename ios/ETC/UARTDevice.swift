//
//  UARTDevice.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/04.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol UARTDeviceDelegate: NSObjectProtocol {
    func deviceDidFinishPreparation(_ device: UARTDevice, error: Error?)
    func device(_ device: UARTDevice, didReceiveData data: Data)
}

protocol UARTDevice: NSObjectProtocol {
    var delegate: UARTDeviceDelegate? { get set }
    func startPreparation()
    func write(_ data: Data) throws
}
