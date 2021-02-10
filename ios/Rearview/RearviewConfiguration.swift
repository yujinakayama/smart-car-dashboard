//
//  RearviewConfiguration.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2021/02/10.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation

struct RearviewConfiguration: Equatable {
    let raspberryPiAddress: String
    let digitalGainForLowLightMode: Float
    let digitalGainForUltraLowLightMode: Float
}
