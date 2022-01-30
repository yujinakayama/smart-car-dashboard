//
//  UARTDevice.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/04.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol SerialPortDelegate: NSObjectProtocol {
    func serialPort(_ serialPort: SerialPort, didReceiveData data: Data)
}

protocol SerialPort: NSObjectProtocol {
    var delegate: SerialPortDelegate? { get set }
    func transmit(_ data: Data)
}
