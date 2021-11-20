//
//  Vehicle.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/09.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

class Vehicle {
    static let `default` = Vehicle()

    let etcDevice = ETCDevice()

    func connect() {
        if Defaults.shared.isETCIntegrationEnabled {
            etcDevice.startPreparation()
        }
    }
}
