//
//  RearviewConfiguration.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2021/02/10.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import Network

public struct RearviewConfiguration: Equatable {
    let raspberryPiAddress: Address
    let digitalGainForLowLightMode: Float
    let digitalGainForUltraLowLightMode: Float
    let gammaAdjustmentPower: Float?

    public init(raspberryPiAddress: Address, digitalGainForLowLightMode: Float, digitalGainForUltraLowLightMode: Float, gammaAdjustmentPower: Float? = nil) {
        self.raspberryPiAddress = raspberryPiAddress
        self.digitalGainForLowLightMode = digitalGainForLowLightMode
        self.digitalGainForUltraLowLightMode = digitalGainForUltraLowLightMode
        self.gammaAdjustmentPower = gammaAdjustmentPower
    }

    public struct Address: Equatable {
        let ipv4Address: IPv4Address
        let string: String

        public init?(_ string: String) {
            guard let ipv4Address = IPv4Address(string) else { return nil }
            self.ipv4Address = ipv4Address
            self.string = string
        }
    }
}
