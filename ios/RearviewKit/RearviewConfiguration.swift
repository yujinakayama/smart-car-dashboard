//
//  RearviewConfiguration.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2021/02/10.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation

public struct RearviewConfiguration: Equatable {
    let raspberryPiAddress: String
    let digitalGainForLowLightMode: Float
    let digitalGainForUltraLowLightMode: Float

    public init(raspberryPiAddress: String, digitalGainForLowLightMode: Float, digitalGainForUltraLowLightMode: Float) {
        self.raspberryPiAddress = raspberryPiAddress
        self.digitalGainForLowLightMode = digitalGainForLowLightMode
        self.digitalGainForUltraLowLightMode = digitalGainForUltraLowLightMode
    }
}
